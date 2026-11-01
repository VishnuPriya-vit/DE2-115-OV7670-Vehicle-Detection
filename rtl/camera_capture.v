`timescale 1ns/1ps
module camera_capture(input pclk, input rst, input vsync, input href,
    input [7:0] data, output reg frame_start, output reg pixel_valid,
    output reg [15:0] pixel, output reg [8:0] x,
    output reg [7:0] y, output reg [16:0] address);
    reg vs_d, href_d, second_byte, armed;
    reg [7:0] high_byte;
    reg [10:0] raw_x;
    reg [9:0] raw_y;
    reg [16:0] next_address;
    always @(posedge pclk or posedge rst) begin
        if (rst) begin
            vs_d<=0; href_d<=0; second_byte<=0; armed<=0;
            high_byte<=0; raw_x<=0; raw_y<=0; next_address<=0;
            frame_start<=0; pixel_valid<=0; pixel<=0;
            x<=0; y<=0; address<=0;
        end else begin
            vs_d<=vsync; href_d<=href;
            frame_start<=0; pixel_valid<=0;
            if (vsync && !vs_d) begin
                frame_start<=1; armed<=1;
                raw_x<=0; raw_y<=0; next_address<=0; second_byte<=0;
            end else if (vsync) begin
                raw_x<=0; raw_y<=0; second_byte<=0;
            end else if (armed) begin
                if (href) begin
                    if (!second_byte) begin
                        high_byte<=data; second_byte<=1;
                    end else begin
                        second_byte<=0;
                        if (raw_x<640 && raw_y<480 && !raw_x[0] && !raw_y[0]) begin
                            pixel<={high_byte,data}; pixel_valid<=1;
                            x<=raw_x[9:1]; y<=raw_y[8:1];
                            address<=next_address; next_address<=next_address+1'b1;
                        end
                        if (raw_x<1023) raw_x<=raw_x+1'b1;
                    end
                end else begin
                    raw_x<=0; second_byte<=0;
                    if (href_d && raw_y<1023) raw_y<=raw_y+1'b1;
                end
            end
        end
    end
endmodule
