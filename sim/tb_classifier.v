`timescale 1ns/1ps
module tb_classifier;
    reg clk=0,rst=1,start=0,we=0;
    always #20 clk=~clk;
    reg [104:0] candidates=0;
    reg [16:0] wa=0;
    reg [1:0] wd=0;
    wire [16:0] ra;
    wire [1:0] q;
    wire busy,done;
    wire [104:0] boxes;
    wire [5:0] ids;
    wire [29:0] scores;
    reg [1:0] patterns[0:60415];
    integer xx,yy,t,w,h,idx,errors=0,cycles,temp;
    reg [1:0] val;
    category_ram ram(.clk(clk),.wr_en(we),.wr_addr(wa),.wr_data(wd),.rd_addr(ra),.rd_data(q));
    template_classifier #(.DRAW_MARGIN(0)) dut(.clk(clk),.rst(rst),.start(start),.candidate_boxes(candidates),
        .busy(busy),.done(done),.accepted_boxes(boxes),.class_ids(ids),.best_costs(scores),.rd_addr(ra),.rd_data(q));
    initial begin
        $readmemh("../reference/all_templates.hex",patterns);
        repeat(4) @(negedge clk);rst=0;
        for(t=0;t<240;t=t+1)begin
            case(t/4)
            0:begin w=96;h=36;end
            1:begin w=96;h=83;end
            2:begin w=96;h=36;end
            3:begin w=96;h=103;end
            4:begin w=96;h=38;end
            5:begin w=96;h=40;end
            6:begin w=96;h=40;end
            7:begin w=96;h=51;end
            8:begin w=96;h=43;end
            9:begin w=96;h=36;end
            10:begin w=96;h=55;end
            11:begin w=96;h=38;end
            12:begin w=96;h=51;end
            13:begin w=96;h=39;end
            14:begin w=96;h=34;end
            15:begin w=96;h=90;end
            16:begin w=96;h=33;end
            17:begin w=96;h=86;end
            18:begin w=96;h=34;end
            19:begin w=96;h=41;end
            20:begin w=96;h=41;end
            21:begin w=96;h=45;end
            22:begin w=96;h=42;end
            23:begin w=96;h=33;end
            24:begin w=96;h=34;end
            25:begin w=96;h=35;end
            26:begin w=96;h=35;end
            27:begin w=96;h=35;end
            28:begin w=96;h=44;end
            29:begin w=96;h=44;end
            30:begin w=96;h=41;end
            31:begin w=96;h=36;end
            32:begin w=96;h=44;end
            33:begin w=96;h=123;end
            34:begin w=96;h=121;end
            35:begin w=96;h=43;end
            36:begin w=96;h=108;end
            37:begin w=96;h=116;end
            38:begin w=96;h=54;end
            39:begin w=96;h=49;end
            40:begin w=96;h=53;end
            41:begin w=96;h=47;end
            42:begin w=96;h=52;end
            43:begin w=96;h=71;end
            44:begin w=96;h=73;end
            45:begin w=96;h=43;end
            46:begin w=96;h=44;end
            47:begin w=96;h=121;end
            48:begin w=96;h=43;end
            49:begin w=96;h=68;end
            50:begin w=96;h=70;end
            51:begin w=96;h=50;end
            52:begin w=96;h=46;end
            53:begin w=96;h=83;end
54:begin w=96;h=77;end
55:begin w=96;h=112;end
56:begin w=96;h=111;end
57:begin w=96;h=101;end
58:begin w=96;h=125;end
            default:begin w=96;h=64;end
            endcase
            if(t<236 && t%2)begin temp=w;w=h;h=temp;end
            for(yy=0;yy<h;yy=yy+1)for(xx=0;xx<w;xx=xx+1)begin
                idx=(yy*16/h)*16+(xx*16/w);
                if(t<236)val=patterns[t*256+idx];
                else if(t==239)begin
                    val=patterns[idx];
                    // Corrupt every sampled center, retaining both neighbours.
                    if(xx%6==3 && yy%4==2)val=(val==1) ? 0 : 1;
                end else val=t-236;
                @(negedge clk);we=1;wa=(yy+17)*320+xx+13;wd=val;
            end
            @(negedge clk);we=0;candidates=0;
            candidates[34:0]={1'b1,9'd13,9'd13+w[8:0]-9'd1,8'd17,8'd17+h[7:0]-8'd1};
            start=1;@(negedge clk);start=0;cycles=0;
            while(!done && cycles<6000)begin @(negedge clk);cycles=cycles+1;end
            if(!done)begin errors=errors+1;$display("FAIL classifier timeout");end
            if(t<236 || t==239)begin
                if(boxes!==candidates || ids[1:0]!==((t<56 || t==239) ? 1 : ((t<128) ? 2 : ((t<212) ? 3 : ((t<220) ? 2 : ((t<228) ? 1 : 3))))) || scores[9:0]!==10'd0)begin
                    errors=errors+1;$display("FAIL template %0d ids=%d cost=%d boxes=%h",t,ids,scores[9:0],boxes);
                end
            end else if(boxes!==0)begin errors=errors+1;$display("FAIL solid category %0d accepted",t-236);end
        end
        if(errors==0)$display("PASS: 236 multi-view and quarter-turn descriptors match at changed scales and positions; solid-color controls rejected; all 256 corrupted sample centers recovered by neighbourhood voting");
        else $display("FAIL: classifier errors=%0d",errors);
        $finish;
    end
    initial begin #200000000;$display("FAIL classifier timeout");$finish;end
endmodule
