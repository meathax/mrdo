//============================================================================
// Universal Do! Castle hardware family — MiSTer wrapper
//============================================================================
module emu
(
	input         CLK_50M,
	input         RESET,
	inout  [45:0] HPS_BUS,
	output        CLK_VIDEO,
	output        CE_PIXEL,
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,
	output  [7:0] VGA_R, VGA_G, VGA_B,
	output        VGA_HS, VGA_VS, VGA_DE, VGA_F1,
	output  [1:0] VGA_SL,
	output        VGA_SCALER, VGA_DISABLE,
	input  [11:0] HDMI_WIDTH, HDMI_HEIGHT,
	output        HDMI_FREEZE, HDMI_BLACKOUT, HDMI_BOB_DEINT,
`ifdef MISTER_FB
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH, FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL, FB_LL,
	output        FB_FORCE_BLANK,
`ifdef MISTER_FB_PALETTE
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif
	output        LED_USER,
	output  [1:0] LED_POWER, LED_DISK, BUTTONS,
	input         CLK_AUDIO,
	output [15:0] AUDIO_L, AUDIO_R,
	output        AUDIO_S,
	output  [1:0] AUDIO_MIX,
	inout   [3:0] ADC_BUS,
	output        SD_SCK, SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,
	output        SDRAM_CLK, SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML, SDRAM_DQMH, SDRAM_nCS, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nWE,
`ifdef MISTER_DUAL_SDRAM
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS, SDRAM2_nCAS, SDRAM2_nRAS, SDRAM2_nWE,
`endif
	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD, UART_DTR,
	input         UART_DSR,
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,
	input         OSD_STATUS
);

assign {SD_SCK,SD_MOSI,SD_CS} = 'Z;
assign {UART_RTS,UART_TXD,UART_DTR} = 0;
assign {SDRAM_DQ,SDRAM_A,SDRAM_BA,SDRAM_CLK,SDRAM_CKE,
	SDRAM_DQML,SDRAM_DQMH,SDRAM_nWE,SDRAM_nCAS,SDRAM_nRAS,SDRAM_nCS} = 'Z;
assign ADC_BUS = 'Z;
assign USER_OUT = '1;
assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;
assign FB_FORCE_BLANK = 0;
assign LED_USER = ioctl_download;
assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;
assign AUDIO_MIX = 0;
assign AUDIO_S = 1;

`include "build_id.v"
localparam CONF_STR = {
	"A.UNIVERSAL_DOCASTLE;;",
	"H0O2,Orientation,Vert,Horz;",
	"O1,Rotate,CCW,CW;",
	"H0OMN,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"DIP;",
	"-;",
	"P1,Pause options;",
	"P1OP,Pause when OSD is open,On,Off;",
	"P1OQ,Dim video after 10s,On,Off;",
	"-;",
	"R0,Reset;",
	"J1,Button 1,Button 2,Start 1P,Start 2P,Coin,Service Mode,Pause,Right Left,Right Right,Right Up,Right Down,Service Credit;",
	"jn,A,B,Start,Select,R,L,X;",
	"V,v",`BUILD_DATE
};

wire clk_unused_98m, clk_sys, clk_unused_24m, pll_locked;
pll pll
(
	.refclk(CLK_50M), .rst(0),
	.outclk_0(clk_unused_98m), .outclk_1(clk_sys),
	.outclk_2(clk_unused_24m), .locked(pll_locked)
);

wire [127:0] status;
wire [1:0] hps_buttons;
wire forced_scandoubler, direct_video, video_rotated;
wire ioctl_download, ioctl_wr;
wire [15:0] ioctl_index;
wire [7:0] ioctl_dout;
wire [26:0] ioctl_addr;
wire [31:0] joystick_0, joystick_1;
wire [15:0] joystick_l_analog_0, joystick_l_analog_1;
wire [15:0] joystick_r_analog_0, joystick_r_analog_1;
wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys), .HPS_BUS(HPS_BUS), .buttons(hps_buttons), .status(status),
	.status_menumask({15'd0,direct_video}), .forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus), .direct_video(direct_video), .video_rotated(video_rotated),
	.ioctl_download(ioctl_download), .ioctl_wr(ioctl_wr), .ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout), .ioctl_index(ioctl_index),
	.joystick_0(joystick_0), .joystick_1(joystick_1),
	.joystick_l_analog_0(joystick_l_analog_0),
	.joystick_l_analog_1(joystick_l_analog_1),
	.joystick_r_analog_0(joystick_r_analog_0),
	.joystick_r_analog_1(joystick_r_analog_1)
);

reg [7:0] sw[0:7];
integer si;
always @(posedge clk_sys) begin
	if (RESET) begin
		for (si=0;si<8;si=si+1) sw[si] <= 8'hff;
		sw[0] <= 8'hdf;
	end
	else if (ioctl_wr && (ioctl_index == 16'd254) && (ioctl_addr[26:3] == 0))
		sw[ioctl_addr[2:0]] <= ioctl_dout;
end

wire p1_right=joystick_0[0], p1_left=joystick_0[1];
wire p1_down=joystick_0[2], p1_up=joystick_0[3];
wire p1_b1=joystick_0[4], p1_b2=joystick_0[5];
wire p2_right=joystick_1[0], p2_left=joystick_1[1];
wire p2_down=joystick_1[2], p2_up=joystick_1[3];
wire p2_b1=joystick_1[4], p2_b2=joystick_1[5];
wire start1=joystick_0[6]|joystick_1[6];
wire start2=joystick_0[7]|joystick_1[7];
wire coin=joystick_0[8]|joystick_1[8];
wire service_mode=joystick_0[9]|joystick_1[9];
wire user_pause=joystick_0[10]|joystick_1[10];
wire service_credit=joystick_0[15]|joystick_1[15];
wire [7:0] standard_joys = ~{p2_down,p2_left,p2_up,p2_right,p1_down,p1_left,p1_up,p1_right};
wire [7:0] game_buttons = ~{start2,1'b0,p2_b2,p2_b1,start1,1'b0,p1_b2,p1_b1};
wire [7:0] game_system = ~{2'b00,coin,1'b0,1'b0,service_credit,service_mode,1'b0};

wire core_reset = RESET | status[0] | hps_buttons[1] | ~pll_locked
	| (ioctl_download && ((ioctl_index == 16'd0) || (ioctl_index == 16'd1)));

wire p1_la_right, p1_la_left, p1_la_down, p1_la_up;
wire p2_la_right, p2_la_left, p2_la_down, p2_la_up;
wire p1_ra_right, p1_ra_left, p1_ra_down, p1_ra_up;
wire p2_ra_right, p2_ra_left, p2_ra_down, p2_ra_up;
docastle_analog p1_left_analog
(
	.clk(clk_sys), .reset(core_reset), .analog(joystick_l_analog_0),
	.right(p1_la_right), .left(p1_la_left), .down(p1_la_down), .up(p1_la_up)
);
docastle_analog p2_left_analog
(
	.clk(clk_sys), .reset(core_reset), .analog(joystick_l_analog_1),
	.right(p2_la_right), .left(p2_la_left), .down(p2_la_down), .up(p2_la_up)
);
docastle_analog p1_right_analog
(
	.clk(clk_sys), .reset(core_reset), .analog(joystick_r_analog_0),
	.right(p1_ra_right), .left(p1_ra_left), .down(p1_ra_down), .up(p1_ra_up)
);
docastle_analog p2_right_analog
(
	.clk(clk_sys), .reset(core_reset), .analog(joystick_r_analog_1),
	.right(p2_ra_right), .left(p2_ra_left), .down(p2_ra_down), .up(p2_ra_up)
);

wire [7:0] game_id_wire;
wire soccer_mode = (game_id_wire == 8'h07) || (game_id_wire == 8'h08);
wire [7:0] soccer_left_joys = ~{
	p2_down|p2_la_down,p2_left|p2_la_left,p2_up|p2_la_up,p2_right|p2_la_right,
	p1_down|p1_la_down,p1_left|p1_la_left,p1_up|p1_la_up,p1_right|p1_la_right
};
wire [7:0] soccer_right_joys = ~{
	joystick_1[14]|p2_ra_down,joystick_1[11]|p2_ra_left,
	joystick_1[13]|p2_ra_up,joystick_1[12]|p2_ra_right,
	joystick_0[14]|p1_ra_down,joystick_0[11]|p1_ra_left,
	joystick_0[13]|p1_ra_up,joystick_0[12]|p1_ra_right
};
wire [7:0] joys_to_core = soccer_mode ? soccer_right_joys : standard_joys;
wire [7:0] joys2_to_core = soccer_mode ? soccer_left_joys : 8'hff;

wire ce_pix, hblank, vblank, hs, vs;
wire [7:0] r,g,b;
wire signed [15:0] core_audio;
wire pause_cpu;
wire [23:0] rgb_out;
pause #(8,8,8,49) pause
(
	.*,
	.reset(core_reset),
	.r(r), .g(g), .b(b), .user_button(user_pause), .pause_request(1'b0),
	.options(~status[26:25])
);

docastle_core core
(
	.clk(clk_sys), .reset(core_reset), .pause(pause_cpu),
	.ioctl_download(ioctl_download), .ioctl_wr(ioctl_wr), .ioctl_index(ioctl_index[7:0]),
	.ioctl_addr(ioctl_addr[24:0]), .ioctl_dout(ioctl_dout),
	.dsw1(sw[0]), .dsw2(sw[1]), .joys(joys_to_core), .joys2(joys2_to_core),
	.buttons(game_buttons), .system(game_system),
	.ce_pix(ce_pix), .r(r), .g(g), .b(b), .hs(hs), .vs(vs),
	.hblank(hblank), .vblank(vblank), .audio(core_audio),
	.main_pc_debug(), .sub_pc_debug(), .sprite_pc_debug(),
	.main_wait_debug(), .psg_ready_debug(), .renderer_busy_debug(),
	.renderer_overrun_debug(), .game_id_debug(game_id_wire),
	.profile_debug(), .profile_valid_debug(), .adpcm_busy_debug(),
	.adpcm_nibble_debug(), .adpcm_strobe_debug()
);
assign AUDIO_L = core_audio;
assign AUDIO_R = core_audio;

wire orientation = status[2];
wire [1:0] ar = status[24:23];
assign VIDEO_ARX = (ar == 0) ? (orientation ? 13'd4 : 13'd3)
	: ({11'd0,ar} - 13'd1);
assign VIDEO_ARY = (ar == 0) ? (orientation ? 13'd3 : 13'd4) : 13'd0;
wire no_rotate = orientation | direct_video;
wire rotate_ccw = ~status[1];
wire flip = 1'b0;
screen_rotate screen_rotate (.*);

arcade_video #(240,24) arcade_video
(
	.*,
	.clk_video(clk_sys), .ce_pix(ce_pix), .RGB_in(rgb_out),
	.HBlank(hblank), .VBlank(vblank), .HSync(hs), .VSync(vs), .fx(status[5:3])
);

wire _unused = &{1'b0,CLK_AUDIO,HDMI_WIDTH,HDMI_HEIGHT,SD_MISO,SD_CD,
	DDRAM_BUSY,DDRAM_DOUT,DDRAM_DOUT_READY,UART_CTS,UART_RXD,UART_DSR,USER_IN,OSD_STATUS,
	clk_unused_98m,clk_unused_24m};
endmodule
