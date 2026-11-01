`timescale 1ns/1ps
// 5x7 font, 2x enlargement, at VGA screen coordinate (16,16).
module text_reference(input [9:0] x,y,input enable,output ink);
    wire in_area=(x>=16 && x<208 && y>=16 && y<30);
    wire [9:0] dx=x-10'd16,dy=y-10'd16;
    wire [3:0] character=dx/12;
    wire [3:0] column=(dx%12)/2;
    wire [2:0] row=dy[3:1];
    reg [7:0] letter;
    reg [34:0] glyph;
    always @* begin
        case(character)
            0:letter="V";1:letter="E";2:letter="H";3:letter="I";
            4:letter="C";5:letter="L";6:letter="E";7:letter=" ";
            8:letter="D";9:letter="E";10:letter="T";11:letter="E";
            12:letter="C";13:letter="T";14:letter="E";15:letter="D";
            default:letter=" ";
        endcase
        case(letter)
            "V":glyph=35'b10001_10001_10001_10001_10001_01010_00100;
            "E":glyph=35'b11111_10000_10000_11110_10000_10000_11111;
            "H":glyph=35'b10001_10001_10001_11111_10001_10001_10001;
            "I":glyph=35'b11111_00100_00100_00100_00100_00100_11111;
            "C":glyph=35'b01111_10000_10000_10000_10000_10000_01111;
            "L":glyph=35'b10000_10000_10000_10000_10000_10000_11111;
            "D":glyph=35'b11110_10001_10001_10001_10001_10001_11110;
            "T":glyph=35'b11111_00100_00100_00100_00100_00100_00100;
            default:glyph=0;
        endcase
    end
    assign ink=enable && in_area && column<5 && glyph[34-row*5-column];
endmodule
