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
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)

	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S    // 1 - signed audio samples, 0 - unsigned
);

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = lamp;

assign HDMI_ARX = status[1] ? 8'd16 : 8'd4;
assign HDMI_ARY = status[1] ? 8'd9  : 8'd3;

`include "build_id.v"
localparam CONF_STR = {
	"A.CANYON;;",
	"-;",
	"O1,Aspect Ratio,Original,Wide;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",  
	"-;",
	//"OCD,Language,English,German,French,Spanish;", // broken?
	"O89,Misses,Three,Four,Five,Six;",
	"OA,Test,Off,On;",
	"-;",
	"R0,Reset;",
	"J1,Fire,Start 1P,Start 2P;",
	"V,v",`BUILD_DATE
};


wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_data;

wire [10:0] ps2_key;

wire [15:0] joystick_0, joystick_1;


hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.ps2_key(ps2_key)
);



wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
			'h029: btn_fire        <= pressed; // space
			'h014: btn_fire        <= pressed; // ctrl

			'h005: btn_one_player  <= pressed; // F1
			'h006: btn_two_players <= pressed; // F2
			// JPAC/IPAC/MAME Style Codes
			'h016: btn_start_1     <= pressed; // 1
			'h01E: btn_start_2     <= pressed; // 2
			'h02E: btn_coin_1      <= pressed; // 5
			'h036: btn_coin_2      <= pressed; // 6
			'h01C: btn_fire_2      <= pressed; // A
		endcase
	end
end

reg btn_fire = 0;
reg btn_one_player  = 0;
reg btn_two_players = 0;

reg btn_start_1=0;
reg btn_start_2=0;
reg btn_coin_1=0;
reg btn_coin_2=0;
reg btn_fire_2=0;


wire m_fire     = btn_fire   | joystick_0[4];
wire m_fire_2   = btn_fire_2 | joystick_1[4];



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

wire [7:0] SW1 = {1'b1,1'b0,status[9:8],1'b0,1'b0,status[13:12]};





wire videowht,videoblk,compositesync,lamp,lamp2;
canyon_bomber canyon_bomber(
	.Clk_50_I(CLK_50M),
	.Reset_I(~(RESET | status[0] | buttons[1] | ioctl_download)),
	
	.dn_addr(ioctl_addr[16:0]),
	.dn_data(ioctl_data),
	.dn_wr(ioctl_wr),

	
	.clk_12(clk_12),
	.VideoW_O(videowht),
	.VideoB_O(videoblk),
	.Sync_O(compositesync),
	.Audio1_O(audio1),
	.Audio2_O(audio2),
	.Coin1_I(~(m_coin|btn_coin_1)),
	.Coin2_I(~(m_coin|btn_coin_2)),
	.Start1_I(~(m_start1|btn_start_1)),
	.Start2_I(~(m_start2|btn_start_2)),
	.Fire1_I(~m_fire),
	.Fire2_I(~m_fire_2),
	.Slam_I(1),
	.Test_I(~status[10]),
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

///////////////////////////////////////////////////
wire clk_24,clk_12,clk_6;
wire clk_sys,locked;
reg [7:0] vid_mono;

always @(posedge clk_sys) begin
		casex({videowht,videoblk})
			2'b01: vid_mono<=8'b01110000;
			2'b10: vid_mono<=8'b10000110;
			2'b11: vid_mono<=8'b11111111;
			2'b00: vid_mono<=8'b00000000;
		endcase
end

assign r=vid_mono[7:5];
assign g=vid_mono[7:5];
assign b=vid_mono[7:5];

assign AUDIO_L={audio1,1'b0,8'b00000000};
assign AUDIO_R={audio2,1'b0,8'b00000000};
assign AUDIO_S = 0;


wire hblank, vblank;
wire hs, vs;
wire [2:0] r,g;
wire [2:0] b;

reg ce_pix;
always @(posedge clk_24) begin
        reg old_clk;

        old_clk <= clk_6;
        ce_pix <= old_clk & ~clk_6;
end

arcade_fx #(298,9) arcade_video
(
        .*,

        .clk_video(clk_24),

        .RGB_in({r,g,b}),
        .HBlank(hblank),
        .VBlank(vblank),
        .HSync(hs),
        .VSync(vs),

        .fx(status[5:3])
);


pll pll (
	.refclk ( CLK_50M   ),
	.rst(0),
	.locked 		( locked    ),        // PLL is running stable
	.outclk_0	( clk_24	),        // 24 MHz
	.outclk_1	( clk_12	)        // 12 MHz
	 );

assign clk_sys=clk_12;


endmodule
