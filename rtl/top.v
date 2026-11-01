`timescale 1ns/1ps
module top #(
    parameter WARMUP_FRAMES=90, parameter LEARN_FRAMES=8,
    parameter THRESHOLD=30,
    parameter TILE_MIN_HITS=8, MIN_PIXELS=48, MIN_WIDTH=12, MIN_HEIGHT=10,
    parameter RECOGNITION_BYPASS=0, SHOW_TEXT=1, YELLOW_FOREGROUND=1, DRAW_MARGIN=1,
    parameter FOREGROUND_RUN_FILTER=1,
    parameter TEST_BARS=0, STABILIZE_BOXES=1, BOX_HOLD_FRAMES=2, BOX_DEADBAND=2,
    parameter POR_CYCLES=65535,
    parameter SCCB_QUARTER_CYCLES=125, parameter SCCB_WAIT_CYCLES=500000
)(input CLOCK_50, input [1:0] KEY,
  input [7:0] CAM_D, input CAM_PCLK, CAM_HREF, CAM_VSYNC,
  output CAM_XCLK, CAM_SCL, inout CAM_SDA, output CAM_RESET, CAM_PWDN,
  output VGA_CLK, VGA_BLANK_N, VGA_SYNC_N, VGA_HS, VGA_VS,
  output [7:0] VGA_R,VGA_G,VGA_B);
    // Quartus supports power-up initialization of Cyclone IV registers.
    // Initial blocks here initialize registers only, never RAM contents.
    reg [31:0] por_count;
    reg clk25;
    initial begin por_count=0; clk25=0; end
    always @(posedge CLOCK_50) begin
        clk25<=!clk25; // Free-running: no gated clock and no PLL.
        if (por_count<POR_CYCLES) por_count<=por_count+1'b1;
    end
    wire arst=(por_count<POR_CYCLES)||!KEY[0];
    wire sys_rst;
    reset_sync rs(.clk(CLOCK_50),.arst(arst),.rst(sys_rst));
    assign CAM_XCLK=clk25; assign VGA_CLK=clk25;
    assign CAM_RESET=1'b1; assign CAM_PWDN=1'b0;
    wire cfg_done, nack_seen;
    sccb_config #(.QUARTER_CYCLES(SCCB_QUARTER_CYCLES),
        .WAIT_CYCLES(SCCB_WAIT_CYCLES)) cfg(
        .clk(CLOCK_50),.rst(sys_rst),.scl(CAM_SCL),.sda(CAM_SDA),
        .done(cfg_done),.nack_seen(nack_seen));
    wire image_arst=sys_rst || !cfg_done;
    wire cam_rst, mailbox_rst;
    reset_sync rc(.clk(CAM_PCLK),.arst(image_arst),.rst(cam_rst));
    reset_sync rm(.clk(CLOCK_50),.arst(image_arst),.rst(mailbox_rst));
    wire relearn;
    sync_bit rk(.clk(CAM_PCLK),.rst(cam_rst),.din(!KEY[1]),.dout(relearn));
    wire frame_start,pixel_valid;
    wire [15:0] pixel;
    wire [8:0] x;
    wire [7:0] y;
    wire [16:0] address;
    camera_capture capture(.pclk(CAM_PCLK),.rst(cam_rst),.vsync(CAM_VSYNC),
        .href(CAM_HREF),.data(CAM_D),.frame_start(frame_start),
        .pixel_valid(pixel_valid),.pixel(pixel),.x(x),.y(y),.address(address));
    wire box_update,background_ready,frame_ready,bad_frame,processing;
    wire [104:0] recognized_boxes;
    wire [5:0] class_ids;
    wire [29:0] best_costs;
    vehicle_engine #(.WARMUP_FRAMES(WARMUP_FRAMES),.LEARN_FRAMES(LEARN_FRAMES),
        .THRESHOLD(THRESHOLD),.FOREGROUND_RUN_FILTER(FOREGROUND_RUN_FILTER),.TILE_MIN_HITS(TILE_MIN_HITS),.MIN_PIXELS(MIN_PIXELS),
        .MIN_WIDTH(MIN_WIDTH),.MIN_HEIGHT(MIN_HEIGHT),.RECOGNITION_BYPASS(RECOGNITION_BYPASS),.YELLOW_FOREGROUND(YELLOW_FOREGROUND),.DRAW_MARGIN(DRAW_MARGIN)) detect(
        .clk(CAM_PCLK),.rst(cam_rst),.frame_start(frame_start),.relearn(relearn),
        .pixel_valid(pixel_valid),.pixel(pixel),.x(x),.y(y),.address(address),
        .box_update(box_update),.boxes(recognized_boxes),
        .background_ready(background_ready),.frame_ready(frame_ready),
        .bad_frame(bad_frame),.processing(processing),.class_ids(class_ids),.best_costs(best_costs));
    wire [104:0] stable_boxes;
    wire stable_update;
    box_stabilizer #(.HOLD_FRAMES(BOX_HOLD_FRAMES),.DEADBAND(BOX_DEADBAND)) stabilizer(
        .clk(CAM_PCLK),.rst(cam_rst),.clear(relearn || !background_ready || bad_frame),
        .update(box_update),.boxes_in(recognized_boxes),
        .update_out(stable_update),.boxes_out(stable_boxes));
    wire [104:0] box_display;
    box_cdc #(.WIDTH(105)) mailbox(.src_clk(CAM_PCLK),.src_rst(cam_rst),.src_update(STABILIZE_BOXES ? stable_update : box_update),
        .src_data(STABILIZE_BOXES ? stable_boxes : recognized_boxes),.dst_clk(CLOCK_50),
        .dst_rst(mailbox_rst),.dst_data(box_display));
    wire ready_display;
    sync_bit rf(.clk(CLOCK_50),.rst(mailbox_rst),.din(frame_ready),.dout(ready_display));
    wire [16:0] rd_addr;
    wire [15:0] rd_data;
    frame_ram frame(.wr_clk(CAM_PCLK),.wr_en(pixel_valid && !cam_rst),
        .wr_addr(address),.wr_data(pixel),.rd_clk(CLOCK_50),
        .rd_addr(rd_addr),.rd_data(rd_data));
    vga_display #(.TEST_BARS(TEST_BARS),.BOX_COUNT(3),.SHOW_TEXT(SHOW_TEXT),.OBJECT_MODE(RECOGNITION_BYPASS)) display(.clk(CLOCK_50),.rst(sys_rst),
        .clk25(clk25),.frame_ready(ready_display),.box_data(box_display),
        .ram_data(rd_data),.ram_address(rd_addr),.red(VGA_R),.green(VGA_G),
        .blue(VGA_B),.hs(VGA_HS),.vs(VGA_VS),.blank_n(VGA_BLANK_N),.sync_n(VGA_SYNC_N));
endmodule
