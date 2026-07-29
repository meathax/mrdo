// Minimal black-box interfaces used only to lint Universal_DoCastle.sv with
// the lint tool. The real MiSTer framework and Intel PLL remain the synthesis
// implementations selected by Universal_DoCastle.qsf.

module pll(
	input refclk, input rst,
	output outclk_0, output outclk_1, output outclk_2, output locked
);
	assign outclk_0 = refclk;
	assign outclk_1 = refclk;
	assign outclk_2 = refclk;
	assign locked = ~rst;
endmodule

module hps_io #(parameter CONF_STR = "") (
	input clk_sys, inout [45:0] HPS_BUS,
	output [1:0] buttons, output [127:0] status,
	input [15:0] status_menumask,
	output forced_scandoubler, output [21:0] gamma_bus,
	output direct_video, input video_rotated,
	output ioctl_download, output ioctl_wr,
	output [26:0] ioctl_addr, output [7:0] ioctl_dout,
	output [15:0] ioctl_index,
	output [31:0] joystick_0, output [31:0] joystick_1,
	output [15:0] joystick_l_analog_0, output [15:0] joystick_l_analog_1,
	output [15:0] joystick_r_analog_0, output [15:0] joystick_r_analog_1
);
	assign buttons = 0;
	assign status = 0;
	assign forced_scandoubler = 0;
	assign gamma_bus = 0;
	assign direct_video = 0;
	assign ioctl_download = 0;
	assign ioctl_wr = 0;
	assign ioctl_addr = 0;
	assign ioctl_dout = 0;
	assign ioctl_index = 0;
	assign joystick_0 = 0;
	assign joystick_1 = 0;
	assign joystick_l_analog_0 = 0;
	assign joystick_l_analog_1 = 0;
	assign joystick_r_analog_0 = 0;
	assign joystick_r_analog_1 = 0;
	assign HPS_BUS = 'z;
endmodule

module screen_rotate(
	input CLK_VIDEO, input CE_PIXEL,
	input [7:0] VGA_R, input [7:0] VGA_G, input [7:0] VGA_B,
	input VGA_HS, input VGA_VS, input VGA_DE,
	input rotate_ccw, input no_rotate, input flip,
	output video_rotated,
	output FB_EN, output [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH, output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE, output [13:0] FB_STRIDE,
	input FB_VBL, input FB_LL,
	output DDRAM_CLK, input DDRAM_BUSY,
	output [7:0] DDRAM_BURSTCNT, output [28:0] DDRAM_ADDR,
	output [63:0] DDRAM_DIN, output [7:0] DDRAM_BE,
	output DDRAM_WE, output DDRAM_RD
);
	assign video_rotated = ~no_rotate;
	assign FB_EN = 0;
	assign FB_FORMAT = 0;
	assign FB_WIDTH = 0;
	assign FB_HEIGHT = 0;
	assign FB_BASE = 0;
	assign FB_STRIDE = 0;
	assign DDRAM_CLK = CLK_VIDEO;
	assign DDRAM_BURSTCNT = 0;
	assign DDRAM_ADDR = 0;
	assign DDRAM_DIN = 0;
	assign DDRAM_BE = 0;
	assign DDRAM_WE = 0;
	assign DDRAM_RD = 0;
endmodule

module arcade_video #(parameter WIDTH=240, DW=24) (
	input clk_video, input ce_pix, input [DW-1:0] RGB_in,
	input HBlank, input VBlank, input HSync, input VSync,
	output CLK_VIDEO, output CE_PIXEL,
	output [7:0] VGA_R, output [7:0] VGA_G, output [7:0] VGA_B,
	output VGA_HS, output VGA_VS, output VGA_DE, output [1:0] VGA_SL,
	input [2:0] fx, input forced_scandoubler, inout [21:0] gamma_bus
);
	assign CLK_VIDEO = clk_video;
	assign CE_PIXEL = ce_pix;
	assign VGA_R = RGB_in[23:16];
	assign VGA_G = RGB_in[15:8];
	assign VGA_B = RGB_in[7:0];
	assign VGA_HS = HSync;
	assign VGA_VS = VSync;
	assign VGA_DE = ~(HBlank | VBlank);
	assign VGA_SL = 0;
endmodule
