`timescale 1ns/1ps
module tb_top #(parameter STABLE=0);
    reg CLOCK_50=0;
    always #10 CLOCK_50=~CLOCK_50;
    // Independent phase; source changes data at falling PCLK edges.
    reg pclk=0;
    initial begin #7; forever #20 pclk=~pclk; end
    reg [1:0] key=2'b11;
    reg vsync=0,href=0;
    reg [7:0] data=0;
    tri1 sda;
    wire scl,xclk,cam_reset,pwdn;
    wire vc,blank,sync,hs,vs;
    wire [7:0] r,g,b;
    integer errors=0, captures=0, completed=0;
    integer xx,yy;
    reg [15:0] colour;
    reg [1:0] a[0:255],bref[0:255],c[0:255];
    top #(.STABILIZE_BOXES(STABLE),.WARMUP_FRAMES(0),.LEARN_FRAMES(2),.YELLOW_FOREGROUND(0),.TILE_MIN_HITS(4),.DRAW_MARGIN(0),.POR_CYCLES(8),
        .SCCB_QUARTER_CYCLES(2),.SCCB_WAIT_CYCLES(8)) dut(
        .CLOCK_50(CLOCK_50),.KEY(key),.CAM_D(data),.CAM_PCLK(pclk),
        .CAM_HREF(href),.CAM_VSYNC(vsync),.CAM_XCLK(xclk),.CAM_SCL(scl),
        .CAM_SDA(sda),.CAM_RESET(cam_reset),.CAM_PWDN(pwdn),
        .VGA_CLK(vc),.VGA_BLANK_N(blank),.VGA_SYNC_N(sync),
        .VGA_HS(hs),.VGA_VS(vs),.VGA_R(r),.VGA_G(g),.VGA_B(b));
    function [34:0] box;
        input integer x0,x1,y0,y1;
        begin box={1'b1,x0[8:0],x1[8:0],y0[7:0],y1[7:0]};end
    endfunction
    function [15:0] rgb;
        input [1:0] cat;
        begin case(cat) 1:rgb=16'hffe0;2:rgb=16'h0000;default:rgb=16'h8410;endcase end
    endfunction
    function [15:0] scene;
        input integer kind,px,py;
        integer dx,dy,idx;
        begin
            scene=16'h2104;
            dx=(kind==4) ? 40:20;dy=(kind==4) ? 40:32;
            if(kind>=1 && kind<=6 && px>=dx && px<dx+96 && py>=dy && py<dy+54)begin
                idx=((py-dy)*16/54)*16+(px-dx)*16/96;
                scene=(kind==5) ? 16'hffe0:rgb(a[idx]);
            end
            dx=(kind==3) ? 20:((kind==4) ? 180:160);
            dy=(kind==3 || kind==4) ? 128:112;
            if((kind==2 || kind==3 || kind==4 || kind==6) && px>=dx && px<dx+80 && py>=dy && py<dy+48)begin
                idx=((py-dy)*16/48)*16+(px-dx)*16/80;scene=rgb(bref[idx]);
            end
            if(kind==6 && px>=240 && px<310 && py>=176 && py<232)begin
                idx=((py-176)*16/56)*16+(px-240)*16/70;scene=rgb(c[idx]);
            end
            if(kind==7 && px>=2 && px<4 && py>=2 && py<4)scene=16'hffff;
        end
    endfunction
    task fail;
        input [511:0] msg;
        begin errors=errors+1; $display("FAIL: %0s at %0t",msg,$time); end
    endtask
    // 800 pixel periods/line, 525 lines/frame. RGB565 uses TWO PCLKs/pixel.
    // Vertical blank starts with positive VSYNC for 2 lines, followed by 43
    // blank lines. HREF is asserted for exactly 1280 PCLKs on each active line.
    task frame_boundary;
        begin
            @(negedge pclk); href=0; vsync=1;
            repeat(3200) @(negedge pclk);
            vsync=0;
            repeat(68800) @(negedge pclk);
        end
    endtask
    task active_frame;
        input integer kind;
        begin
            captures=0;
            for (yy=0;yy<480;yy=yy+1) begin
                for (xx=0;xx<640;xx=xx+1) begin
                    colour=scene(kind,xx/2,yy/2);
                    @(negedge pclk); href=1; data=colour[15:8];
                    @(negedge pclk); data=colour[7:0];
                end
                @(negedge pclk); href=0;
                repeat(319) @(negedge pclk);
            end
            if (captures!=76800) fail("capture must emit 76800 downsampled pixels");
        end
    endtask
    task check_boxes;
        input [104:0] expected;
        begin
            $display("CAMERA boxes=%h expected=%h",dut.recognized_boxes,expected);
            if(dut.recognized_boxes!==expected)fail("wrong recognized camera boxes");
            if(dut.box_display!==(STABLE ? dut.stable_boxes : expected))fail("105-bit box CDC mismatch");
            if(dut.bad_frame || dut.processing)fail("frame invalid or processing exceeded blanking");
        end
    endtask
    always @(posedge pclk) begin
        if (dut.pixel_valid && !dut.cam_rst) begin
            if (dut.address!==captures) fail("capture address sequence");
            if (dut.x!==captures%320 || dut.y!==captures/320)
                fail("capture x/y sequence");
            captures=captures+1;
        end
    end
    // VGA signal checker: verify all 800x525 slots against output coordinates.
    integer vh=0,vv=0, active_count=0, hslow=0,vslow=0,vga_frames=0;
    integer green_pixels=0, colour_pixels=0;
    reg vga_armed=0;
    always @(posedge CLOCK_50) if (dut.clk25) begin
        if (dut.sys_rst) begin vh=0; vv=0; vga_armed=0; end
        else begin
            #1;
            vga_armed=1;
            if (blank!==(vh<640 && vv<480)) fail("VGA blank polarity/position");
            if (hs!==!(vh>=656 && vh<752)) fail("VGA horizontal sync");
            if (vs!==!(vv>=490 && vv<492)) fail("VGA vertical sync");
            if (sync!==0) fail("VGA_SYNC_N must be low");
            if (blank) active_count=active_count+1;
            if (!hs) hslow=hslow+1;
            if (!vs) vslow=vslow+1;
            if (blank && {r,g,b}===24'h00ff00) green_pixels=green_pixels+1;
            if (blank && {r,g,b}===24'h212021) colour_pixels=colour_pixels+1;
            if (vh==799) begin
                vh=0;
                if(vv==524) begin
                    vv=0; vga_frames=vga_frames+1;
                    if(active_count!=307200 || hslow!=50400 || vslow!=1600)
                        fail("VGA frame totals");
                    active_count=0; hslow=0; vslow=0;
                end else vv=vv+1;
            end else vh=vh+1;
        end
    end
    // Data must not change at DAC rising edge.
    reg [26:0] stable_dac;
    always @(negedge vc) begin #2; stable_dac={r,g,b,hs,vs,blank}; end
    always @(posedge vc) begin
        #1;
        if (!dut.sys_rst && vga_armed && stable_dac!=={r,g,b,hs,vs,blank})
            fail("DAC outputs changed at VGA_CLK rising edge");
    end
    initial begin
        $readmemh("../reference/dump_truck_categories.hex",a);
        $readmemh("../reference/van_categories.hex",bref);
        $readmemh("../reference/construction_truck_categories.hex",c);
        wait(dut.cfg_done);wait(!dut.cam_rst);
        frame_boundary;active_frame(0);
        frame_boundary;active_frame(0);
        frame_boundary;
        if(!dut.background_ready)fail("learning not complete");
        check_boxes(0);
        active_frame(2);frame_boundary;
        check_boxes({35'd0,box(160,239,112,159),box(20,115,32,85)});
        active_frame(3);frame_boundary;
        check_boxes({35'd0,box(20,99,128,175),box(20,115,32,85)});
        active_frame(1);frame_boundary;
        check_boxes({70'd0,box(20,115,32,85)});
        active_frame(5);frame_boundary;check_boxes(0);
        active_frame(0);frame_boundary;check_boxes(0);
        if(vga_frames<2 || green_pixels==0 || colour_pixels==0)fail("missing VGA coverage");
        key[0]=0;repeat(10) @(negedge CLOCK_50);
        if(dut.cfg_done || !dut.cam_rst || dut.recognized_boxes!==0)fail("KEY0 restart reset");
        key[0]=1;wait(dut.cfg_done);wait(!dut.cam_rst);
        if(dut.background_ready || dut.frame_ready)fail("stale state after reset");
        $display("VGA frames=%0d green pixels=%0d live colour pixels=%0d",vga_frames,green_pixels,colour_pixels);
        if(errors==0)$display("PASS: full camera timing, two empty frames, template recognition, horizontal/vertical two-box separation, removal, solid-color rejection, reset, 105-bit CDC and VGA/DAC timing");
        else $display("FAIL: %0d errors",errors);
        $finish;
    end
    initial begin #1000000000; fail("simulation timeout"); $finish; end
endmodule

module tb_top_stable;
 tb_top #(.STABLE(1)) test();
endmodule
