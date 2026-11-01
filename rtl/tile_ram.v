`timescale 1ns/1ps
// 40x30 tiles, each 8x8 stored pixels. Data: count[18:12],
// local ymax[11:9], ymin[8:6], xmax[5:3], xmin[2:0].
module tile_ram(input clk, input [10:0] rd_addr, output reg [18:0] rd_data,
    input wr_en, input [10:0] wr_addr, input [18:0] wr_data);
    (* ramstyle="M9K" *) reg [18:0] mem[0:1199];
    always @(posedge clk) begin
        rd_data<=mem[rd_addr];
        if(wr_en) mem[wr_addr]<=wr_data;
    end
endmodule
