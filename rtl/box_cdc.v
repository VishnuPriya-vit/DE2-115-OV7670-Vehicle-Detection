`timescale 1ns/1ps
module box_cdc #(parameter WIDTH=35)(input src_clk, input src_rst, input src_update,
    input [WIDTH-1:0] src_data, input dst_clk, input dst_rst,
    output reg [WIDTH-1:0] dst_data);
    // Bundled-data mailbox. Holding register is immutable until acknowledgement.
    // Requests arrive only once per camera frame; destination responds in <1 us.
    reg [WIDTH-1:0] holding;
    reg request, acknowledge;
    wire ack_sync, req_sync;
    sync_bit a(.clk(src_clk),.rst(src_rst),.din(acknowledge),.dout(ack_sync));
    sync_bit b(.clk(dst_clk),.rst(dst_rst),.din(request),.dout(req_sync));
    always @(posedge src_clk or posedge src_rst)
        if (src_rst) begin holding<=0; request<=0; end
        else if (src_update && request==ack_sync) begin
            holding<=src_data; request<=!request;
        end
    always @(posedge dst_clk or posedge dst_rst)
        if (dst_rst) begin dst_data<=0; acknowledge<=0; end
        else if (req_sync!=acknowledge) begin
            dst_data<=holding; acknowledge<=req_sync;
        end
endmodule
