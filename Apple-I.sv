//============================================================================
//  Apple I port to MiSTer
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
	//ADC
	inout   [3:0] ADC_BUS,

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
	input         UART_DSR,
	
	
	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..5 - USR1..USR4
	// Set USER_OUT to 1 to read from USER_IN.
	input   [5:0] USER_IN,
	output  [5:0] USER_OUT,

	input         OSD_STATUS	
);

//`define SOUND_DBG
assign VGA_SL=0;
assign VGA_F1=0;
//assign CE_PIXEL=1;

assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign USER_OUT = '1;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
assign ADC_BUS  = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CKE, SDRAM_CLK, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;

//assign VIDEO_ARX = status[9] ? 8'd16 : 8'd4;
//assign VIDEO_ARY = status[9] ? 8'd9  : 8'd3;


assign VIDEO_ARX = 4;
assign VIDEO_ARY = 3;

assign AUDIO_S = 0;
assign AUDIO_MIX = 0;

assign LED_DISK  = LED;
assign LED_POWER = 1;
assign LED_USER  = ioctl_download;

`include "build_id.v"
localparam CONF_STR = {
	"APPLE-I;;",
	"F,TXT,Load Ascii;",
//	"F,CAS,Load Cassette;",
	"O1,Scanlines,Off,On;",
	"-;",
	"R0,Reset;",
	"V,v",`BUILD_DATE
};

wire LED;

wire [31:0] status;
wire  [1:0] buttons;
wire        ioctl_download;
wire        ioctl_wr;
wire [13:0] ioctl_addr;
wire [7:0] ioctl_data;
wire  [7:0] ioctl_index;

wire        forced_scandoubler;
wire [10:0] ps2_key;
//wire [24:0] ps2_mouse;

wire [15:0] joystick_0, joystick_1;


//hps_io #(.STRLEN(($size(CONF_STR)>>3) ), .PS2DIV(4000)/*, .WIDE(0)*/) hps_io
hps_io #(.STRLEN(($size(CONF_STR)>>3) ), .PS2DIV(4000)/*, .WIDE(0)*/) hps_io
(
	.clk_sys(/*CLK_VIDEO*/clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),
	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),
	//.new_vmode(new_vmode),

	.status(status),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_index(ioctl_index),
	
	.ps2_kbd_clk_out    ( ps2_kbd_clk    ),
	.ps2_kbd_data_out   ( ps2_kbd_data   )
);


wire ps2_kbd_clk;
wire ps2_kbd_data;

wire r,g,b;

apple1 apple1 (
	.clk25(clk25),
	.rst_n(~(RESET| status[0] |  buttons[1])),
	.uart_rx(),
	.uart_tx(),
	.uart_cts(),
	.ps2_clk(ps2_kbd_clk),
	.ps2_din(ps2_kbd_data),
	.ps2_select(1'b1),
	.vga_h_sync(hs),
   .vga_v_sync(vs),
	.vga_red(r),
	.vga_grn(g),
	.vga_blu(b),
	.vga_de(VGA_DE),
	.vga_cls(),
   .ioctl_download(ioctl_download && ioctl_index),
   .textinput_dout(ioctl_data),
   .textinput_addr(ioctl_addr[12:0]),
   .pc_monitor()
);


wire clk_vid;
//assign CE_PIXEL = clk6p25;
assign CLK_VIDEO = clk25;
//assign CE_PIXEL = clk25;
assign CE_PIXEL = 1;

			
///////////////////////////////////////////////////
//wire clk_sys, clk_ram, clk_ram2, clk_pixel, locked;
wire clk_sys,locked;
wire hs,vs,hblank,vblank;

assign VGA_VS=vs;
assign VGA_HS=hs;
wire [8:0]audiomix;

//assign VGA_R=8'b11111111;
assign VGA_R={{r,r,r},5'b00000};
assign VGA_G={{g,g,g},5'b00000};
assign VGA_B={{b,b,b},5'b00000};
//assign VGA_DE=~(vblank | hblank);
//assign VGA_DE=(vblank & hblank);
assign AUDIO_L={audiomix,7'b0000000};
assign AUDIO_R=AUDIO_L;

wire clk6p25, clk25;

assign clk_sys = clk25;

pll pll (
	 .refclk ( CLK_50M   ),
	 .rst(0),
	 .locked 		( locked    ),        // PLL is running stable
	 .outclk_0		( clk6p25	),			
	 .outclk_1		( clk25		)
	 );

endmodule
