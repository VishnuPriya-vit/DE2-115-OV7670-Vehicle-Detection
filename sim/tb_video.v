`timescale 1ns/1ps
module tb_video;
    reg clk=0, clk25=0, rst=1, ready=0, we=0;
    always #10 clk=~clk;
    always @(posedge clk) clk25<=!clk25;
    reg [16:0] wa=0;
    reg [15:0] wd=0;
    wire [16:0] ra;
    wire [15:0] q;
    wire [7:0] r,g,b;
    wire hs,vs,blank,sync;
    wire golden_text;
    text_reference golden(.x(dut.h),.y(dut.v),.enable(1'b1),.ink(golden_text));
    integer i,errors=0,checked=0,ox,oy;
    reg [15:0] expected;
    reg [23:0] rgb_expected;
    reg [104:0] box={1'b1,9'd300,9'd319,8'd200,8'd239,
        1'b1,9'd150,9'd209,8'd100,8'd149,{1'b1,9'd50,9'd99,8'd40,8'd79}};
    function [15:0] pattern;
        input integer x,y;
        begin pattern={x[4:0],y[5:0],x[4:0]^y[4:0]}; end
    endfunction
    frame_ram ram(.wr_clk(clk),.wr_en(we),.wr_addr(wa),.wr_data(wd),
        .rd_clk(clk),.rd_addr(ra),.rd_data(q));
    vga_display #(.BOX_COUNT(3),.SHOW_TEXT(1)) dut(.clk(clk),.rst(rst),.clk25(clk25),.frame_ready(ready),
        .box_data(box),.ram_data(q),.ram_address(ra),.red(r),.green(g),.blue(b),
        .hs(hs),.vs(vs),.blank_n(blank),.sync_n(sync));
    always @(posedge clk) if (!rst && clk25 && ready && dut.active_box[34]) begin
        ox=dut.h; oy=dut.v;
        expected=pattern(ox/2,oy/2);
        rgb_expected={{expected[15:11],expected[15:13]},
                      {expected[10:5],expected[10:9]},
                      {expected[4:0],expected[4:2]}};
        if (ox>=100 && ox<=199 && oy>=80 && oy<=159 &&
            (ox<104 || ox>195 || oy<84 || oy>155)) rgb_expected=24'h00ff00;
        if (ox>=300 && ox<=419 && oy>=200 && oy<=299 &&
            (ox<304 || ox>415 || oy<204 || oy>295)) rgb_expected=24'h00ff00;
        if (ox>=600 && ox<=639 && oy>=400 && oy<=479 &&
            (ox<604 || ox>635 || oy<404 || oy>475)) rgb_expected=24'h00ff00;
        if(golden_text) rgb_expected=24'h00ff00;
        if (ox>=640 || oy>=480) rgb_expected=0;
        #1;
        if ({r,g,b}!==rgb_expected) begin
            errors=errors+1;
            if(errors<10) $display("FAIL pixel (%0d,%0d): got %h expected %h",ox,oy,{r,g,b},rgb_expected);
        end
        if(ox<640 && oy<480) checked=checked+1;
    end
    initial begin
        repeat(4) @(negedge clk);
        rst=0;
        for(i=0;i<76800;i=i+1) begin
            @(negedge clk); we=1; wa=i; wd=pattern(i%320,i/320);
        end
        @(negedge clk); we=0; ready=1;
        wait(checked>=307200);
        #100;
        if(errors==0) $display("PASS: all 307200 active VGA pixels match 2x2 RGB565 mapping and three 4-pixel borders plus pipelined status text");
        else $display("FAIL: %0d VGA pixel mismatches",errors);
        $finish;
    end
    initial begin #60000000; $display("FAIL: VGA timeout"); $finish; end
endmodule
