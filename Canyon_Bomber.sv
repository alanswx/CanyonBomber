//============================================================================
//  Canyon Bomber port to MiSTer
//  Copyright (c) 2019 Alan Steremberg - alanswx
//
//   
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [44:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S, // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
	input         TAPE_IN,

	// SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
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
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR
);

//`define SOUND_DBG
assign VGA_SL=0;

assign VGA_F1=0;
assign CE_PIXEL=1;

assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;

//assign VIDEO_ARX = status[9] ? 8'd16 : 8'd4;
//assign VIDEO_ARY = status[9] ? 8'd9  : 8'd3;


assign VIDEO_ARX = 4;
assign VIDEO_ARY = 3;

assign AUDIO_S = 0;
assign AUDIO_MIX = 0;

assign LED_DISK  = lamp;
assign LED_POWER = 1;
assign LED_USER  = ioctl_download;

`include "build_id.v"
localparam CONF_STR = {
	"A.CANYON;;",
	"-;",
	"O12,Misses,Three,Four,Five,Six;",
	"O3,Test,Off,On;",
	"-;",
	"T6,Reset;",
	"J,Fire,Start 1P,Start 2P;",
	"V,v",`BUILD_DATE
};


wire [31:0] status;
wire  [1:0] buttons;
wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_data;

wire        forced_scandoubler;
wire [10:0] ps2_key;
//wire [24:0] ps2_mouse;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;


hps_io #(.STRLEN(($size(CONF_STR)>>3) )/*, .PS2DIV(1000), .WIDE(0)*/) hps_io
(
	.clk_sys(CLK_VIDEO/*clk_sys*/),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),
	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),
	.new_vmode(new_vmode),

	.status(status),
	.status_in({status[31:8],region_req,status[5:0]}),
	.status_set(region_set),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	
	.ps2_key(ps2_key)
);



wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
//			'hX75: btn_up          <= pressed; // up
//			'hX72: btn_down        <= pressed; // down
			'hX6B: btn_left        <= pressed; // left
			'hX74: btn_right       <= pressed; // right
			'h029: btn_fire        <= pressed; // space
			'h014: btn_fire        <= pressed; // ctrl

			'h005: btn_one_player  <= pressed; // F1
			'h006: btn_two_players <= pressed; // F2
		endcase
	end
end

//reg btn_up    = 0;
//reg btn_down  = 0;
reg btn_right = 0;
reg btn_left  = 0;
reg btn_fire  = 0;
reg btn_one_player  = 0;
reg btn_two_players = 0;

//wire m_up     =  btn_up    | joy[3];
//wire m_down   =  btn_down  | joy[2];
//wire m_left   =  btn_left  | joystick_0[1];
//wire m_right  =  btn_right | joystick_0[0];
wire m_fire   = btn_fire | joystick_0[4];
wire m_fire2   = btn_fire | joystick_1[4];

wire m_start1 = btn_one_player  | joystick_0[5];
wire m_start2 = btn_two_players | joystick_1[5];
wire m_coin   = m_start1 | m_start2;



/*
-- Configuration DIP switches, these can be brought out to external switches if desired
-- See Canyon Bomber manual for complete information. Active low (0 = On, 1 = Off)
--    8 	7							Game Cost			(10-1 Coin per player, 11-Two coins per player, 01-Two players per coin, 00-Free Play)
--				6	5					Misses Per Play   (00-Three, 01-Four, 10-Five, 11-Six)
--   					4	3			Not Used
--								2	1	Language				(00-English, 10-French, 01-Spanish, 11-German)
--										
DIP_Sw <= "10100000"; -- Config dip switches


*/

wire [7:0] SW1 = {1'b1,1'b0,status[2:1],1'b0,1'b0,1'b0,1'b0};





wire videowht,videoblk,compositesync,lamp;
canyon_bomber canyon_bomber(
	.Clk_50_I(CLK_50M),
	.Reset_I(~(RESET | status[0] | status[6] | buttons[1] | ioctl_download)),
	
	.dn_addr(ioctl_addr[16:0]),
	.dn_data(ioctl_data),
	.dn_wr(ioctl_wr),

	
	.clk_12(clk_12),
	.VideoW_O(videowht),
	.VideoB_O(videoblk),
	.Sync_O(compositesync),
	.Audio1_O(audio1),
	.Audio2_O(audio2),
	.Coin1_I(~m_start1),
	.Coin2_I(~m_start2),
	.Start1_I(~m_start1),
	.Start2_I(~m_start2),
	.Fire1_I(~m_fire),
	.Fire2_I(~m_fire2),
	.Slam_I(1),
	.Test_I(~status[3]),
	.clk_6_O(clk_6),
	.Lamp1_O(lamp),
	.Lamp2_O(lamp2),
	.hs_O(hs),
	.vs_O(vs),
	.hblank_O(hblank),
	.vblank_O(vblank),
	.DIP_Sw(SW1)
			);

			
wire [6:0] audio1;
wire [6:0] audio2;
wire [1:0] video;
wire [3:0] videor;
///////////////////////////////////////////////////
//wire clk_sys, clk_ram, clk_ram2, clk_pixel, locked;
wire clk_sys,locked;
wire clk_12,CLK_VIDEO_2;
wire hs,vs,hblank,vblank;
assign VGA_HS=hs;
assign VGA_VS=vs;
assign VGA_HS=hs;
reg [7:0] vid_mono;
wire[1:0] sprint_vid;

//assign sprint_vid = {videowht,videoblk};
always @(posedge clk_sys) begin
		casex({videowht,videoblk})
			2'b01: vid_mono<=8'b01010000;
			2'b10: vid_mono<=8'b10000110;
			2'b11: vid_mono<=8'b11111111;
			2'b00: vid_mono<=8'b00000000;
		endcase
end

assign VGA_R=vid_mono;
assign VGA_G=vid_mono;
assign VGA_B=vid_mono;

assign VGA_DE=~(vblank | hblank);
assign AUDIO_L={audio1,1'b0,8'b00000000};
assign AUDIO_R={audio2,1'b0,8'b00000000};
assign CLK_VIDEO=clk_6;

//assign SDRAM_CLK=ram_clock;
pll pll (
	 .refclk ( CLK_50M   ),
	 .rst(0),
	 .locked 		( locked    ),        // PLL is running stable
	 .outclk_0		( clk_sys	),
	 .outclk_1		( clk_12		)        // 12 MHz
	 );

endmodule
