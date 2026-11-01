`timescale 1ns/1ps
module sync_bit(input clk, input rst, input din, output dout);
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
    reg [1:0] pipe;
    always @(posedge clk or posedge rst)
        if (rst) pipe <= 0;
        else pipe <= {pipe[0],din};
    assign dout = pipe[1];
endmodule
