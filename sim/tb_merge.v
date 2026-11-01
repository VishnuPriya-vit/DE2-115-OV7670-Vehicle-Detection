`timescale 1ns/1ps
module tb_merge;
reg [104:0] boxes;wire [104:0] merged;integer errors=0;
merge_regions dut(.boxes(boxes),.merged(merged));
function [34:0] b;input integer l,r,t,d;begin b={1'b1,l[8:0],r[8:0],t[7:0],d[7:0]};end endfunction
task check;input [104:0] expected;begin #1;if(merged!==expected)begin errors=errors+1;$display("FAIL merge got %h expected %h",merged,expected);end end endtask
initial begin
 boxes=0;check(0);
 boxes={35'd0,b(20,90,79,115),b(20,90,25,62)};check({70'd0,b(20,90,25,115)});
 boxes={35'd0,b(20,90,80,115),b(20,90,25,62)};check(boxes);
 boxes={35'd0,b(60,90,10,40),b(10,40,10,40)};check(boxes);
 boxes={35'd0,b(50,90,10,40),b(10,40,10,40)};check({70'd0,b(10,90,10,40)});
 boxes={b(10,30,40,50),b(10,30,70,80),b(10,30,10,20)};check(boxes); // gaps too large
 boxes={b(10,30,35,50),b(10,30,60,80),b(10,30,10,25)};check({70'd0,b(10,30,10,80)});
 boxes={35'd0,b(28,45,28,45),b(0,10,0,10)};check(boxes); // diagonal fragments not joined
 if(errors==0)$display("PASS: fragment joining, gap boundary, distinct objects, transitive joining and diagonal rejection");
 else $display("FAIL merge errors %d",errors);
 $finish;
end
endmodule
