`timescale 1ns/1ps
// Flood fill over 40x30 occupied tiles. Four-neighbor connectivity.
// Every tile is cleared when queued; therefore the FIFO never exceeds 1200.
// Keep the three largest qualifying components. No persistent object tracking.
module component_boxes #(
    parameter TILE_MIN_HITS=4, MIN_PIXELS=48, MIN_WIDTH=12, MIN_HEIGHT=10
)(input clk,rst,start,enable,
    output reg busy,done, output reg [104:0] boxes,
    output reg [10:0] rd_addr,input [18:0] rd_data,
    output reg wr_en,output reg [10:0] wr_addr,output reg [18:0] wr_data);
    localparam IDLE=0,SCAN=1,SCAN_EVAL=2,POP=3,POP_EVAL=4,
        NEIGHBOR=5,NEIGHBOR_EVAL=6,FINISH=7,CLEAR=8;
    reg [3:0] state;
    reg [10:0] cursor,clear_index;
    reg [5:0] scan_x,tx;
    reg [4:0] scan_y,ty;
    reg [1:0] direction;
    reg [10:0] head,tail;
    // Queue holds {tile_y,tile_x,tile_address}; one inferred synchronous RAM.
    (* ramstyle="M9K" *) reg [21:0] queue[0:1199];
    reg [21:0] queue_q;
    reg queue_we;
    reg [21:0] queue_in;
    reg [10:0] queue_write_addr;
    reg [5:0] nx;
    reg [4:0] ny;
    reg neighbor_ok;
    reg [8:0] left,right;
    reg [7:0] top_y,bottom;
    reg [16:0] area,size0,size1,size2;
    wire [34:0] completed_box={1'b1,left,right,top_y,bottom};
    wire [8:0] tile_left={nx,3'b0}+rd_data[2:0];
    wire [8:0] tile_right={nx,3'b0}+rd_data[5:3];
    wire [7:0] tile_top={ny,3'b0}+rd_data[8:6];
    wire [7:0] tile_bottom={ny,3'b0}+rd_data[11:9];
    wire occupied=(rd_data[18:12]>=TILE_MIN_HITS);
    always @* begin
        nx=tx;ny=ty;neighbor_ok=1;
        case(direction)
            0:begin nx=tx-1'b1;if(tx==0)neighbor_ok=0;end
            1:begin nx=tx+1'b1;if(tx==39)neighbor_ok=0;end
            2:begin ny=ty-1'b1;if(ty==0)neighbor_ok=0;end
            3:begin ny=ty+1'b1;if(ty==29)neighbor_ok=0;end
        endcase
        if(state==SCAN || state==SCAN_EVAL) begin nx=scan_x;ny=scan_y;end
        rd_addr=cursor;
        if(state==NEIGHBOR || state==NEIGHBOR_EVAL)
            rd_addr=neighbor_ok ? ({6'b0,ny}<<5)+({6'b0,ny}<<3)+nx : 11'd0;
        wr_en=0;wr_addr=rd_addr;wr_data=0;
        queue_we=0;queue_in={ny,nx,rd_addr};queue_write_addr=tail;
        if((state==SCAN_EVAL || state==NEIGHBOR_EVAL) && occupied) begin
            wr_en=1;queue_we=1;
            if(state==SCAN_EVAL) queue_write_addr=0;
        end
        if(state==CLEAR) begin wr_en=1;wr_addr=clear_index;end
    end
    always @(posedge clk) begin
        // Guard the empty FIFO pointer, which may equal 1200.
        queue_q<=queue[(head<1200) ? head : 11'd0];
        if(queue_we && queue_write_addr<1200) queue[queue_write_addr]<=queue_in;
    end
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state<=IDLE;busy<=0;done<=0;boxes<=0;cursor<=0;
            clear_index<=0;scan_x<=0;scan_y<=0;tx<=0;ty<=0;
            direction<=0;head<=0;tail<=0;left<=0;right<=0;top_y<=0;bottom<=0;
            area<=0;size0<=0;size1<=0;size2<=0;
        end else begin
            done<=0;
            case(state)
            IDLE:if(start) begin
                busy<=1;boxes<=0;cursor<=0;scan_x<=0;scan_y<=0;
                size0<=0;size1<=0;size2<=0;clear_index<=0;
                if(enable)state<=SCAN;else state<=CLEAR;
            end
            SCAN:state<=SCAN_EVAL;
            SCAN_EVAL:begin
                if(occupied) begin
                    head<=0;tail<=1;area<=rd_data[18:12];
                    left<=tile_left;right<=tile_right;top_y<=tile_top;bottom<=tile_bottom;
                    state<=POP;
                end else if(cursor==1199) begin clear_index<=0;state<=CLEAR;end
                else begin
                    cursor<=cursor+1'b1;
                    if(scan_x==39)begin scan_x<=0;scan_y<=scan_y+1'b1;end
                    else scan_x<=scan_x+1'b1;
                    state<=SCAN;
                end
            end
            POP:if(head<tail)state<=POP_EVAL;else state<=FINISH;
            POP_EVAL:begin
                ty<=queue_q[21:17];tx<=queue_q[16:11];head<=head+1'b1;
                direction<=0;state<=NEIGHBOR;
            end
            NEIGHBOR:begin
                if(neighbor_ok)state<=NEIGHBOR_EVAL;
                else if(direction==3)state<=POP;
                else direction<=direction+1'b1;
            end
            NEIGHBOR_EVAL:begin
                if(occupied) begin
                    tail<=tail+1'b1;area<=area+rd_data[18:12];
                    if(tile_left<left)left<=tile_left;
                    if(tile_right>right)right<=tile_right;
                    if(tile_top<top_y)top_y<=tile_top;
                    if(tile_bottom>bottom)bottom<=tile_bottom;
                end
                if(direction==3)state<=POP;
                else begin direction<=direction+1'b1;state<=NEIGHBOR;end
            end
            FINISH:begin
                if(area>=MIN_PIXELS && right-left+1>=MIN_WIDTH && bottom-top_y+1>=MIN_HEIGHT) begin
                    if(area>size0) begin
                        size2<=size1;size1<=size0;size0<=area;
                        boxes<={boxes[69:0],completed_box};
                    end else if(area>size1) begin
                        size2<=size1;size1<=area;
                        boxes[104:35]<={boxes[69:35],completed_box};
                    end else if(area>size2) begin size2<=area;boxes[104:70]<=completed_box;end
                end
                // Revisit cleared seed, then resume raster search.
                state<=SCAN;
            end
            CLEAR:begin
                if(clear_index==1199)begin busy<=0;done<=1;state<=IDLE;end
                else clear_index<=clear_index+1'b1;
            end
            default:state<=IDLE;
            endcase
        end
    end
endmodule
