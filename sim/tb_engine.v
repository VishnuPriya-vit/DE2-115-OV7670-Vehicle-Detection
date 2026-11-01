`timescale 1ns/1ps
module tb_engine;
    reg clk=0,rst=1,fs=0,relearn=0,pv=0;
    always #20 clk=~clk;
    reg [15:0] pixel=0;
    reg [8:0] x=0;
    reg [7:0] y=0;
    reg [16:0] address=0;
    wire update,ready,fr,bad,processing;
    wire [104:0] boxes;
    wire [5:0] ids;
    wire [29:0] costs;
    reg [1:0] a[0:255],b[0:255],c[0:255];
    integer xx,yy,errors=0,cycles,max_cycles=0;
    vehicle_engine #(.WARMUP_FRAMES(0),.LEARN_FRAMES(2),.YELLOW_FOREGROUND(0),.TILE_MIN_HITS(4),.DRAW_MARGIN(0)) dut(
        .clk(clk),.rst(rst),.frame_start(fs),.relearn(relearn),.pixel_valid(pv),
        .pixel(pixel),.x(x),.y(y),.address(address),.box_update(update),.boxes(boxes),
        .background_ready(ready),.frame_ready(fr),.bad_frame(bad),.processing(processing),
        .class_ids(ids),.best_costs(costs));
    function [34:0] box;
        input integer x0,x1,y0,y1;
        begin box={1'b1,x0[8:0],x1[8:0],y0[7:0],y1[7:0]};end
    endfunction
    function [15:0] rgb;
        input [1:0] cat;
        begin case(cat) 1:rgb=16'hffe0;2:rgb=16'h0000;default:rgb=16'h8410;endcase end
    endfunction
    function [15:0] scene;
        input integer kind,px,py;
        integer dx,dy,idx;
        begin
            scene=16'h2104;
            dx=(kind==4) ? 40:20;dy=(kind==4) ? 40:32;
            if(kind>=1 && kind<=6 && px>=dx && px<dx+96 && py>=dy && py<dy+54)begin
                idx=((py-dy)*16/54)*16+(px-dx)*16/96;
                scene=(kind==5) ? 16'hffe0:rgb(a[idx]);
            end
            dx=(kind==3) ? 20:((kind==4) ? 180:160);
            dy=(kind==3 || kind==4) ? 128:112;
            if((kind==2 || kind==3 || kind==4 || kind==6) && px>=dx && px<dx+80 && py>=dy && py<dy+48)begin
                idx=((py-dy)*16/48)*16+(px-dx)*16/80;scene=rgb(b[idx]);
            end
            if(kind==6 && px>=240 && px<310 && py>=176 && py<232)begin
                idx=((py-176)*16/56)*16+(px-240)*16/70;scene=rgb(c[idx]);
            end
            if(kind==7 && px>=2 && px<4 && py>=2 && py<4)scene=16'hffff;
        end
    endfunction
    task boundary;
        begin
            @(negedge clk);fs=1;pv=0;
            @(negedge clk);fs=0;cycles=0;
            while(!update && cycles<30000)begin @(negedge clk);cycles=cycles+1;end
            if(cycles>max_cycles)max_cycles=cycles;
            if(!update)begin errors=errors+1;$display("FAIL engine processing timeout");end
            repeat(4) @(negedge clk);
        end
    endtask
    task frame;
        input integer kind;
        begin
            for(yy=0;yy<240;yy=yy+1)for(xx=0;xx<320;xx=xx+1)begin
                @(negedge clk);pv=1;x=xx;y=yy;address=yy*320+xx;pixel=scene(kind,xx,yy);
                @(negedge clk);pv=0;
                repeat(2) @(negedge clk);
            end
            repeat(3) @(negedge clk);
            boundary;
        end
    endtask
    task check;
        input [104:0] expected;
        begin
            $display("ENGINE boxes=%h classes=%h costs=%h processing_clocks=%0d",boxes,ids,costs,cycles);
            if(boxes!==expected || bad)begin errors=errors+1;$display("FAIL engine boxes expected %h bad=%b",expected,bad);end
        end
    endtask
    initial begin
        $readmemh("../reference/dump_truck_categories.hex",a);
        $readmemh("../reference/van_categories.hex",b);
        $readmemh("../reference/construction_truck_categories.hex",c);
        repeat(4) @(negedge clk);rst=0;
        boundary;frame(0);frame(0);
        if(!ready)begin errors=errors+1;$display("FAIL background not learned");end
        check(0);
        frame(1);check({70'd0,box(20,115,32,85)});
        frame(2);check({35'd0,box(160,239,112,159),box(20,115,32,85)});
        frame(3);check({35'd0,box(20,99,128,175),box(20,115,32,85)});
        frame(4);check({35'd0,box(180,259,128,175),box(40,135,40,93)});
        frame(6);check({box(160,239,112,159),box(240,309,176,231),box(20,115,32,85)});
        frame(5);check(0);
        frame(7);check(0);
        frame(0);check(0);
        relearn=1;frame(0);if(ready)begin errors=errors+1;$display("FAIL relearn");end
        relearn=0;frame(0);frame(0);
        if(!ready)begin errors=errors+1;$display("FAIL relearn did not finish");end
        frame(1);check({70'd0,box(20,115,32,85)});
        @(negedge clk);pv=1;pixel=16'hffff;x=0;y=0;address=0;
        @(negedge clk);pv=0;repeat(3) @(negedge clk);boundary;
        if(!bad || boxes!==0)begin errors=errors+1;$display("FAIL incomplete frame");end
        rst=1;repeat(4) @(negedge clk);
        if(boxes!==0 || ready || fr)begin errors=errors+1;$display("FAIL reset");end
        if(errors==0)$display("PASS: integrated learning, photo-descriptor matching, horizontal/vertical objects, movement, three objects, rejection controls, noise, removal, relearn, incomplete frame; max processing clocks=%0d",max_cycles);
        else $display("FAIL engine errors=%0d",errors);
        $finish;
    end
    initial begin #250000000;$display("FAIL engine timeout");$finish;end
endmodule
