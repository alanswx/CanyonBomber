-- Top level file for Atari Canyon Bomber
-- (c) 2018 James Sweet
--
-- This is free software: you can redistribute
-- it and/or modify it under the terms of the GNU General
-- Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your
-- option) any later version.
--
-- This is distributed in the hope that it will
-- be useful, but WITHOUT ANY WARRANTY; without even the
-- implied warranty of MERCHANTABILITY or FITNESS FOR A
-- PARTICULAR PURPOSE. See the GNU General Public License
-- for more details.

-- Targeted to EP2C5T144C8 mini board but porting to nearly any FPGA should be fairly simple
-- See Canyon Bomber manual for video output details. Resistor values listed here have been scaled 
-- for 3.3V logic. 
-- R44 1.2k Ohm
-- R43 1.2k Ohm
-- R51 1.2k Ohm
-- R42 330R

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;


entity canyon_bomber is 
port(		
			Clk_50_I	: in	std_logic;	-- 50MHz input clock
			clk_12	: in	std_logic;	-- 12.09Mhz input clock
			clk_6_O	: out	std_logic;	-- 12.09Mhz input clock
			Reset_I		: in	std_logic;	-- Reset button (Active low)
			VideoW_O	: out 	std_logic;  	-- White video output (1.2k Ohm)
			VideoB_O	: out 	std_logic;  	-- Black video output (1.2k)
			Sync_O		: out 	std_logic;  	-- Composite sync output (1.2k)
			Audio1_O	: out 	std_logic_vector(6 downto 0);  	-- Player 1 audio
			Audio2_O	: out 	std_logic_vector(6 downto 0);  	-- Player 2 audio
			Coin1_I		: in  	std_logic;  	-- Coin switches (All inputs are active-low)
			Coin2_I		: in  	std_logic;
			Start1_I	: in  	std_logic;  	-- Player 1 and 2 Start buttons
			Start2_I	: in  	std_logic;
			Fire1_I		: in	std_logic;  	-- Fire buttons
			Fire2_I		: in	std_logic;
			Slam_I		: in	std_logic;  	-- Slam switch
			Test_I		: in  	std_logic;  	-- Self-test switch
			Lamp1_O		: out 	std_logic;	-- Player 1 and 2 start button LEDs
			Lamp2_O		: out 	std_logic;
			hs_O			: out std_logic;
			vs_O			: out std_logic;
			hblank_O		: out std_logic;
			vblank_O		: out std_logic;
			DIP_Sw		: in std_logic_vector(8 downto 1);
			
			-- signals that carry the ROM data from the MiSTer disk
			dn_addr        	: in  std_logic_vector(15 downto 0);
			dn_data        	: in  std_logic_vector(7 downto 0);
			dn_wr          	: in  std_logic

			);
end canyon_bomber;

architecture rtl of canyon_bomber is

--signal clk_12		: std_logic;
signal clk_6		: std_logic;
signal Ena_3k		: std_logic;
signal phi1 		: std_logic;
signal phi2		: std_logic;
signal reset_n		: std_logic;

signal Hcount		: std_logic_vector(8 downto 0) := (others => '0');
signal H256_s		: std_logic;
signal Vcount  		: std_logic_vector(7 downto 0) := (others => '0');
signal Vreset		: std_logic;
signal Vblank		: std_logic;
signal Vblank_s		: std_logic;
signal Vblank_n_s	: std_logic;
signal HBlank		: std_logic;
signal CompBlank_n_s	: std_logic;
signal Hsync		: std_logic;
signal Vsync		: std_logic;
signal CompSync_n_s	: std_logic;

signal WhitePF_n	: std_logic;
signal BlackPF_n	: std_logic;

signal Adr		: std_logic_vector(9 downto 0);
signal DBus		: std_logic_vector(7 downto 0);
signal Display		: std_logic_vector(7 downto 0);

signal RnW		: std_logic;
signal Write_n		: std_logic;
signal NMI_n		: std_logic;

signal RAM_n		: std_logic;
signal Sync_n		: std_logic;
signal Switch_n		: std_logic;
signal Display_n	: std_logic;
signal TimerReset_n	: std_logic;

signal Attract1		: std_logic;
signal Attract2		: std_logic;	
signal Skid1		: std_logic;
signal Skid2		: std_logic;
signal Lamp1		: std_logic;
signal Lamp2		: std_logic;

signal Motor1_n 	: std_logic;
signal Motor2_n		: std_logic;
signal Whistle1		: std_logic;
signal Whistle2		: std_logic;
signal Explode_n	: std_logic;
signal Ship1_n		: std_logic;
signal Ship2_n		: std_logic;
signal Shell1_n		: std_logic;
signal Shell2_n		: std_logic;

--signal DIP_Sw		: std_logic_vector(8 downto 1);
signal prog_rom3L_cs : std_logic;
signal prog_rom3H_cs : std_logic;
signal progROM4_cs : std_logic;
signal Char_ROM_cs : std_logic;
signal M5_rom_cs : std_logic;
signal N5_rom_cs : std_logic;


begin
-- Configuration DIP switches, these can be brought out to external switches if desired
-- See Canyon Bomber manual for complete information. Active low (0 = On, 1 = Off)
--    8 	7							Game Cost			(10-1 Coin per player, 11-Two coins per player, 01-Two players per coin, 00-Free Play)
--				6	5					Misses Per Play   (00-Three, 01-Four, 10-Five, 11-Six)
--   					4	3			Not Used
--								2	1	Language				(00-English, 10-French, 01-Spanish, 11-German)
--										
--DIP_Sw <= "10100000"; -- Config dip switches



--9499-01.j1	1024	0			0 0000 0000 0000  prog_rom3L (cpu)
--9503-01.p1	1024	1024		0 0100 0000 0000  prog_rom3H (cpu)
--9496-01.d1	2048	2048		0 1000 0000 0000  progROM4 (cpu)
--9492-01.n8	1024	4096		1 0000 0000 0000  Char_ROM (playfield)
--9506-01.m5	256	5120		1 0100 0000 0000  M5_rom (motion)
--9505-01.n5	256	5376		1 0101 0000 0000  N5_rom (motion)
--9491-01.j6	256	5632		1 0110 0000 0000  ?

prog_rom3L_cs <= '1' when dn_addr(12 downto 10) = "000"     else '0';
prog_rom3H_cs <= '1' when dn_addr(12 downto 10) = "001"     else '0';
progROM4_cs <= '1' when dn_addr(12 downto 11) = "01"     else '0';
Char_ROM_cs <= '1' when dn_addr(12 downto 10) = "100"     else '0';
M5_rom_cs <= '1' when dn_addr(12 downto 8) =  "10100"   else '0';
N5_rom_cs <= '1' when dn_addr(12 downto 8) =  "10101"   else '0';
--N5_rom_cs <= '1' when dn_addr(12 downto 8) =  "10110"   else '0';
--N5_rom_cs <= '1' when dn_addr(12 downto 8) =  "10100"   else '0';

clk_6_O<=clk_6;

-- PLL to generate 12.09 MHz clock
--PLL: entity work.clk_pll
--port map(
--		inclk0 => Clk_50_I,
--		c0 => clk_12
--		);
		
		
Vid_sync: entity work.synchronizer
port map(
		clk_12 => clk_12,
		clk_6	=> clk_6,
		hcount => hcount,
		vcount => vcount,
		hsync => hsync,
		hblank => hblank,
		vblank_s => vblank_s,
		vblank_n_s => vblank_n_s,
		vblank => vblank,
		vsync => vsync,
		vreset => vreset
		);


Background: entity work.playfield
port map( 
		clk6	=> clk_6,
		clk12	=> clk_12,
		display => display,
		HCount => HCount,
		VCount => VCount,
		HBlank => HBlank,		
		H256_s => H256_s,
		VBlank => VBlank,
		VBlank_n_s => Vblank_n_s,
		HSync => Hsync,
		VSync => VSync,
		CompSync_n_s => CompSync_n_s,
		CompBlank_n_s => CompBlank_n_s,
		WhitePF_n => WhitePF_n,
		BlackPF_n => BlackPF_n,
		
		dn_wr => dn_wr,
		dn_addr=>dn_addr,
		dn_data=>dn_data,

		Char_ROM_cs=>Char_ROM_cs
		
		);

		
Motion_Objects: entity work.motion
port map(
		CLK6 => clk_6,
		CLK12 => clk_12,
		PHI2 => phi2,
		DISPLAY => Display,
		H256_s => H256_s,
		HSync => HSync,
		VCount => VCount,
		HCount => HCount,
		Shell1_n => Shell1_n,
		Shell2_n => Shell2_n,
		Ship1_n => Ship1_n,
		Ship2_n => Ship2_n,
		
		dn_wr => dn_wr,
		dn_addr=>dn_addr,
		dn_data=>dn_data,
		
		M5_rom_cs=>M5_rom_cs,
		N5_rom_cs=>N5_rom_cs
		
		);
		
		
CPU: entity work.cpu_mem
port map(
		Clk12 => clk_12,
		Clk6	=> clk_6,
		Ena_3k => Ena_3k,
		Reset_I => Reset_I,
		Reset_n => reset_n,
		VBlank => VBlank,
		VCount => VCount,
		HCount => HCount,
		Test_n => Test_I,
		Coin1_n => Coin1_I,
		Coin2_n	=> Coin2_I,
		Start1_n => Start1_I,
		Start2_n => Start2_I,
		Fire1_n => Fire1_I,
		Fire2_n => Fire2_I,
		Slam_n => Slam_I,
		DIP_Sw => DIP_Sw,
		Motor1_n => Motor1_n,
		Motor2_n => Motor2_n,
		Explode_n => Explode_n,
		Whistle1 => Whistle1,
		Whistle2 => Whistle2,
		Player1Lamp => Lamp1_O,
		Player2Lamp => Lamp2_O,
		Attract1 => Attract1,
		Attract2 => Attract2,
		Phi1_o => Phi1,
		Phi2_o => Phi2,
		DBus => DBus,
		Display => Display,
		
		dn_wr => dn_wr,
		dn_addr=>dn_addr,
		dn_data=>dn_data,
		
		prog_rom3L_cs =>prog_rom3L_cs,
		prog_rom3H_cs =>prog_rom3H_cs,
		progROM4_cs =>progROM4_cs

		);

	
Sound: entity work.audio
port map( 
		Clk_50 => Clk_50_I,
		Clk_6	=> Clk_6,
		Ena_3k => Ena_3k,
		Reset_n => Reset_n,
		Motor1_n => Motor1_n,
		Motor2_n => Motor2_n,
		Whistle1 => Whistle1,
		Whistle2 => Whistle2,
		Explode_n => Explode_n,
		Attract1 => Attract1,
		Attract2 => Attract2,
		DBus => DBus,
		VCount => VCount,
		Audio1 => Audio1_O,
		Audio2 => Audio2_O
		);


-- Video mixing	
VideoB_O <= ( BlackPF_n and Ship1_n and Shell1_n and CompBlank_n_s);	
VideoW_O <= not(WhitePF_n and Ship2_n and Shell2_n);  
Sync_O <= CompSync_n_s;
hs_O<= hsync;
hblank_O <= HBlank;
vblank_O <= VBlank;
vs_O <=vsync;

end rtl;
