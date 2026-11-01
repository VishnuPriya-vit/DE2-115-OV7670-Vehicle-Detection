`timescale 1ns/1ps
// Three spatial tracks. All logic remains in PCLK domain. One accepted packet
// per frame; processing takes at most 24 clocks. Slots are not class identities.
module box_stabilizer #(parameter CONFIRM_FRAMES=2, DEADBAND=2, HOLD_FRAMES=2, MATCH_DISTANCE=48)(
 input clk,rst,clear,update,input [104:0] boxes_in,
 output reg update_out,output reg [104:0] boxes_out);
 localparam IDLE=0,SEARCH=1,APPLY=2,ALLOCATE=3,PUBLISH=4;
 reg [2:0] state;
 reg [34:0] tracks[0:2], observations[0:2];
 reg [7:0] misses[0:2],seen[0:2];
 reg [2:0] used;
 reg [1:0] track,obs,best_index;
 reg [10:0] best_distance;
 reg found;
 integer k;
 wire [34:0] a=tracks[track], b=observations[obs];
 wire [9:0] ax={1'b0,a[33:25]}+{1'b0,a[24:16]};
 wire [9:0] bx={1'b0,b[33:25]}+{1'b0,b[24:16]};
 wire [8:0] ay={1'b0,a[15:8]}+{1'b0,a[7:0]};
 wire [8:0] by={1'b0,b[15:8]}+{1'b0,b[7:0]};
 wire [9:0] dx=ax>=bx ? ax-bx : bx-ax;
 wire [8:0] dy=ay>=by ? ay-by : by-ay;
 wire [10:0] distance={1'b0,dx}+{2'b0,dy};
 function [8:0] smooth;
  input [8:0] old_value,new_value;
  reg [8:0] delta;
  reg [9:0] total;
  begin
   delta=old_value>=new_value ? old_value-new_value : new_value-old_value;
   total={1'b0,old_value}+{1'b0,new_value}+10'd1;
   if(delta<=DEADBAND) smooth=old_value;
   else if(delta>12) smooth=new_value; // Follow deliberate movement promptly.
   else smooth=total[9:1];
  end
 endfunction
 function [34:0] filtered;
  input [34:0] old_box,new_box;
  reg [8:0] x0,x1,y0,y1;
  begin
   x0=smooth(old_box[33:25],new_box[33:25]);
   x1=smooth(old_box[24:16],new_box[24:16]);
   y0=smooth({1'b0,old_box[15:8]},{1'b0,new_box[15:8]});
   y1=smooth({1'b0,old_box[7:0]},{1'b0,new_box[7:0]});
   if(x0>x1 || y0>y1)filtered=new_box;
   else filtered={1'b1,x0,x1,y0[7:0],y1[7:0]};
  end
 endfunction
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   state<=IDLE;boxes_out<=0;update_out<=0;used<=0;
   track<=0;obs<=0;best_index<=0;best_distance<=2047;found<=0;
   for(k=0;k<3;k=k+1)begin tracks[k]<=0;observations[k]<=0;misses[k]<=0;seen[k]<=0;end
  end else begin
   update_out<=0;
   if(clear)begin
    state<=IDLE;boxes_out<=0;update_out<=1;
    for(k=0;k<3;k=k+1)begin tracks[k]<=0;misses[k]<=0;seen[k]<=0;end
   end else case(state)
    IDLE:if(update)begin
     for(k=0;k<3;k=k+1)observations[k]<=boxes_in[k*35 +:35];
     used<=0;track<=0;obs<=0;found<=0;best_distance<=2047;state<=SEARCH;
    end
    SEARCH:begin
     if(a[34] && b[34] && !used[obs] && distance<=2*MATCH_DISTANCE && distance<best_distance)begin
      found<=1;best_distance<=distance;best_index<=obs;
     end
     if(obs==2)state<=APPLY;else obs<=obs+1'b1;
    end
    APPLY:begin
     if(tracks[track][34])begin
      if(found)begin
       tracks[track]<=filtered(tracks[track],observations[best_index]);
       misses[track]<=0;used[best_index]<=1;
       if(seen[track]<CONFIRM_FRAMES)seen[track]<=seen[track]+1'b1;
      end else if(seen[track]<CONFIRM_FRAMES || misses[track]>=HOLD_FRAMES)begin tracks[track]<=0;misses[track]<=0;seen[track]<=0;end
      else misses[track]<=misses[track]+1'b1;
     end
     obs<=0;found<=0;best_distance<=2047;
     if(track==2)begin track<=0;state<=ALLOCATE;end
     else begin track<=track+1'b1;state<=SEARCH;end
    end
    ALLOCATE:begin
     if(!tracks[track][34] && observations[obs][34] && !used[obs])begin
      tracks[track]<=observations[obs];misses[track]<=0;seen[track]<=1;used[obs]<=1;
     end
     if(obs==2)begin
      obs<=0;
      if(track==2)state<=PUBLISH;else track<=track+1'b1;
     end else obs<=obs+1'b1;
    end
    PUBLISH:begin
     for(k=0;k<3;k=k+1)boxes_out[k*35 +:35]<=(seen[k]>=CONFIRM_FRAMES) ? tracks[k] : 35'd0;
     update_out<=1;state<=IDLE;
    end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
