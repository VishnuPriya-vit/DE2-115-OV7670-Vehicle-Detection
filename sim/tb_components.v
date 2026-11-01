`timescale 1ns/1ps
module tb_components;
    reg clk=0,rst=1,start=0,enable=1,loading=0;
    always #20 clk=~clk;
    wire busy,done,we;
    wire [104:0] boxes;
    wire [10:0] ra,wa;
    wire [18:0] q,wd;
    reg [10:0] load_addr=0;
    reg [18:0] load_data=0;
    reg [18:0] vectors[0:9599];
    reg [104:0] expected[0:7];
    integer i,t,cycles,errors=0,max_cycles=0;
    tile_ram ram(.clk(clk),.rd_addr(ra),.rd_data(q),.wr_en(loading || we),
        .wr_addr(loading ? load_addr:wa),.wr_data(loading ? load_data:wd));
    component_boxes dut(.clk(clk),.rst(rst),.start(start),.enable(enable),
        .busy(busy),.done(done),.boxes(boxes),.rd_addr(ra),.rd_data(q),
        .wr_en(we),.wr_addr(wa),.wr_data(wd));
    initial begin
        $readmemh("vectors/tiles.hex",vectors);$readmemh("vectors/tile_expected.hex",expected);
        repeat(4) @(negedge clk);rst=0;
        for(t=0;t<8;t=t+1)begin
            for(i=0;i<1200;i=i+1)begin
                @(negedge clk);loading=1;load_addr=i;load_data=vectors[t*1200+i];
            end
            @(negedge clk);loading=0;start=1;
            @(negedge clk);start=0;cycles=0;
            while(!done && cycles<22000)begin @(negedge clk);cycles=cycles+1;end
            if(cycles>max_cycles)max_cycles=cycles;
            if(boxes!==expected[t] || !done)begin errors=errors+1;$display("FAIL CC case %0d got %h expected %h",t,boxes,expected[t]);end
            for(i=0;i<1200;i=i+1)if(ram.mem[i]!==0)begin errors=errors+1;$display("FAIL uncleared tile %0d",i);end
            $display("CC case %0d completed in %0d clocks",t,cycles);
        end
        if(errors==0)$display("PASS: 8 independent component cases, full FIFO capacity, top-three ordering; max cycles=%0d",max_cycles);
        else $display("FAIL: component errors=%0d",errors);
        $finish;
    end
    initial begin #20000000;$display("FAIL CC timeout");$finish;end
endmodule
