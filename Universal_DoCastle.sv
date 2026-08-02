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
	"O[102],PCB support,On,Off;",
	"O[103],PCB audio stage,On,Off;",
	"O[104],PCB-rate raster,On,Off;",
	"-;",
	"P2,CRT Adjust;",
	"P2O[101],Enable,Off,On;",
	"H1P2O[100:96],CRT H-Size,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
	"H1P2O[85:79],CRT H-Position,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,+16,+17,+18,+19,+20,+21,+22,+23,+24,+25,+26,+27,+28,+29,+30,+31,+32,+33,+34,+35,+36,+37,+38,+39,+40,+41,+42,+43,+44,+45,+46,+47,+48,-48,-47,-46,-45,-44,-43,-42,-41,-40,-39,-38,-37,-36,-35,-34,-33,-32,-31,-30,-29,-28,-27,-26,-25,-24,-23,-22,-21,-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
	"H1P2O[78:74],CRT V-Shift,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
	"-;",
	"DIP;",
	"-;",
	"P1,Pause options;",
	"P1OP,Pause when OSD is open,On,Off;",
	"P1OQ,Dim video after 10s,On,Off;",
	"-;",
	"R0,Reset;",
	"J1,Button 1,Button 2,Start 1P,Start 2P,Coin 1,Coin 2,Service Mode,Pause,Right Left,Right Right,Right Up,Right Down,Service Credit;",
	"jn,A,B,Start,Select,R,L,X,Y;",
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
	.status_menumask({14'd0,~status[101],direct_video}), .forced_scandoubler(forced_scandoubler),
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
wire coin1=joystick_0[8]|joystick_1[8];
wire coin2=joystick_0[9]|joystick_1[9];
wire service_mode=joystick_0[10]|joystick_1[10];
wire user_pause=joystick_0[11]|joystick_1[11];
wire service_credit=joystick_0[16]|joystick_1[16];
wire [7:0] standard_joys = ~{p2_down,p2_left,p2_up,p2_right,p1_down,p1_left,p1_up,p1_right};
wire [7:0] game_buttons = ~{start2,1'b0,p2_b2,p2_b1,start1,1'b0,p1_b2,p1_b1};
// MAME's input table and the PCB expose two active-low coin lines:
// SYSTEM[5] is COIN1 and SYSTEM[4] is COIN2.
wire [7:0] game_system = ~{2'b00,coin1,coin2,1'b0,service_credit,service_mode,1'b0};

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
wire pcb_fidelity = ~status[102];
wire pcb_audio_filter = ~status[103];
wire exact_pixel_clock = status[104];
wire soccer_mode = (game_id_wire == 8'h07) || (game_id_wire == 8'h08);
wire [7:0] soccer_left_joys = ~{
	p2_down|p2_la_down,p2_left|p2_la_left,p2_up|p2_la_up,p2_right|p2_la_right,
	p1_down|p1_la_down,p1_left|p1_la_left,p1_up|p1_la_up,p1_right|p1_la_right
};
wire [7:0] soccer_right_joys = ~{
	joystick_1[15]|p2_ra_down,joystick_1[12]|p2_ra_left,
	joystick_1[14]|p2_ra_up,joystick_1[13]|p2_ra_right,
	joystick_0[15]|p1_ra_down,joystick_0[12]|p1_ra_left,
	joystick_0[14]|p1_ra_up,joystick_0[13]|p1_ra_right
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
	.pcb_fidelity(pcb_fidelity), .pcb_audio_filter(pcb_audio_filter),
	.pcb_framebuffer(1'b0), .pcb_cursor_irq(1'b0), .exact_pixel_clock(exact_pixel_clock),
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
	.adpcm_nibble_debug(), .adpcm_strobe_debug(),
	.watchdog_reset_debug(), .sprite_copy_debug(), .cf_write_debug(),
	.crtc_cursor_debug(), .cf_irq_debug(), .cf_overrun_debug(),
	.cf_reg2_debug(), .cf_addr_debug(), .cf_data_debug(),
	.crtc_write_debug(), .crtc_reg_debug(), .crtc_data_debug()
);
assign AUDIO_L = core_audio;
assign AUDIO_R = core_audio;

wire orientation = status[2];
wire [1:0] ar = status[24:23];
wire [12:0] aspect_arx = (ar == 0) ? (orientation ? 13'd4 : 13'd3)
	: ({11'd0,ar} - 13'd1);
wire [12:0] aspect_ary = (ar == 0) ? (orientation ? 13'd3 : 13'd4) : 13'd0;
wire no_rotate = orientation | direct_video;
wire rotate_ccw = ~status[1];
wire flip = 1'b0;

// CRT Adjust (rmonic79/MiSTer-CRT-Adjust). The native raster is 312x264 with
// an asymmetric 240-pixel active window, so the upstream SYNCSHIFT mode is the
// appropriate horizontal-position implementation. The read period is measured
// in quarter master-clock cycles: 49.152 MHz / 4.9152 MHz = 10 clocks = 40
// quarters at the neutral setting.
wire crt_on = status[101];
wire signed [4:0] crt_hsize = $signed(status[100:96]);
wire [6:0] crt_hpos_raw = status[85:79];
wire signed [8:0] crt_hpos = (crt_hpos_raw <= 7'd48)
	? $signed({2'b00,crt_hpos_raw})
	: (crt_hpos_raw <= 7'd96)
		? ($signed({2'b00,crt_hpos_raw}) - 9'sd97) : 9'sd0;
wire signed [5:0] crt_vshift = $signed(status[78:74]);

wire crt_hs_ref;
reg crt_hs_ref_d;
always @(posedge clk_sys) crt_hs_ref_d <= crt_hs_ref;
wire crt_hs_ref_rise = crt_hs_ref & ~crt_hs_ref_d;

wire signed [8:0] crt_period_calc = 9'sd40 + crt_hsize;
wire [7:0] crt_rd_period = crt_period_calc[7:0];
reg [7:0] crt_rd_acc;
wire [8:0] crt_rd_sum = {1'b0,crt_rd_acc} + 9'd4;
wire crt_rd_tick = crt_rd_sum >= {1'b0,crt_rd_period};
always @(posedge clk_sys) begin
	if (!crt_on || crt_hs_ref_rise) crt_rd_acc <= 8'd0;
	else if (crt_rd_tick) crt_rd_acc <= crt_rd_sum - {1'b0,crt_rd_period};
	else crt_rd_acc <= crt_rd_sum[7:0];
end

wire [7:0] crt_r, crt_g, crt_b;
wire crt_hs, crt_vs, crt_hblank, crt_vblank;
crt_adjust #(
	.VTOTAL(264),
	.HTOTAL(312),
	.HPOS_MODE(`HPOS_SYNCSHIFT)
) crt_adjust
(
	.clk(clk_sys), .pxl_cen(ce_pix), .pxl2_cen(crt_rd_tick),
	.active(crt_on), .hsize(crt_hsize), .hoffset(crt_hpos),
	.voffset(crt_vshift),
	.r_in(rgb_out[23:16]), .g_in(rgb_out[15:8]), .b_in(rgb_out[7:0]),
	.hs_in(hs), .vs_in(vs), .hb_in(hblank | vblank), .vb_in(vblank),
	.r_out(crt_r), .g_out(crt_g), .b_out(crt_b),
	.hs_out(crt_hs), .vs_out(crt_vs),
	.hb_out(crt_hblank), .vb_out(crt_vblank),
	.hs_ref_out(crt_hs_ref)
);

wire video_ce = crt_on ? crt_rd_tick : ce_pix;
wire [23:0] video_rgb = crt_on ? {crt_r,crt_g,crt_b} : rgb_out;
wire video_hblank = crt_on ? crt_hblank : hblank;
wire video_vblank = crt_on ? crt_vblank : vblank;
wire video_hs = crt_on ? crt_hs : hs;
wire video_vs = crt_on ? crt_vs : vs;

screen_rotate screen_rotate (.*);

wire video_de;
arcade_video #(240,24) arcade_video
(
	.*,
	.clk_video(clk_sys), .ce_pix(video_ce), .RGB_in(video_rgb),
	.HBlank(video_hblank), .VBlank(video_vblank),
	.HSync(video_hs), .VSync(video_vs), .VGA_DE(video_de), .fx(3'd0)
);

assign VGA_DE = video_de;
assign VIDEO_ARX = aspect_arx;
assign VIDEO_ARY = aspect_ary;

wire _unused = &{1'b0,CLK_AUDIO,HDMI_WIDTH,HDMI_HEIGHT,SD_MISO,SD_CD,
	DDRAM_BUSY,DDRAM_DOUT,DDRAM_DOUT_READY,UART_CTS,UART_RXD,UART_DSR,USER_IN,OSD_STATUS,
	clk_unused_98m,clk_unused_24m};
endmodule
