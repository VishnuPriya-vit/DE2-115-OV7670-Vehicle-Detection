`timescale 1ns/1ps
module vga_display # (parameter TEST_BARS=0, parameter BOX_COUNT=1, parameter SHOW_TEXT=0, parameter OBJECT_MODE=0)(
    input clk, input rst, input clk25, input frame_ready,
    input [35*BOX_COUNT-1:0] box_data, input [15:0] ram_data,
    output [16:0] ram_address,
    output reg [7:0] red, green, blue,
    output reg hs, vs, blank_n, output sync_n);
    reg [9:0] h,v;
    reg [35*BOX_COUNT-1:0] active_box;
    wire active=(h<640 && v<480);
    wire [BOX_COUNT-1:0] borders;
    wire border=|borders;
    wire [BOX_COUNT-1:0] valid_boxes;
    wire text_ink;
    reg overlay_d;
    status_text #(.OBJECT_MODE(OBJECT_MODE)) label(.x(h),.y(v),.enable((|valid_boxes) && SHOW_TEXT),.ink(text_ink));
    genvar k;
    generate for (k=0;k<BOX_COUNT;k=k+1) begin: outlines
        assign valid_boxes[k]=active_box[k*35+34];
        wire [34:0] box_bits=active_box[k*35 +: 35];
        wire [9:0] left={box_bits[33:25],1'b0};
        wire [9:0] right={box_bits[24:16],1'b1};
        wire [9:0] top_y={1'b0,box_bits[15:8],1'b0};
        wire [9:0] bottom={1'b0,box_bits[7:0],1'b1};
        assign borders[k]=box_bits[34] && h>=left && h<=right &&
            v>=top_y && v<=bottom && ((h-left<4)||(right-h<4)||
            (v-top_y<4)||(bottom-v<4));
    end endgenerate
    wire [16:0] row_base=({9'b0,v[8:1]}<<8)+({9'b0,v[8:1]}<<6);
    assign ram_address=active ? row_base+{8'b0,h[9:1]} : 17'd0;
    assign sync_n=1'b0;
    // h/v advance at VGA_CLK falling edges. Precompute the overlay on the
    // intervening CLOCK_50 edge, then emit it with the matching RAM pixel at
    // the next falling edge. This breaks the coordinate-to-RGB timing path.
    always @(posedge clk or posedge rst)
        if(rst) overlay_d<=1'b0;
        else if(!clk25) overlay_d<=border || text_ink;
    // h/v describe the NEXT output pixel. At a falling VGA_CLK edge output
    // ram_data for h/v, then advance h/v. On the intervening rising edge
    // frame_ram reads the new address; it is ready for the next falling edge.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            h<=0; v<=0; red<=0; green<=0; blue<=0;
            hs<=1; vs<=1; blank_n<=0; active_box<=0;
        end else if (clk25) begin
            hs<=!(h>=656 && h<752); vs<=!(v>=490 && v<492);
            blank_n<=active;
            red<=0; green<=0; blue<=0;
            if (active) begin
                if (TEST_BARS) begin
                    red <= (h<80 || (h>=240 && h<400) || h>=560) ? 8'd255:8'd0;
                    green <= (h<240 || (h>=400 && h<480)) ? 8'd255:8'd0;
                    blue <= (h<80 || (h>=160 && h<320) || (h>=480 && h<560)) ? 8'd255:8'd0;
                end else if (frame_ready) begin
                    if (overlay_d) begin red<=0; green<=255; blue<=0; end
                    else begin
                        red<={ram_data[15:11],ram_data[15:13]};
                        green<={ram_data[10:5],ram_data[10:9]};
                        blue<={ram_data[4:0],ram_data[4:2]};
                    end
                end
            end
            if (h==799) begin
                h<=0;
                if (v==524) v<=0; else v<=v+1'b1;
            end else h<=h+1'b1;
            // Hold a coherent box for the full VGA frame.
            if (h==0 && v==480) active_box<=box_data;
        end
    end
endmodule
