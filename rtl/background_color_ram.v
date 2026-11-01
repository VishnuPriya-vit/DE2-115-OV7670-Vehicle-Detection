`timescale 1ns/1ps
// A learned one-bit yellow-background mask. Same one-clock read latency as
// background_ram. No RAM reset, no initialization file, and no extra clock.
module background_color_ram(input clk,input [16:0] rd_addr,
 output reg rd_data,input wr_en,input [16:0] wr_addr,input wr_data);
 (* ramstyle = "M9K" *) reg mem[0:76799];
 always @(posedge clk)begin
  rd_data<=mem[rd_addr];
  if(wr_en)mem[wr_addr]<=wr_data;
 end
endmodule
