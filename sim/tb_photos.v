`timescale 1ns/1ps
module tb_photos;
    reg clk=0,rst=1,fs=0,relearn=0,pv=0;
    always #20 clk=~clk;
    reg [15:0] pixel=0;
    reg [8:0] x=0;
    reg [7:0] y=0;
    reg [16:0] address=0;
    wire update,ready,fr,bad,processing;
    wire [104:0] boxes;
    wire [5:0] ids;
    wire [29:0] costs;
    reg [1:0] a[0:255],b[0:255],c[0:255];
    reg [15:0] photo[0:76799];
    reg [104:0] expected_boxes[0:114];
    reg [5:0] expected_ids[0:114];
    integer n;
    integer xx,yy,errors=0,cycles,max_cycles=0;
    vehicle_engine #(.WARMUP_FRAMES(0),.LEARN_FRAMES(2)) dut(
        .clk(clk),.rst(rst),.frame_start(fs),.relearn(relearn),.pixel_valid(pv),
        .pixel(pixel),.x(x),.y(y),.address(address),.box_update(update),.boxes(boxes),
        .background_ready(ready),.frame_ready(fr),.bad_frame(bad),.processing(processing),
        .class_ids(ids),.best_costs(costs));
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
                idx=((py-dy)*16/48)*16+(px-dx)*16/80;scene=rgb(b[idx]);
            end
            if(kind==6 && px>=240 && px<310 && py>=176 && py<232)begin
                idx=((py-176)*16/56)*16+(px-240)*16/70;scene=rgb(c[idx]);
            end
            if(kind==7 && px>=2 && px<4 && py>=2 && py<4)scene=16'hffff;
        end
    endfunction
    task boundary;
        begin
            @(negedge clk);fs=1;pv=0;
            @(negedge clk);fs=0;cycles=0;
            while(!update && cycles<30000)begin @(negedge clk);cycles=cycles+1;end
            if(cycles>max_cycles)max_cycles=cycles;
            if(!update)begin errors=errors+1;$display("FAIL engine processing timeout");end
            repeat(4) @(negedge clk);
        end
    endtask
    task frame;
        input integer kind;
        begin
            for(yy=0;yy<240;yy=yy+1)for(xx=0;xx<320;xx=xx+1)begin
                @(negedge clk);pv=1;x=xx;y=yy;address=yy*320+xx;pixel=(kind==0) ? 16'h2104 : photo[yy*320+xx];
                @(negedge clk);pv=0;
                repeat(2) @(negedge clk);
            end
            repeat(3) @(negedge clk);
            boundary;
        end
    endtask
    task check;
        input [104:0] expected;
        begin
            $display("ENGINE boxes=%h classes=%h costs=%h processing_clocks=%0d",boxes,ids,costs,cycles);
            if(boxes!==expected || bad)begin errors=errors+1;$display("FAIL engine boxes expected %h bad=%b",expected,bad);end
        end
    endtask
    initial begin
        $readmemh("vectors/photo_expected.hex",expected_boxes);
        $readmemh("vectors/photo_ids.hex",expected_ids);
        repeat(4) @(negedge clk);rst=0;
        boundary;frame(0);frame(0);
        for(n=0;n<115;n=n+1)begin
            case(n)
                0:$readmemh("vectors/photo_scene_0.hex",photo);
                1:$readmemh("vectors/photo_scene_1.hex",photo);
                2:$readmemh("vectors/photo_scene_2.hex",photo);
                3:$readmemh("vectors/photo_scene_3.hex",photo);
                4:$readmemh("vectors/photo_scene_4.hex",photo);
                5:$readmemh("vectors/photo_scene_5.hex",photo);
                6:$readmemh("vectors/photo_scene_6.hex",photo);
                7:$readmemh("vectors/photo_scene_7.hex",photo);
                8:$readmemh("vectors/photo_scene_8.hex",photo);
                9:$readmemh("vectors/photo_scene_9.hex",photo);
                10:$readmemh("vectors/photo_scene_10.hex",photo);
                11:$readmemh("vectors/photo_scene_11.hex",photo);
                12:$readmemh("vectors/photo_scene_12.hex",photo);
                13:$readmemh("vectors/photo_scene_13.hex",photo);
                14:$readmemh("vectors/photo_scene_14.hex",photo);
                15:$readmemh("vectors/photo_scene_15.hex",photo);
                16:$readmemh("vectors/photo_scene_16.hex",photo);
                17:$readmemh("vectors/photo_scene_17.hex",photo);
                18:$readmemh("vectors/photo_scene_18.hex",photo);
                19:$readmemh("vectors/photo_scene_19.hex",photo);
                20:$readmemh("vectors/photo_scene_20.hex",photo);
                21:$readmemh("vectors/photo_scene_21.hex",photo);
                22:$readmemh("vectors/photo_scene_22.hex",photo);
                23:$readmemh("vectors/photo_scene_23.hex",photo);
                24:$readmemh("vectors/photo_scene_24.hex",photo);
                25:$readmemh("vectors/photo_scene_25.hex",photo);
                26:$readmemh("vectors/photo_scene_26.hex",photo);
                27:$readmemh("vectors/photo_scene_27.hex",photo);
                28:$readmemh("vectors/photo_scene_28.hex",photo);
                29:$readmemh("vectors/photo_scene_29.hex",photo);
                30:$readmemh("vectors/photo_scene_30.hex",photo);
                31:$readmemh("vectors/photo_scene_31.hex",photo);
                32:$readmemh("vectors/photo_scene_32.hex",photo);
                33:$readmemh("vectors/photo_scene_33.hex",photo);
                34:$readmemh("vectors/photo_scene_34.hex",photo);
                35:$readmemh("vectors/photo_scene_35.hex",photo);
                36:$readmemh("vectors/photo_scene_36.hex",photo);
                37:$readmemh("vectors/photo_scene_37.hex",photo);
                38:$readmemh("vectors/photo_scene_38.hex",photo);
                39:$readmemh("vectors/photo_scene_39.hex",photo);
                40:$readmemh("vectors/photo_scene_40.hex",photo);
                41:$readmemh("vectors/photo_scene_41.hex",photo);
                42:$readmemh("vectors/photo_scene_42.hex",photo);
                43:$readmemh("vectors/photo_scene_43.hex",photo);
                44:$readmemh("vectors/photo_scene_44.hex",photo);
                45:$readmemh("vectors/photo_scene_45.hex",photo);
                46:$readmemh("vectors/photo_scene_46.hex",photo);
                47:$readmemh("vectors/photo_scene_47.hex",photo);
                48:$readmemh("vectors/photo_scene_48.hex",photo);
                49:$readmemh("vectors/photo_scene_49.hex",photo);
                50:$readmemh("vectors/photo_scene_50.hex",photo);
                51:$readmemh("vectors/photo_scene_51.hex",photo);
                52:$readmemh("vectors/photo_scene_52.hex",photo);
                53:$readmemh("vectors/photo_scene_53.hex",photo);
                54:$readmemh("vectors/photo_scene_54.hex",photo);
                55:$readmemh("vectors/photo_scene_55.hex",photo);
                56:$readmemh("vectors/photo_scene_56.hex",photo);
                57:$readmemh("vectors/photo_scene_57.hex",photo);
                58:$readmemh("vectors/photo_scene_58.hex",photo);
                59:$readmemh("vectors/photo_scene_59.hex",photo);
                60:$readmemh("vectors/photo_scene_60.hex",photo);
                61:$readmemh("vectors/photo_scene_61.hex",photo);
                62:$readmemh("vectors/photo_scene_62.hex",photo);
                63:$readmemh("vectors/photo_scene_63.hex",photo);
                64:$readmemh("vectors/photo_scene_64.hex",photo);
                65:$readmemh("vectors/photo_scene_65.hex",photo);
                66:$readmemh("vectors/photo_scene_66.hex",photo);
                67:$readmemh("vectors/photo_scene_67.hex",photo);
                68:$readmemh("vectors/photo_scene_68.hex",photo);
                69:$readmemh("vectors/photo_scene_69.hex",photo);
                70:$readmemh("vectors/photo_scene_70.hex",photo);
                71:$readmemh("vectors/photo_scene_71.hex",photo);
                72:$readmemh("vectors/photo_scene_72.hex",photo);
                73:$readmemh("vectors/photo_scene_73.hex",photo);
                74:$readmemh("vectors/photo_scene_74.hex",photo);
                75:$readmemh("vectors/photo_scene_75.hex",photo);
                76:$readmemh("vectors/photo_scene_76.hex",photo);
                77:$readmemh("vectors/photo_scene_77.hex",photo);
                78:$readmemh("vectors/photo_scene_78.hex",photo);
                79:$readmemh("vectors/photo_scene_79.hex",photo);
                80:$readmemh("vectors/photo_scene_80.hex",photo);
                81:$readmemh("vectors/photo_scene_81.hex",photo);
                82:$readmemh("vectors/photo_scene_82.hex",photo);
                83:$readmemh("vectors/photo_scene_83.hex",photo);
                84:$readmemh("vectors/photo_scene_84.hex",photo);
                85:$readmemh("vectors/photo_scene_85.hex",photo);
                86:$readmemh("vectors/photo_scene_86.hex",photo);
                87:$readmemh("vectors/photo_scene_87.hex",photo);
                88:$readmemh("vectors/photo_scene_88.hex",photo);
                89:$readmemh("vectors/photo_scene_89.hex",photo);
                90:$readmemh("vectors/photo_scene_90.hex",photo);
                91:$readmemh("vectors/photo_scene_91.hex",photo);
                92:$readmemh("vectors/photo_scene_92.hex",photo);
                93:$readmemh("vectors/photo_scene_93.hex",photo);
                94:$readmemh("vectors/photo_scene_94.hex",photo);
                95:$readmemh("vectors/photo_scene_95.hex",photo);
                96:$readmemh("vectors/photo_scene_96.hex",photo);
                97:$readmemh("vectors/photo_scene_97.hex",photo);
                98:$readmemh("vectors/photo_scene_98.hex",photo);
                99:$readmemh("vectors/photo_scene_99.hex",photo);
                100:$readmemh("vectors/photo_scene_100.hex",photo);
                101:$readmemh("vectors/photo_scene_101.hex",photo);
                102:$readmemh("vectors/photo_scene_102.hex",photo);
                103:$readmemh("vectors/photo_scene_103.hex",photo);
                104:$readmemh("vectors/photo_scene_104.hex",photo);
                105:$readmemh("vectors/photo_scene_105.hex",photo);
                106:$readmemh("vectors/photo_scene_106.hex",photo);
                107:$readmemh("vectors/photo_scene_107.hex",photo);
                108:$readmemh("vectors/photo_scene_108.hex",photo);
                109:$readmemh("vectors/photo_scene_109.hex",photo);
                110:$readmemh("vectors/photo_scene_110.hex",photo);
                111:$readmemh("vectors/photo_scene_111.hex",photo);
                112:$readmemh("vectors/photo_scene_112.hex",photo);
                113:$readmemh("vectors/photo_scene_113.hex",photo);
                114:$readmemh("vectors/photo_scene_114.hex",photo);
            endcase
            frame(1);check(expected_boxes[n]);
            if(n<53 && ids[1:0]!==((n<14) ? 1 : ((n<32) ? 2 : 3)))begin errors=errors+1;$display("FAIL photo class id");end
            if(n>=61 && n<91 && ids[1:0]!==((n<71) ? 1 : ((n<81) ? 2 : 3)))begin errors=errors+1;$display("FAIL noisy front/rear class");end
            if(n>=91 && ids[1:0]!==((n<99) ? 2 : ((n<107) ? 1 : 3)))begin errors=errors+1;$display("FAIL new front/rear class scene=%0d",n);end
            if(ids!==expected_ids[n])begin errors=errors+1;$display("FAIL three-photo class ids");end
        end
        if(errors==0)$display("PASS: camera-view photo RGB565 fixtures with yellow foreground and wheel margins, 53 PDF views, combined scene, rotated scene, six brightness cases 30 noisy front/rear fixtures and 24 new front/rear scale fixtures agree with independent software model; NOT held-out recognition validation");
        else $display("FAIL photo-scene errors=%0d",errors);
        $finish;
    end
    initial begin #2000000000;$display("FAIL photo-scene timeout");$finish;end
endmodule
