//============================================================================
//  Arcade: Moon Patrol
//
//  Port to MiSTer
//  Copyright (C) 2017 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

// Backported to MiST for DeMiSTified platforms by Alastair M. Robinson
// (MiST already has its own port, but currently uses embedded ROMs)

module MoonPatrol_MiST
(
	//Master input clock
	input         CLOCK_27,

	output  [5:0] VGA_R,
	output  [5:0] VGA_G,
	output  [5:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,

	output SPI_DO,
	input SPI_DI,
	input SPI_SCK,
	input SPI_SS2,
	input	SPI_SS3,
	input	SPI_SS4,
	input	CONF_DATA0,

	output AUDIO_L,
	output AUDIO_R,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE
);

///////// Default values for ports not used in this core /////////

assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;

`include "build_id.v" 
localparam CONF_STR = {
	"MPATROL;;",
	"O12,Scandoubler Fx,None,CRT 25%,CRT 50%,CRT 75%;",
	"OB,Video timings,Original,PAL;",
	"O34,Patrol cars,5,3,2,1;",
	"O56,New car at,10/30/50K,20/40/60K,10K,Never;",
	"OA,Freeze,Disable,Enable;",
	"O7,Demo mode,Off,On;",
	"O8,Sector selection,Off,On;",
	"O9,Test mode,Off,On;",
	"T0,Reset;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys, clk_vid, clk_snd;
wire pll_locked;

pll pll
(
	.inclk0(CLOCK_27),
	.c0(clk_sys), // 30
	.c1(clk_vid), // 48
	.c2(clk_snd), // 3.58
	.locked(pll_locked)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
reg         forced_scandoubler;
wire        sd;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire        ioctl_wr;
wire  [7:0] ioctl_index;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

wire [21:0] gamma_bus;

wire ypbpr;
wire nocsync;

// Replace with userio
// include user_io module for arm controller communication
user_io #(.STRLEN($size(CONF_STR)>>3)) user_io (
	.conf_str       ( CONF_STR       ),

	.clk_sys        ( clk_sys        ),

	.SPI_CLK        ( SPI_SCK        ),
	.SPI_SS_IO      ( CONF_DATA0     ),
	.SPI_MISO       ( SPI_DO         ),
	.SPI_MOSI       ( SPI_DI         ),

	.scandoubler_disable ( sd   ),
	.ypbpr          ( ypbpr ),
	.no_csync       ( nocsync ),
	.buttons        ( buttons        ),

	.joystick_0     ( joystick_0            ),
	.joystick_1     ( joystick_1            ),

	.status         ( status         )
);


data_io data_io (
	.clk_sys        ( clk_sys ),
	// SPI interface
	.SPI_SCK        ( SPI_SCK ),
	.SPI_SS2        ( SPI_SS2 ),
	.SPI_DI         ( SPI_DI  ),

	// ram interface
	.ioctl_download ( ioctl_download ),
	.ioctl_index    ( ioctl_index ),
	.ioctl_wr       ( ioctl_wr ),
	.ioctl_addr     ( ioctl_addr ),
	.ioctl_dout     ( ioctl_dout )
);

wire [15:0] switches_i;
wire [1:0] scanlines = status[2:1];
assign switches_i[15] = ~status[9]; // Test mode
assign switches_i[14] = ~status[7];
assign switches_i[13] = ~status[8]; // Sector select
assign switches_i[12] = ~status[10];// Freeze enable
assign switches_i[11:8] = 4'b1100;
assign switches_i[7:4] = 4'b1111;
assign switches_i[1:0] = ~status[4:3]; // Patrol cars
assign switches_i[3:2] = ~status[6:5]; // New car

wire m_up     = joy[3];
wire m_down   = joy[2];
wire m_left   = joy[1];
wire m_right  = joy[0];
wire m_fire   = joy[4];
wire m_jump   = joy[5];

wire m_up_2   = joy[3];
wire m_down_2 = joy[2];
wire m_left_2 = joy[1];
wire m_right_2= joy[0];
wire m_fire_2 = joy[4];
wire m_jump_2 = joy[5];

wire m_start1 = joystick_0[7]; // P1 start only available on 1st input device
wire m_start2 = joystick_1[7];
wire m_coin1  = joystick_0[6];
wire m_coin2  = joystick_1[6];

// PAUSE SYSTEM

wire hbl,vbl,hs,vs;
wire [3:0] r,g,b;

reg clk_6; // nasty! :)
always @(negedge clk_vid) begin
	reg [2:0] div;

	div <= div + 1'd1;
	clk_6 <= div[2];
end

reg ce_pix;
reg HSync,VSync;
reg [2:0] fx;
always @(posedge clk_vid) begin
	reg old_clk_v;
	old_clk_v <= clk_6;
	ce_pix <= (old_clk_v & ~clk_6);
	HSync <= ~hs;
	VSync <= ~vs;
	fx <= status[5:3];
	forced_scandoubler <= sd;
end


mist_video #(.COLOR_DEPTH(4)) videochain
(
	// master clock
	// it should be 4x (or 2x) pixel clock for the scandoubler
	.clk_sys(clk_vid),

	// OSD SPI interface
	.SPI_SCK(SPI_SCK),
	.SPI_SS3(SPI_SS3),
	.SPI_DI(SPI_DI),

	// scanlines (00-none 01-25% 10-50% 11-75%)
	.scanlines(scanlines),

	// non-scandoubled pixel clock divider:
	// 0 - clk_sys/4, 1 - clk_sys/2, 2 - clk_sys/3, 3 - clk_sys/4, etc
	.ce_divider(7),

	// 0 = HVSync 31KHz, 1 = CSync 15KHz
	.scandoubler_disable(sd),

	// disable csync without scandoubler
	.no_csync(nocsync),

	// YPbPr always uses composite sync
	.ypbpr(ypbpr),

	// Rotate OSD [0] - rotate [1] - left or right
	.rotate(1'b0),

	// composite-like blending
	.blend(1'b0),

	// video in
	.R(r),
	.G(g),
	.B(b),

	.HSync(HSync),
	.VSync(VSync),

	// MiST video output signals
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS)
);

wire [12:0] audio;
wire aud_sd;

dac #(.C_Bits(13)) (
	.clk_i(clk_sys),
	.res_n_i(1'b1),
	.dac_i({~audio[12],audio[11:0]}),
	.dac_o(aud_sd)
);

assign AUDIO_L=aud_sd;
assign AUDIO_R=aud_sd;

wire rom_download = ioctl_download & !ioctl_index;
wire reset = status[0] | ioctl_download | buttons[1];

wire palmode = status[11];

target_top moonpatrol
(
	.clock_30(clk_sys),
	.clock_v(clk_6),
	.clock_3p58(clk_snd),

	.switches_i(switches_i),
	
	.reset(reset),

	.dn_addr(ioctl_addr[15:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr & rom_download),

	.VGA_R(r),
	.VGA_G(g),
	.VGA_B(b),
	.VGA_HS(hs),
	.VGA_VS(vs),
	.VGA_HBLANK(hbl),
	.VGA_VBLANK(vbl),

	.palmode(palmode),
	.hs_offset(0),
	.vs_offset(0),

	.AUDIO(audio),

	.JOY({m_coin1, m_start1, m_jump, m_fire, m_up, m_down, m_left, m_right}),
	.JOY2({m_coin2, m_start2, m_jump_2, m_fire_2, m_up_2, m_down_2, m_left_2, m_right_2}),

	.pause(pause_cpu),

	.hs_address(hs_address),
	.hs_data_in(hs_data_in),
	.hs_data_out(hs_data_out),
	.hs_write(hs_write_enable)
);

//// HISCORE SYSTEM
//// --------------
//wire [11:0]hs_address;
//wire [7:0] hs_data_in;
//wire [7:0] hs_data_out;
//wire hs_write_enable;
//wire hs_pause;
//wire hs_configured;
//wire OSD_STATUS;
//hiscore #(
//	.HS_ADDRESSWIDTH(12),
//	.HS_SCOREWIDTH(6),
//	.CFG_ADDRESSWIDTH(1),
//	.CFG_LENGTHWIDTH(2)
//) hi (
//	.*,
//	.clk(clk_sys),
//	.paused(pause_cpu),
//	.autosave(status[27]),
//	.ram_address(hs_address),
//	.data_from_ram(hs_data_out),
//	.data_to_ram(hs_data_in),
//	.data_from_hps(ioctl_dout),
//	.data_to_hps(ioctl_din),
//	.ram_write(hs_write_enable),
//	.ram_intent_read(),
//	.ram_intent_write(),
//	.pause_cpu(hs_pause),
//	.configured(hs_configured)
//);

endmodule
