`timescale 1ns/1ps
module tb_text;
    reg [9:0] x=0,y=0;
    reg enable=0;
    wire ink,expected,candidate_ink;
    status_text #(.OBJECT_MODE(1)) candidate_label(.x(x),.y(y),.enable(enable),.ink(candidate_ink));
    integer xx,yy,errors=0;
    status_text dut(.x(x),.y(y),.enable(enable),.ink(ink));
    text_reference ref_model(.x(x),.y(y),.enable(enable),.ink(expected));
    initial begin
        for(yy=0;yy<525;yy=yy+1)for(xx=0;xx<800;xx=xx+1)begin
            x=xx;y=yy;enable=1;#1;
            if(ink!==expected)begin errors=errors+1;if(errors<5)$display("FAIL text x=%0d y=%0d",xx,yy);end
            enable=0;#1;
            if(ink!==0)begin errors=errors+1;if(errors<5)$display("FAIL disabled text");end
        end
        enable=1;x=16;y=16;#1;if(candidate_ink!==0)errors=errors+1;
        x=18;#1;if(candidate_ink!==1)errors=errors+1;
        x=88;#1;if(candidate_ink!==0)errors=errors+1;
        x=196;#1;if(candidate_ink!==1)errors=errors+1;
        if(errors==0)$display("PASS: new text ROM matches golden renderer at every 800x525 position; enable/disable and OBJECT CANDIDATE bypass label checked");
        else $display("FAIL: text mismatches=%0d",errors);
        $finish;
    end
endmodule
