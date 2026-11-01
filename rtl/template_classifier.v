`timescale 1ns/1ps
// Positive-only photo-template matching. This is NOT a validated semantic
// vehicle classifier. Distances are integer costs, not confidence percentages.
module template_classifier #(parameter BYPASS=0, DRAW_MARGIN=1, ROBUST_SAMPLING=1)(
    input clk,rst,start, input [104:0] candidate_boxes,
    output reg busy,done, output reg [104:0] accepted_boxes,
    output reg [5:0] class_ids, output reg [29:0] best_costs,
    output [16:0] rd_addr, input [1:0] rd_data);
    localparam IDLE=0,LOAD=1,READ=2,SAMPLE=3,CHOOSE=4,COMMIT=5;
    reg [2:0] state;
    reg [104:0] candidates;
    reg [1:0] slot;
    reg [34:0] current_box;
    reg [8:0] bx,width;
    reg [7:0] by,height;
    reg [7:0] sample_index;
    reg [1:0] tap,center_category,left_category;
    reg [9:0] costs[0:235];
    reg [7:0] choice,best_choice;
    reg [9:0] best;
    reg found;
    integer k;
    wire [235:0] rom_yellow,rom_dark,rom_care;
    reg [235:0] ty,td,care;
    vehicle_template_rom rom(.index(sample_index),.yellow(rom_yellow),.dark(rom_dark),.dark_care(rom_care));
    // Cell centers. Keep products wide before shifting to avoid truncation.
    wire [14:0] x_product=({10'b0,sample_index[3:0],1'b1}*width);
    wire [13:0] y_product=({9'b0,sample_index[7:4],1'b1}*height);
    wire [8:0] center_x=bx+x_product[13:5];
    wire [8:0] right_edge=current_box[24:16];
    wire [8:0] px=(!ROBUST_SAMPLING || tap==0) ? center_x :
        ((tap==1) ? ((center_x>bx) ? center_x-9'd1 : center_x) :
        ((center_x<right_edge) ? center_x+9'd1 : center_x));
    // Majority of center/left/right, with center as the three-way tie break.
    wire [1:0] voted=(center_category==left_category || center_category==rd_data) ?
        center_category : ((left_category==rd_data) ? left_category : center_category);
    wire [1:0] sampled_category=ROBUST_SAMPLING ? voted : rd_data;
    wire [7:0] py=by+y_product[12:5];
    assign rd_addr=({9'b0,py}<<8)+({9'b0,py}<<6)+{8'b0,px};
    wire [9:0] max_cost;
    wire [8:0] aspect_min,aspect_max;
    vehicle_match_limits limits(.index(choice),.max_cost(max_cost),
        .aspect_min(aspect_min),.aspect_max(aspect_max));
    wire [1:0] selected_class=(best_choice<8'd56) ? 2'd1 :
        ((best_choice<8'd128) ? 2'd2 : ((best_choice<8'd212) ? 2'd3 :
        ((best_choice<8'd220) ? 2'd2 : ((best_choice<8'd228) ? 2'd1 : 2'd3))));
    // Match the yellow body, then extend the displayed outline to cover wheels.
    // Margins are geometric approximations, clipped to the active image.
    wire [8:0] raw_left=current_box[33:25],raw_right=current_box[24:16];
    wire [7:0] raw_top=current_box[15:8],raw_bottom=current_box[7:0];
    // Consistent upright-camera margin: never jump with the winning view.
    wire [1:0] rotation=2'd0;
    wire [8:0] wheel_margin=(found && !BYPASS) ?
        (rotation[0] ? {2'b0,width[8:2]} : {3'b0,height[7:2]}) : 9'd0;
    wire [9:0] left_pad=10'd2+((rotation==1) ? {1'b0,wheel_margin}:10'd0);
    wire [9:0] top_pad=10'd2+((rotation==2) ? {1'b0,wheel_margin}:10'd0);
    wire [9:0] left_difference={1'b0,raw_left}-left_pad;
    wire [9:0] top_difference={2'b0,raw_top}-top_pad;
    wire [9:0] right_sum={1'b0,raw_right}+10'd2+((rotation==3) ? {1'b0,wheel_margin}:10'd0);
    wire [9:0] bottom_sum={2'b0,raw_bottom}+10'd2+((rotation==0) ? {1'b0,wheel_margin}:10'd0);
    wire [34:0] displayed_box=DRAW_MARGIN ?
        {1'b1,(({1'b0,raw_left}>=left_pad) ? left_difference[8:0]:9'd0),
         ((right_sum<=319) ? right_sum[8:0]:9'd319),
         (({2'b0,raw_top}>=top_pad) ? top_difference[7:0]:8'd0),
         ((bottom_sum<=239) ? bottom_sum[7:0]:8'd239)} : current_box;
    wire aspect_ok=(width*100>=height*aspect_min && width*100<=height*aspect_max);
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state<=IDLE;busy<=0;done<=0;accepted_boxes<=0;
            class_ids<=0;best_costs<=0;candidates<=0;slot<=0;
            current_box<=0;bx<=0;by<=0;width<=0;height<=0;
            sample_index<=0;tap<=0;center_category<=0;left_category<=0;choice<=0;best_choice<=0;best<=1023;found<=0;
            for(k=0;k<236;k=k+1) costs[k]<=0;
        end else begin
            done<=0;
            case(state)
            IDLE: if(start) begin
                busy<=1;candidates<=candidate_boxes;slot<=0;
                accepted_boxes<=0;class_ids<=0;best_costs<=0;state<=LOAD;
            end
            LOAD: begin
                current_box<=candidates[slot*35 +: 35];
                bx<=candidates[slot*35+25 +: 9];
                by<=candidates[slot*35+8 +: 8];
                width<=candidates[slot*35+16 +: 9]-candidates[slot*35+25 +: 9]+1'b1;
                height<=candidates[slot*35 +: 8]-candidates[slot*35+8 +: 8]+1'b1;
                sample_index<=0;tap<=0;best<=1023;best_choice<=0;found<=0;
                for(k=0;k<236;k=k+1) costs[k]<=0;
                if(!candidates[slot*35+34] || BYPASS) state<=COMMIT;
                else state<=READ;
            end
            READ: begin
                // Register the wider reference ROM while synchronous category
                // RAM completes its read; no extra pixel or frame latency.
                ty<=rom_yellow;td<=rom_dark;care<=rom_care;state<=SAMPLE;
            end
            SAMPLE: begin
                if(ROBUST_SAMPLING && tap<2)begin
                    if(tap==0)center_category<=rd_data;
                    else left_category<=rd_data;
                    tap<=tap+1'b1;state<=READ;
                end else begin
                    for(k=0;k<236;k=k+1)
                        costs[k]<=costs[k]+(((sampled_category==1)!=ty[k]) ? 10'd2:10'd0)+
                            ((care[k] && ((sampled_category==2)!=td[k])) ? 10'd1:10'd0);
                    tap<=0;
                    if(sample_index==255) begin choice<=0;state<=CHOOSE;end
                    else begin sample_index<=sample_index+1'b1;state<=READ;end
                end
            end
            CHOOSE: begin
                if(aspect_ok && costs[choice]<=max_cost && costs[choice]<best) begin
                    best<=costs[choice];best_choice<=choice;found<=1;
                end
                if(choice==235) state<=COMMIT;
                else choice<=choice+1'b1;
            end
            COMMIT: begin
                if(current_box[34] && (found || BYPASS)) begin
                    accepted_boxes[slot*35 +: 35]<=displayed_box;
                    // Slots are components, not persistent object identities.
                    class_ids[slot*2 +: 2]<=BYPASS ? 2'd0 : selected_class;
                end
                best_costs[slot*10 +: 10]<=best;
                if(slot==2) begin busy<=0;done<=1;state<=IDLE;end
                else begin slot<=slot+1'b1;state<=LOAD;end
            end
            default:state<=IDLE;
            endcase
        end
    end
endmodule
