`timescale 1ns/1ps
module ov7670_rom(input [7:0] index, output reg [15:0] word,
    output reg last);
    // 0: software reset; controller waits 10 ms after every write.
    // CLKRC=40: direct external clock; DBLV=0A: sensor PLL bypass.
    // COM7=04, RGB444=00, COM15=D0: full-range RGB565.
    // COM10=00: positive VSYNC/HREF and continuous PCLK (blanking included).
    // Auto exposure/gain/white balance remain enabled. See tuning guide.
    always @* begin
        last=0;
        case(index)
            8'd0: word=16'h1280;
            8'd1: word=16'h1140;
            8'd2: word=16'h6b0a;
            8'd3: word=16'h1204;
            8'd4: word=16'h8c00;
            8'd5: word=16'h0400;
            8'd6: word=16'h40d0;
            8'd7: word=16'h0c00;
            8'd8: word=16'h3e00;
            8'd9: word=16'h1500;
            8'd10: word=16'h3a04;
            8'd11: word=16'h3dc0;
            8'd12: word=16'h1713;
            8'd13: word=16'h1801;
            8'd14: word=16'h32b6;
            8'd15: word=16'h1902;
            8'd16: word=16'h1a7a;
            8'd17: word=16'h030a;
            8'd18: word=16'h703a;
            8'd19: word=16'h7135;
            8'd20: word=16'h7211;
            8'd21: word=16'h73f0;
            8'd22: word=16'ha202;
            8'd23: word=16'h1e07;
            8'd24: word=16'h13e7;
            8'd25: word=16'h1418;
            8'd26: word=16'h2475;
            8'd27: word=16'h2563;
            8'd28: word=16'h26a5;
            8'd29: word=16'h0e61;
            8'd30: word=16'h0f4b;
            8'd31: word=16'h1602;
            8'd32: word=16'h2102;
            8'd33: word=16'h2291;
            8'd34: word=16'h2907;
            8'd35: word=16'h330b;
            8'd36: word=16'h350b;
            8'd37: word=16'h371d;
            8'd38: word=16'h3871;
            8'd39: word=16'h392a;
            8'd40: word=16'h3c78;
            8'd41: word=16'h4d40;
            8'd42: word=16'h4e20;
            8'd43: word=16'h6900;
            8'd44: word=16'h7410;
            8'd45: word=16'hb084;
            8'd46: word=16'h430a;
            8'd47: word=16'h44f0;
            8'd48: word=16'h4534;
            8'd49: word=16'h4658;
            8'd50: word=16'h4728;
            8'd51: word=16'h483a;
            8'd52: word=16'h5988;
            8'd53: word=16'h5a88;
            8'd54: word=16'h5b44;
            8'd55: word=16'h5c67;
            8'd56: word=16'h5d49;
            8'd57: word=16'h5e0e;
            8'd58: word=16'h6c0a;
            8'd59: word=16'h6d55;
            8'd60: word=16'h6e11;
            8'd61: word=16'h6f9f;
            8'd62: word=16'h6a40;
            8'd63: word=16'h0140;
            8'd64: word=16'h0260;
            8'd65: word=16'h4fb3;
            8'd66: word=16'h50b3;
            8'd67: word=16'h5100;
            8'd68: word=16'h523d;
            8'd69: word=16'h53a7;
            8'd70: word=16'h54e4;
            8'd71: word=16'h589e;
            8'd72: word=16'h4108;
            8'd73: word=16'h3f00;
            8'd74: word=16'h7505;
            8'd75: word=16'h76e1;
            8'd76: word=16'h4c00;
            8'd77: word=16'h7701;
            8'd78: word=16'h4b09;
            8'd79: word=16'hc960;
            8'd80: word=16'h5640;
            8'd81: word=16'h3411;
            8'd82: word=16'h3b0a;
            8'd83: word=16'h4200;
            8'd84: begin word=0; last=1; end
            default: begin word=0; last=1; end
        endcase
    end
endmodule
