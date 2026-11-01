`timescale 1ns/1ps
module category_ram(input clk, input wr_en, input [16:0] wr_addr,
    input [1:0] wr_data, input [16:0] rd_addr, output reg [1:0] rd_data);
    (* ramstyle="M9K" *) reg [1:0] mem [0:76799];
    always @(posedge clk) begin
        rd_data<=mem[rd_addr];
        if(wr_en) mem[wr_addr]<=wr_data;
    end
endmodule
