`timescale 1ns/1ps
module vehicle_engine #(
    parameter WARMUP_FRAMES=90, LEARN_FRAMES=8, THRESHOLD=30,
    parameter TILE_MIN_HITS=8, MIN_PIXELS=48, MIN_WIDTH=12, MIN_HEIGHT=10,
    parameter RECOGNITION_BYPASS=0, YELLOW_FOREGROUND=1, DRAW_MARGIN=1, FOREGROUND_RUN_FILTER=1
)(input clk,rst,frame_start,relearn,pixel_valid,input [15:0] pixel,
    input [8:0] x,input [7:0] y,input [16:0] address,
    output reg box_update,output reg [104:0] boxes,
    output reg background_ready,frame_ready,bad_frame,
    output reg processing,output [5:0] class_ids,output [29:0] best_costs);
    localparam WAITING=0,LEARNING=1,DETECTING=2;
    reg [1:0] mode;
    integer warm_left,learned;
    reg started,pending_relearn,drop_frame;
    reg [16:0] samples;
    reg valid_d;
    reg [7:0] gray_d;
    reg [1:0] category_d;
    reg [8:0] x_d;
    reg [7:0] y_d;
    reg [16:0] addr_d;
    reg [10:0] tile_d;
    wire [7:0] r={pixel[15:11],pixel[15:13]};
    wire [7:0] g={pixel[10:5],pixel[10:9]};
    wire [7:0] b={pixel[4:0],pixel[4:2]};
    wire [9:0] gray_sum={2'b0,r}+{1'b0,g,1'b0}+{2'b0,b};
    wire [7:0] bg;
    wire [8:0] average={1'b0,bg}+{1'b0,gray_d};
    wire [7:0] difference=(gray_d>=bg) ? gray_d-bg : bg-gray_d;
    wire sample_ok=valid_d && !processing && !frame_start;
    background_ram background(.clk(clk),.rd_addr(address),.rd_data(bg),
        .wr_en(sample_ok && mode==LEARNING),.wr_addr(addr_d),
        .wr_data((learned==0) ? gray_d : average[8:1]));
    // Color novelty allows a yellow toy against a neutral wall even when
    // their grayscale brightnesses are nearly equal. OR during learning
    // conservatively marks any yellow seen in the empty background.
    wire background_yellow;
    background_color_ram background_color(.clk(clk),.rd_addr(address),
        .rd_data(background_yellow),.wr_en(sample_ok && mode==LEARNING),
        .wr_addr(addr_d),.wr_data((category_d==1) || (learned!=0 && background_yellow)));
    wire [10:0] pixel_tile=({6'b0,y[7:3]}<<5)+({6'b0,y[7:3]}<<3)+x[8:3];
    wire [10:0] cc_rd_addr,cc_wr_addr;
    wire [18:0] tile_q,cc_wr_data;
    wire cc_wr_en,cc_busy,cc_done;
    reg cc_start,cc_enable,class_start;
    wire [104:0] candidate_boxes,accepted_boxes;
    wire class_busy,class_done;
    wire [104:0] merged_boxes;
    merge_regions join_body(.boxes(candidate_boxes),.merged(merged_boxes));
    wire [6:0] count=tile_q[18:12];
    wire raw_hit=sample_ok && mode==DETECTING && (YELLOW_FOREGROUND ?
        (category_d==2'd1 && (!background_yellow || difference>THRESHOLD)) :
        difference>THRESHOLD);
    // Qualify runs within each 8-pixel tile row. Isolated yellow sensor speckles
    // no longer build large connected regions. First qualifying hit credits all
    // three pixels, preserving the true left edge instead of shrinking it.
    reg [1:0] run_length;
    reg [8:0] previous_x;
    reg [7:0] previous_y;
    reg previous_valid;
    wire adjacent=previous_valid && y_d==previous_y &&
        x_d==previous_x+9'd1 && x_d[2:0]!=0;
    wire [1:0] prior_run=adjacent ? run_length : 2'd0;
    wire filtered=YELLOW_FOREGROUND && FOREGROUND_RUN_FILTER;
    wire hit=raw_hit && (!filtered || prior_run>=2);
    wire first_run=filtered && prior_run==2;
    wire [2:0] hit_left=first_run ? x_d[2:0]-3'd2 : x_d[2:0];
    wire [2:0] lx0=(count==0 || hit_left<tile_q[2:0]) ? hit_left : tile_q[2:0];
    wire [2:0] lx1=(count==0 || x_d[2:0]>tile_q[5:3]) ? x_d[2:0] : tile_q[5:3];
    wire [2:0] ly0=(count==0 || y_d[2:0]<tile_q[8:6]) ? y_d[2:0] : tile_q[8:6];
    wire [2:0] ly1=(count==0 || y_d[2:0]>tile_q[11:9]) ? y_d[2:0] : tile_q[11:9];
    wire [7:0] count_sum={1'b0,count}+(first_run ? 8'd3 : 8'd1);
    wire [6:0] next_count=(count_sum>64) ? 7'd64 : count_sum[6:0];
    always @(posedge clk or posedge rst)begin
        if(rst)begin run_length<=0;previous_x<=0;previous_y<=0;previous_valid<=0;end
        else if(frame_start || relearn || processing)begin run_length<=0;previous_valid<=0;end
        else if(sample_ok)begin
            previous_x<=x_d;previous_y<=y_d;previous_valid<=1;
            if(!raw_hit)run_length<=0;
            else if(prior_run<3)run_length<=prior_run+1'b1;
            else run_length<=3;
        end
    end
    tile_ram tiles(.clk(clk),.rd_addr(processing ? cc_rd_addr : pixel_tile),.rd_data(tile_q),
        .wr_en(processing ? cc_wr_en : hit),.wr_addr(processing ? cc_wr_addr : tile_d),
        .wr_data(processing ? cc_wr_data : {next_count,ly1,ly0,lx1,lx0}));
    component_boxes #(.TILE_MIN_HITS(TILE_MIN_HITS),.MIN_PIXELS(YELLOW_FOREGROUND ? 16 : MIN_PIXELS),
        .MIN_WIDTH(YELLOW_FOREGROUND ? 4 : MIN_WIDTH),.MIN_HEIGHT(YELLOW_FOREGROUND ? 4 : MIN_HEIGHT)) components(
        .clk(clk),.rst(rst),.start(cc_start),.enable(cc_enable),
        .busy(cc_busy),.done(cc_done),.boxes(candidate_boxes),
        .rd_addr(cc_rd_addr),.rd_data(tile_q),.wr_en(cc_wr_en),
        .wr_addr(cc_wr_addr),.wr_data(cc_wr_data));
    wire [1:0] category,category_q;
    wire [16:0] category_addr;
    pixel_category encode(.pixel(pixel),.category(category));
    category_ram colors(.clk(clk),.wr_en(pixel_valid && !processing && !frame_start && !rst),
        .wr_addr(address),.wr_data(category),.rd_addr(category_addr),.rd_data(category_q));
    template_classifier #(.BYPASS(RECOGNITION_BYPASS),.DRAW_MARGIN(DRAW_MARGIN)) classifier(
        .clk(clk),.rst(rst),.start(class_start),.candidate_boxes(YELLOW_FOREGROUND ? merged_boxes : candidate_boxes),
        .busy(class_busy),.done(class_done),.accepted_boxes(accepted_boxes),
        .class_ids(class_ids),.best_costs(best_costs),.rd_addr(category_addr),.rd_data(category_q));
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            mode<=WAITING;warm_left<=WARMUP_FRAMES;learned<=0;started<=0;
            pending_relearn<=0;drop_frame<=0;samples<=0;valid_d<=0;
            gray_d<=0;category_d<=0;x_d<=0;y_d<=0;addr_d<=0;tile_d<=0;
            processing<=0;cc_start<=0;cc_enable<=0;class_start<=0;
            box_update<=0;boxes<=0;background_ready<=0;frame_ready<=0;bad_frame<=0;
        end else begin
            box_update<=0;cc_start<=0;class_start<=0;
            if(relearn && mode!=LEARNING)pending_relearn<=1;
            valid_d<=pixel_valid && !processing && !frame_start;
            gray_d<=gray_sum[9:2];category_d<=category;x_d<=x;y_d<=y;addr_d<=address;tile_d<=pixel_tile;
            if(sample_ok && samples<76800)samples<=samples+1'b1;
            // An unexpectedly short blanking interval invalidates recognition.
            // Live RGB capture is independent and remains enabled.
            if(pixel_valid && processing)drop_frame<=1;
            if(cc_done)class_start<=1;
            if(class_done)begin
                processing<=0;box_update<=1;
                if(drop_frame || relearn || pending_relearn)boxes<=0;
                else boxes<=accepted_boxes;
            end
            if(frame_start) begin
                valid_d<=0;samples<=0;started<=1;
                drop_frame<=processing;
                if(started)begin
                    bad_frame<=samples!=76800 || drop_frame || processing;
                    if(samples==76800)frame_ready<=1;
                end
                if(!processing)begin
                    processing<=1;cc_start<=1;
                    cc_enable<=started && samples==76800 && !drop_frame &&
                        mode==DETECTING && !pending_relearn && !relearn;
                end
                if(pending_relearn || relearn)begin
                    mode<=LEARNING;learned<=0;background_ready<=0;pending_relearn<=0;
                end else if(mode==WAITING)begin
                    if(warm_left==0)begin mode<=LEARNING;learned<=0;end
                    else warm_left<=warm_left-1;
                end else if(mode==LEARNING && started)begin
                    if(samples!=76800 || drop_frame || processing)begin learned<=0;background_ready<=0;end
                    else if(learned==LEARN_FRAMES-1)begin mode<=DETECTING;background_ready<=1;end
                    else learned<=learned+1;
                end
            end
        end
    end
endmodule
