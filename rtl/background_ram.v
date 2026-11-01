`timescale 1ns/1ps
module background_ram(input clk, input [16:0] rd_addr,
    output reg [7:0] rd_data, input wr_en, input [16:0] wr_addr,
    input [7:0] wr_data);
    (* ramstyle = "M9K" *) reg [7:0] mem [0:76799];
    always @(posedge clk) begin
        rd_data <= mem[rd_addr];
        if (wr_en) mem[wr_addr] <= wr_data;
    end
endmodule
