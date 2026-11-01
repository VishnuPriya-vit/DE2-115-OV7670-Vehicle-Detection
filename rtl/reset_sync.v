`timescale 1ns/1ps
module reset_sync(input clk, input arst, output rst);
    // Asynchronous assertion, two local clock edges to release.
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
    reg [1:0] pipe;
    always @(posedge clk or posedge arst)
        if (arst) pipe <= 2'b11;
        else pipe <= {pipe[0],1'b0};
    assign rst = pipe[1];
endmodule
