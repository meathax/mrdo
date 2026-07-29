//============================================================================
// 8301 sprite/protection Z80.  MAME documents this CPU as a sprite-RAM
// doorway and currently models its external ports as no-ops while the main
// CPU writes sprite RAM directly.  The real ROM still runs here so its bus
// and interrupt timing are present rather than deleting the third CPU.
//============================================================================
module docastle_spritecpu
(
	input         clk,
	input         reset,
	input         ce_cpu,
	input         pause,
	input         nmi_req,
	input   [7:0] rom_q,
	output  [8:0] rom_addr,
	output [15:0] cpu_addr_debug
);

reg nmi_n;
wire [15:0] cpu_addr;
wire [7:0] cpu_dout;
reg  [7:0] cpu_din;
wire mreq_n, rd_n, wr_n, rfsh_n;

always @(posedge clk) begin
	if (reset) nmi_n <= 1;
	else begin
		if (nmi_req) nmi_n <= 0;
		else if (ce_cpu) nmi_n <= 1;
	end
end

T80se #(.Mode(0), .T2Write(1), .IOWait(1)) cpu
(
	.RESET_n(~reset), .CLK_n(clk), .CLKEN(ce_cpu & ~pause),
	.WAIT_n(1'b1), .INT_n(1'b1), .NMI_n(nmi_n), .BUSRQ_n(1'b1),
	.M1_n(), .MREQ_n(mreq_n), .IORQ_n(), .RD_n(rd_n), .WR_n(wr_n),
	.RFSH_n(rfsh_n), .HALT_n(), .BUSAK_n(), .A(cpu_addr),
	.DI(cpu_din), .DO(cpu_dout)
);

assign rom_addr = cpu_addr[8:0];
assign cpu_addr_debug = cpu_addr;

(* ramstyle = "M10K, no_rw_check" *) reg [7:0] work_ram [0:2047];
reg [7:0] work_q;
wire ram_cs = (cpu_addr >= 16'h4000) && (cpu_addr <= 16'h47ff);
wire wr = ~mreq_n & ~wr_n & rfsh_n & ram_cs & ce_cpu;

always @(posedge clk) begin
	work_q <= work_ram[cpu_addr[10:0]];
	if (wr) work_ram[cpu_addr[10:0]] <= cpu_dout;
end

always @(*) begin
	cpu_din = 8'hff;
	if (cpu_addr <= 16'h00ff) cpu_din = rom_q;
	else if (ram_cs) cpu_din = work_q;
	else if (cpu_addr == 16'h8000) cpu_din = 8'hff;
end

wire _unused = rd_n;
endmodule
