`timescale 1ns/1ps
module tb_shadows;
    reg clk=0,rst=1,fs=0,pv=0;
    always #20 clk=~clk;
    reg [15:0] pixel=0;
    reg [8:0] x=0;
    reg [7:0] y=0;
    reg [16:0] address=0;
    wire update,ready,fr,bad,processing;
    wire [104:0] boxes;
    wire [5:0] ids;
    wire [29:0] costs;
    integer xx,yy,t,cycles,errors=0;
    vehicle_engine #(.WARMUP_FRAMES(0),.LEARN_FRAMES(1),.RECOGNITION_BYPASS(1),.DRAW_MARGIN(0)) dut(
        .clk(clk),.rst(rst),.frame_start(fs),.relearn(1'b0),.pixel_valid(pv),.pixel(pixel),
        .x(x),.y(y),.address(address),.box_update(update),.boxes(boxes),.background_ready(ready),
        .frame_ready(fr),.bad_frame(bad),.processing(processing),.class_ids(ids),.best_costs(costs));
    task boundary;
        begin
            @(negedge clk);fs=1;pv=0;
            @(negedge clk);fs=0;cycles=0;
            while(!update && cycles<30000)begin @(negedge clk);cycles=cycles+1;end
            if(!update)begin errors=errors+1;$display("FAIL shadow processing timeout");end
            repeat(4)@(negedge clk);
        end
    endtask
    task frame;
        input integer kind;
        begin
            for(yy=0;yy<240;yy=yy+1)for(xx=0;xx<320;xx=xx+1)begin
                @(negedge clk);pv=1;x=xx;y=yy;address=yy*320+xx;
                case(kind)
                    0:pixel=16'h2104; // Empty learn scene.
                    1:pixel=16'h0000; // Full-frame neutral darkening/shadow.
                    2:pixel=16'h8410; // Full-frame neutral brightening.
                    3:pixel=16'hde96; // Warm off-white, formerly yellow by absolute differences.
                    4:pixel=(xx[2:0]==0 && yy[2:0]==0) ? 16'hffe0:16'h2104;
                    5,6,7,8:begin
                        pixel=16'h8410;
                        if(xx<180 && yy>60)pixel=16'h0000; // Large neutral shadow.
                        if(xx>=200 && xx<248 && yy>=40 && yy<72)begin
                            pixel=16'hffe0;
                            if(kind==7)pixel=16'h2940; // Dim saturated yellow: below old absolute gates.
                            if(kind==8)pixel=16'h2900; // Gray approximately equals learned background.
                        end
                    end
                    9:pixel=(!xx[0]) ? 16'hffe0 : 16'h2104;
                    10:pixel=(xx[1:0]<2) ? 16'hffe0 : 16'h2104;
                    default:pixel=16'h2104;
                endcase
                @(negedge clk);pv=0;repeat(2)@(negedge clk);
            end
            repeat(3)@(negedge clk);boundary;
        end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;boundary;frame(0);
        if(!ready)begin errors=errors+1;$display("FAIL shadow test learning");end
        for(t=1;t<=10;t=t+1)begin
            frame(t);
            if((t<5 || t>=9) && boxes!==0)begin errors=errors+1;$display("FAIL shadow/noise case %0d boxes=%h",t,boxes);end
            if(t>=5 && t<=8 && boxes!=={70'd0,1'b1,9'd200,9'd247,8'd40,8'd71})begin
                errors=errors+1;$display("FAIL colored object amid neutral changes case %0d boxes=%h",t,boxes);
            end
            if(bad)begin errors=errors+1;$display("FAIL valid shadow frame marked bad");end
        end
        if(errors==0)$display("PASS: neutral full-frame shadows/brightness shifts, warm off-white and sparse and dense unconnected yellow speckles rejected; dim and near-equal-gray yellow candidates remain stable with bypass enabled");
        else $display("FAIL shadow errors=%0d",errors);
        $finish;
    end
    initial begin #180000000;$display("FAIL shadow timeout");$finish;end
endmodule
