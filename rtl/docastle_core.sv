//============================================================================
// Mr. Do's Castle complete board-level core.
//============================================================================
module docastle_core
(
	input         clk,
	input         reset,
	input         pause,

	input         ioctl_download,
	input         ioctl_wr,
	input   [7:0] ioctl_index,
	input  [24:0] ioctl_addr,
	input   [7:0] ioctl_dout,

	input   [7:0] dsw1,
	input   [7:0] dsw2,
	input   [7:0] joys,
	input   [7:0] joys2,
	input   [7:0] buttons,
	input   [7:0] system,

	output        ce_pix,
	output  [7:0] r,
	output  [7:0] g,
	output  [7:0] b,
	output        hs,
	output        vs,
	output        hblank,
	output        vblank,
	output signed [15:0] audio,

	output [15:0] main_pc_debug,
	output [15:0] sub_pc_debug,
	output [15:0] sprite_pc_debug,
	output        main_wait_debug,
	output  [3:0] psg_ready_debug,
	output        renderer_busy_debug,
	output        renderer_overrun_debug,
	output  [7:0] game_id_debug,
	output  [1:0] profile_debug,
	output        profile_valid_debug,
	output        adpcm_busy_debug,
	output [17:0] adpcm_nibble_debug,
	output        adpcm_strobe_debug
);

reg [7:0] game_id = 8'h00;
reg game_id_loaded = 1'b0;
always @(posedge clk) begin
	if (ioctl_download && (ioctl_index == 8'd0))
		game_id_loaded <= 1'b0;
	if (ioctl_download && ioctl_wr && (ioctl_index == 8'd1) && (ioctl_addr == 0)) begin
		game_id <= ioctl_dout;
		game_id_loaded <= 1'b1;
	end
end

wire profile_valid;
wire [1:0] profile;
wire low_pen_priority;
wire soccer_sprites;
wire has_adpcm;
wire has_joys2;
wire native_vertical;
docastle_profile profile_decode
(
	.game_id(game_id),
	.valid(profile_valid),
	.profile(profile),
	.low_pen_priority(low_pen_priority),
	.soccer_sprites(soccer_sprites),
	.has_adpcm(has_adpcm),
	.has_joys2(has_joys2),
	.native_vertical(native_vertical)
);

wire machine_reset = reset | !profile_valid | !game_id_loaded;
assign game_id_debug = game_id;
assign profile_debug = profile;
assign profile_valid_debug = profile_valid & game_id_loaded;

// The inherited PLL provides 49.152 MHz. Rational enables reproduce both
// independent PCB clocks exactly on average:
//   pixel: 49.152 MHz * 819 / 8192 = 4.914 MHz
//   CPU/PSG: 49.152 MHz * 125 / 1536 = 4.000 MHz
reg [12:0] pix_phase;
reg ce_pix_r;
reg [10:0] cpu_phase;
reg ce_cpu;
assign ce_pix = ce_pix_r;

always @(posedge clk) begin
	if (machine_reset) begin
		pix_phase <= 0;
		ce_pix_r <= 0;
		cpu_phase <= 0;
		ce_cpu <= 0;
	end else begin
		ce_pix_r <= 0;
		if (pix_phase >= 13'd7373) begin
			pix_phase <= pix_phase - 13'd7373;
			ce_pix_r <= 1;
		end else pix_phase <= pix_phase + 13'd819;

		ce_cpu <= 0;
		if (cpu_phase >= 11'd1411) begin
			cpu_phase <= cpu_phase + 11'd125 - 11'd1536;
			ce_cpu <= 1;
		end else cpu_phase <= cpu_phase + 11'd125;
	end
end

// ROM ports.
wire [15:0] main_rom_addr;
wire [13:0] sub_rom_addr;
wire  [8:0] sprite_rom_addr;
wire [13:0] char_addr;
wire [16:0] sprite_gfx_addr;
wire [15:0] adpcm_rom_addr;
wire  [7:0] prom_addr;
wire [7:0] main_rom_q, sub_rom_q, sprite_rom_q, char_q, sprite_gfx_q;
wire [7:0] adpcm_rom_q, prom_q;

docastle_rom roms
(
	.*,
	.main_addr(main_rom_addr), .main_q(main_rom_q),
	.sub_addr(sub_rom_addr), .sub_q(sub_rom_q),
	.sprite_cpu_addr(sprite_rom_addr), .sprite_cpu_q(sprite_rom_q),
	.char_addr(char_addr), .char_q(char_q),
	.sprite_gfx_addr(sprite_gfx_addr), .sprite_gfx_q(sprite_gfx_q),
	.adpcm_addr(adpcm_rom_addr), .adpcm_q(adpcm_rom_q),
	.prom_addr({1'b0,prom_addr}), .prom_q(prom_q)
);

// Single bidirectional latch and main-CPU WAIT handshake.
reg [7:0] comm_latch;
reg main_wait;
wire [7:0] main_comm_dout, sub_comm_dout;
wire main_comm_start, main_comm_write;
wire sub_comm_access, sub_comm_write;
assign main_wait_debug = main_wait;

always @(posedge clk) begin
	if (machine_reset) begin
		comm_latch <= 0;
		main_wait <= 0;
	end else begin
		if (main_comm_write) comm_latch <= main_comm_dout;
		if (sub_comm_write)  comm_latch <= sub_comm_dout;
		if (main_comm_start) main_wait <= 1;
		if (sub_comm_access) main_wait <= 0;
	end
end

// Shared video RAM wiring.
wire [8:0] spr_addr;
wire [7:0] spr_din;
wire spr_we;
wire [9:0] video_addr, color_addr;
wire [7:0] video_din, color_din, video_q, color_q;
wire video_we, color_we;
wire [4:0] crtc_reg;
wire [7:0] crtc_data;
wire crtc_we;
wire sub_nmi_req;
wire flipscreen;
wire main_m1_n, main_iorq_n, sub_m1_n, sub_iorq_n;

wire main_irq_n;
wire sub_irq_req;
wire sprite_nmi_req;
reg sub_irq_n;
wire sub_iack = ~sub_m1_n & ~sub_iorq_n;
wire [7:0] adpcm_status;
wire adpcm_wr;
wire [7:0] adpcm_data;
wire signed [11:0] adpcm_sound;
wire signed [15:0] psg_audio;

always @(posedge clk) begin
	if (machine_reset) sub_irq_n <= 1;
	else begin
		if (sub_iack) sub_irq_n <= 1;
		if (sub_irq_req) sub_irq_n <= 0;
	end
end

docastle_main main_cpu
(
	.clk(clk), .reset(machine_reset), .ce_cpu(ce_cpu), .pause(pause), .profile(profile),
	.irq_n(main_irq_n), .rom_q(main_rom_q), .rom_addr(main_rom_addr),
	.comm_latch(comm_latch), .comm_dout(main_comm_dout),
	.comm_start(main_comm_start), .comm_write(main_comm_write),
	.comm_wait_n(~main_wait),
	.sprite_addr(spr_addr), .sprite_din(spr_din), .sprite_we(spr_we),
	.video_addr(video_addr), .video_din(video_din), .video_dout(video_q), .video_we(video_we),
	.color_addr(color_addr), .color_din(color_din), .color_dout(color_q), .color_we(color_we),
	.adpcm_status(adpcm_status), .adpcm_wr(adpcm_wr), .adpcm_data(adpcm_data),
	.crtc_reg(crtc_reg), .crtc_data(crtc_data), .crtc_we(crtc_we),
	.sub_nmi_req(sub_nmi_req),
	.cpu_addr_debug(main_pc_debug), .m1_n_debug(main_m1_n), .iorq_n_debug(main_iorq_n)
);

docastle_sub sub_cpu
(
	.clk(clk), .reset(machine_reset), .ce_cpu(ce_cpu), .ce_psg(ce_cpu), .pause(pause),
	.profile(profile),
	.irq_n(sub_irq_n), .nmi_req(sub_nmi_req),
	.rom_q(sub_rom_q), .rom_addr(sub_rom_addr),
	.comm_latch(comm_latch), .comm_dout(sub_comm_dout),
	.comm_access(sub_comm_access), .comm_write(sub_comm_write),
	.dsw1(dsw1), .dsw2(dsw2), .joys(joys), .joys2(joys2),
	.buttons(buttons), .system(system),
	.flipscreen(flipscreen), .audio(psg_audio),
	.cpu_addr_debug(sub_pc_debug), .m1_n_debug(sub_m1_n), .iorq_n_debug(sub_iorq_n),
	.psg_ready_debug(psg_ready_debug)
);

docastle_spritecpu sprite_cpu
(
	.clk(clk), .reset(machine_reset), .ce_cpu(ce_cpu), .pause(pause),
	.nmi_req(sprite_nmi_req), .rom_q(sprite_rom_q), .rom_addr(sprite_rom_addr),
	.cpu_addr_debug(sprite_pc_debug)
);

wire [8:0] h_count_unused, v_count_unused;
docastle_video video
(
	.clk(clk), .reset(machine_reset), .ce_pix(ce_pix_r), .flipscreen(flipscreen),
	.low_pen_priority(low_pen_priority), .soccer_sprites(soccer_sprites),
	.video_cpu_addr(video_addr), .video_cpu_din(video_din), .video_cpu_we(video_we), .video_cpu_q(video_q),
	.color_cpu_addr(color_addr), .color_cpu_din(color_din), .color_cpu_we(color_we), .color_cpu_q(color_q),
	.sprite_cpu_addr(spr_addr), .sprite_cpu_din(spr_din), .sprite_cpu_we(spr_we),
	.char_addr(char_addr), .char_q(char_q),
	.sprite_gfx_addr(sprite_gfx_addr), .sprite_gfx_q(sprite_gfx_q),
	.prom_addr(prom_addr), .prom_q(prom_q),
	.crtc_reg(crtc_reg), .crtc_data(crtc_data), .crtc_we(crtc_we),
	.r(r), .g(g), .b(b), .hs(hs), .vs(vs), .hblank(hblank), .vblank(vblank),
	.main_irq_n(main_irq_n), .sub_irq_req(sub_irq_req), .sprite_nmi_req(sprite_nmi_req),
	.h_count_debug(h_count_unused), .v_count_debug(v_count_unused),
	.renderer_busy_debug(renderer_busy_debug),
	.renderer_overrun_debug(renderer_overrun_debug)
);

docastle_adpcm adpcm
(
	.clk(clk), .reset(machine_reset), .pause(pause), .enabled(has_adpcm),
	.control_wr(adpcm_wr), .control_data(adpcm_data), .status(adpcm_status),
	.rom_addr(adpcm_rom_addr), .rom_q(adpcm_rom_q), .sound(adpcm_sound),
	.busy_debug(adpcm_busy_debug), .nibble_pos_debug(adpcm_nibble_debug),
	.nibble_strobe_debug(adpcm_strobe_debug)
);

wire signed [17:0] psg_mix = {{2{psg_audio[15]}},psg_audio};
// MAME's MSM5205 stream is signal/4096, masks the low two bits for the
// physical 10-bit DAC, then routes the device at 0.40. In signed 16-bit
// output units that is a gain of 3.20. 13/4 = 3.25 is the nearest compact
// fixed-point gain and differs by only +0.135 dB.
wire signed [11:0] adpcm_dac = {adpcm_sound[11:2],2'b00};
wire signed [17:0] adpcm_scaled = $signed(adpcm_dac) * 18'sd13;
wire signed [17:0] adpcm_mix = adpcm_scaled >>> 2;
wire signed [18:0] full_mix = {psg_mix[17],psg_mix} + {adpcm_mix[17],adpcm_mix};
reg signed [15:0] mixed_audio;
always @(*) begin
	if (full_mix > 19'sd32767)
		mixed_audio = 16'sh7fff;
	else if (full_mix < -19'sd32768)
		mixed_audio = -16'sd32768;
	else
		mixed_audio = full_mix[15:0];
end
assign audio = (machine_reset || pause) ? 16'sd0 : mixed_audio;

wire _unused = main_m1_n | main_iorq_n | has_joys2 | native_vertical;
endmodule
