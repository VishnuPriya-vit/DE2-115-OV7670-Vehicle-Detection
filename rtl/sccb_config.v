`timescale 1ns/1ps
module sccb_config #(parameter QUARTER_CYCLES=125, parameter WAIT_CYCLES=500000)(
    input clk, input rst, output reg scl, inout sda,
    output reg done, output reg nack_seen);
    // 50 MHz / (4*125) = 100 kHz. SDA is never driven high.
    // SCCB ninth bits are don't-care for completion; nack_seen is diagnostic.
    // No clock stretching or register readback is implemented.
    reg sda_low;
    assign sda=sda_low ? 1'b0 : 1'bz;
    reg [7:0] index;
    wire [15:0] word;
    wire last;
    ov7670_rom rom(.index(index),.word(word),.last(last));
    integer wait_count, tick_count;
    reg [3:0] state;
    reg [1:0] phase, byte_no;
    reg [3:0] bit_no;
    reg [7:0] txbyte;
    localparam WAIT=0, START=1, BITS=2, ACK=3, STOP=4, FINISH=5;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scl<=1; sda_low<=0; done<=0; nack_seen<=0;
            index<=0; wait_count<=0; tick_count<=0; state<=WAIT;
            phase<=0; byte_no<=0; bit_no<=7; txbyte<=8'h42;
        end else if (!done) begin
            if (state==WAIT) begin
                scl<=1; sda_low<=0;
                if (wait_count==WAIT_CYCLES-1) begin
                    wait_count<=0; tick_count<=0; phase<=0;
                    if (last) begin done<=1; state<=FINISH; end
                    else begin state<=START; byte_no<=0; bit_no<=7; txbyte<=8'h42; end
                end else wait_count<=wait_count+1;
            end else if (tick_count==QUARTER_CYCLES-1) begin
                tick_count<=0;
                case(state)
                    START: begin
                        case(phase)
                            0: begin scl<=1; sda_low<=0; end
                            1: sda_low<=1;
                            2: scl<=0;
                            3: begin state<=BITS; end
                        endcase
                        phase<=phase+1'b1;
                    end
                    BITS: begin
                        case(phase)
                            0: begin scl<=0; sda_low<=!txbyte[bit_no]; end
                            1: scl<=1;
                            2: scl<=1;
                            3: begin
                                scl<=0;
                                if (bit_no==0) state<=ACK;
                                else bit_no<=bit_no-1'b1;
                            end
                        endcase
                        phase<=phase+1'b1;
                    end
                    ACK: begin
                        case(phase)
                            0: begin scl<=0; sda_low<=0; end
                            1: scl<=1;
                            2: if (sda) nack_seen<=1;
                            3: begin
                                scl<=0; bit_no<=7;
                                if (byte_no==2) state<=STOP;
                                else begin
                                    byte_no<=byte_no+1'b1;
                                    txbyte<=(byte_no==0) ? word[15:8]:word[7:0];
                                    state<=BITS;
                                end
                            end
                        endcase
                        phase<=phase+1'b1;
                    end
                    STOP: begin
                        case(phase)
                            0: begin scl<=0; sda_low<=1; end
                            1: scl<=1;
                            2: sda_low<=0;
                            3: begin state<=WAIT; index<=index+1'b1; end
                        endcase
                        phase<=phase+1'b1;
                    end
                    default: state<=WAIT;
                endcase
            end else tick_count<=tick_count+1;
        end
    end
endmodule
