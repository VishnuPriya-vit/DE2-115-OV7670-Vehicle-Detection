`timescale 1ns/1ps
module tb_sccb;
    reg clk=0,rst=1;
    always #10 clk=~clk;
    wire scl,done,nack;
    tri1 sda;
    // No slave response: intentionally exercise SCCB don't-care ninth bits.
    sccb_config #(.QUARTER_CYCLES(2),.WAIT_CYCLES(8)) dut(
        .clk(clk),.rst(rst),.scl(scl),.sda(sda),.done(done),.nack_seen(nack));
    integer errors=0,transactions=0,bits=0,bytes=0;
    reg active=0;
    reg [7:0] shift=0;
    reg [23:0] transaction=0;
    reg [7:0] rom_index=0;
    wire [15:0] rom_word;
    wire last;
    ov7670_rom expected_rom(.index(rom_index),.word(rom_word),.last(last));
    always @(negedge sda) if(scl && !rst) begin
        active=1; bits=0; bytes=0; shift=0; transaction=0;
    end
    always @(posedge scl) if(active && !rst) begin
        if(bits<8) begin shift={shift[6:0],sda}; bits=bits+1; end
        else begin
            transaction={transaction[15:0],shift};
            bytes=bytes+1; bits=0;
        end
    end
    always @(posedge sda) if(scl && active && !rst) begin
        active=0;
        if(bytes!=3 || transaction!=={8'h42,rom_word}) begin
            $display("FAIL SCCB index %0d transaction %h expected 42%h bytes=%0d",
                rom_index,transaction,rom_word,bytes); errors=errors+1;
        end
        transactions=transactions+1; rom_index=rom_index+1;
    end
    initial begin
        repeat(4) @(negedge clk); rst=0;
        wait(done); #100;
        if(!last || transactions<80 || !nack) errors=errors+1;
        if(errors==0) $display("PASS: SCCB %0d ROM writes, address 42, three bytes, START/STOP and released ninth bits",transactions);
        else $display("FAIL: %0d SCCB errors",errors);
        $finish;
    end
    initial begin #5000000; $display("FAIL SCCB timeout"); $finish; end
endmodule
