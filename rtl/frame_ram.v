`timescale 1ns/1ps
module frame_ram(input wr_clk, input wr_en, input [16:0] wr_addr,
    input [15:0] wr_data, input rd_clk, input [16:0] rd_addr,
    output reg [15:0] rd_data);
    // No array reset: required for embedded RAM inference.
    // A same-address mixed-clock collision has undefined read data.
    (* ramstyle = "M9K, no_rw_check" *) reg [15:0] mem [0:76799];
    always @(posedge wr_clk)
        if (wr_en) mem[wr_addr] <= wr_data;
    always @(posedge rd_clk) rd_data <= mem[rd_addr];
endmodule
