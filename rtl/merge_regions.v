`timescale 1ns/1ps
// Join up to three nearby yellow fragments. Camera pixels, not VGA pixels.
// Close separate objects can also merge: keep a clear gap between vehicles.
module merge_regions #(parameter GAP=16)(input [104:0] boxes,output reg [104:0] merged);
reg [34:0] b[0:2];
integer pass,i,j;
reg xov,yov,nearby;
always @* begin
 for(i=0;i<3;i=i+1)b[i]=boxes[i*35 +: 35];
 xov=0;yov=0;nearby=0;
 for(pass=0;pass<2;pass=pass+1)begin
  for(i=0;i<3;i=i+1)begin
   for(j=i+1;j<3;j=j+1)begin
    xov=(b[i][33:25]<=b[j][24:16] && b[j][33:25]<=b[i][24:16]);
    yov=(b[i][15:8]<=b[j][7:0] && b[j][15:8]<=b[i][7:0]);
    nearby=(xov && ({1'b0,b[i][15:8]}<={1'b0,b[j][7:0]}+GAP+1) &&
                    ({1'b0,b[j][15:8]}<={1'b0,b[i][7:0]}+GAP+1)) ||
           (yov && ({1'b0,b[i][33:25]}<={1'b0,b[j][24:16]}+GAP+1) &&
                    ({1'b0,b[j][33:25]}<={1'b0,b[i][24:16]}+GAP+1));
    if(b[i][34] && b[j][34] && nearby)begin
     if(b[j][33:25]<b[i][33:25])b[i][33:25]=b[j][33:25];
     if(b[j][24:16]>b[i][24:16])b[i][24:16]=b[j][24:16];
     if(b[j][15:8]<b[i][15:8])b[i][15:8]=b[j][15:8];
     if(b[j][7:0]>b[i][7:0])b[i][7:0]=b[j][7:0];
     b[j]=0;
    end
   end
  end
 end
 merged={b[2],b[1],b[0]};
end
endmodule
