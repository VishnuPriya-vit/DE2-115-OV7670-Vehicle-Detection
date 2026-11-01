`timescale 1ns/1ps
module pixel_category(input [15:0] pixel, output [1:0] category);
    wire [7:0] r={pixel[15:11],pixel[15:13]};
    wire [7:0] g={pixel[10:5],pixel[10:9]};
    wire [7:0] b={pixel[4:0],pixel[4:2]};
    // Relative blue suppression rejects warm off-white surfaces that the
    // old absolute color differences alone could classify as yellow.
    wire [10:0] blue5={1'b0,b,2'b0}+{3'b0,b};
    wire [10:0] green3={3'b0,g}+{2'b0,g,1'b0};
    wire yellow=(blue5<=green3 && r>=32 && g>=24 && {1'b0,r}>={1'b0,b}+9'd16 &&
                 {1'b0,g}>={1'b0,b}+9'd12 &&
                 {r,2'b0}>=({2'b0,g}+{1'b0,g,1'b0}));
    wire dark=(r<96 && g<96 && b<96);
    assign category=yellow ? 2'd1 : (dark ? 2'd2 : 2'd0);
endmodule
