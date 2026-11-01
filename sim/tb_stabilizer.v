`timescale 1ns/1ps
module tb_stabilizer;
 reg clk=0,rst=1,clear=0,update=0;
 always #20 clk=~clk;
 reg [104:0] bi=0;
 wire [104:0] bo;
 wire done;
 integer errors=0,cycles;
 box_stabilizer dut(.clk(clk),.rst(rst),.clear(clear),.update(update),.boxes_in(bi),.update_out(done),.boxes_out(bo));
 function [34:0] box;
 input integer x0,x1,y0,y1;
 begin box={1'b1,x0[8:0],x1[8:0],y0[7:0],y1[7:0]};end
 endfunction
 task send;
 input [104:0] value;
 begin
  @(negedge clk);bi=value;update=1;
  @(negedge clk);update=0;cycles=0;
  while(!done && cycles<40)begin @(negedge clk);cycles=cycles+1;end
  if(!done)begin errors=errors+1;$display("FAIL tracker timeout");end
  @(negedge clk);
 end
 endtask
 task check;
 input [104:0] wanted;
 begin if(bo!==wanted)begin errors=errors+1;$display("FAIL tracker got=%h want=%h",bo,wanted);end end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  send({35'd0,box(180,220,100,130),box(20,60,40,70)});
  check(0);
  send({35'd0,box(180,220,100,130),box(20,60,40,70)});
  check({35'd0,box(180,220,100,130),box(20,60,40,70)});
  // Reordered detection slots and +/-2 stored-pixel edge noise.
  send({35'd0,box(179,222,101,129),box(22,59,39,72)});
  check({35'd0,box(180,220,100,130),box(20,60,40,70)});
  send({35'd0,box(21,61,41,71),box(182,218,98,132)});
  check({35'd0,box(180,220,100,130),box(20,60,40,70)});
  // Four-pixel movement gives two-pixel smoothing, then fast motion follows.
  send({35'd0,box(180,220,100,130),box(24,64,44,74)});
  check({35'd0,box(180,220,100,130),box(22,62,42,72)});
  send({35'd0,box(180,220,100,130),box(42,82,42,72)});
  check({35'd0,box(180,220,100,130),box(42,82,42,72)});
  send(0);check({35'd0,box(180,220,100,130),box(42,82,42,72)});
  send(0);check({35'd0,box(180,220,100,130),box(42,82,42,72)});
  send(0);check(0);
  send({70'd0,box(270,310,180,220)});
  check(0);
  send({70'd0,box(270,310,180,220)});
  check({70'd0,box(270,310,180,220)});
  @(negedge clk);clear=1;@(negedge clk);check(0);clear=0;
  send({70'd0,box(0,8,0,8)});check(0);
  send(0);check(0); // One-frame candidate must never flash or linger.
  send({70'd0,box(0,8,0,8)});check(0);
  send({70'd0,box(0,8,0,8)});check({70'd0,box(0,8,0,8)});
  send({70'd0,box(13,16,13,16)});check({70'd0,box(13,16,13,16)});
  @(negedge clk);rst=1;@(negedge clk);check(0);
  if(errors==0)$display("PASS: two-frame confirmation, one-frame noise rejection, spatial box association, two vehicles, reordered slots, jitter deadband, smoothing, motion, two-frame dropout, removal, relearn clear and reset");
  else $display("FAIL tracker errors=%0d",errors);
  $finish;
 end
endmodule
