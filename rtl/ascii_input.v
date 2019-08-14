// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//
// Description: ascii file load interface
//
// Author.....: Alan Steremberg
// Date.......: 13-8-2019
//

module ascii_input(
    input       clk25,      // 25MHz clock
    input       rst,        // active high reset

    // I/O interface to keyboard
    input       key_clk,    // clock input from keyboard / device
    input ioctl_download,
    input [7:0] textinput_dout,
    input [12:0] textinput_addr,

    // I/O interface to computer
    input       cs,         // chip select, active high
    input       address,    // =0 RX buffer, =1 RX status
    output reg [7:0] dout,   // 8-bit output bus.
    output  data_ready // 8-bit output bus.
);

	// save loaded data into ram
   reg [12:0] ascii_last_byte = 13'b0;
   reg [7:0] ascii_data[0:8191];
   reg [12:0] text_byte = 13'b0;
   reg in_dl = 1'b0;
 
   assign data_ready= in_dl & !ioctl_download;

    reg  prev_ps2_clkdb;    // previous clock state (in clk25 domain)
    
    // keyboard translation signals
    reg [7:0]  ascii;       // ASCII code of received character
    reg ascii_rdy;          // new ASCII character received
    reg shift;              // state of the shift key
    reg [2:0] cur_state;
    reg [2:0] next_state;

    always @(posedge clk25 or posedge rst)
    begin
        if (rst)
        begin
            prev_ps2_clkdb <= 1'b0;
            ascii_rdy   <= 0;
        end
        else
        begin
            // and sample the state of the PS/2 data line
            if ((prev_ps2_clkdb == 1'b1) && (key_clk == 1'b0))
            begin
              // check for negative edge of PS/2 clock
              if (!ascii_rdy & data_ready& (text_byte<=ascii_last_byte))
		        begin
				     case(ascii_data[text_byte])
					  8'h0A: ascii=8'h0D;
					  default: ascii= ascii_data[text_byte];
					  endcase
                 
            	  ascii_rdy   <= 1;
                 $display("inside a %x",ascii);
                 text_byte = text_byte + 13'b00000001;
		        end
            end
            
            // update previous clock state
            prev_ps2_clkdb <= key_clk;//ps2_clkdb;            
            
  	         if (ioctl_download)
            begin
                 $display("ioctl_download: %x",textinput_addr);
                 ascii_data[textinput_addr] = textinput_dout;
                 ascii_last_byte = textinput_addr;
                 text_byte = 13'b0;
                 in_dl=1'b1;
            end
            else
            begin
                if (in_dl & text_byte>(ascii_last_byte+1) & !ascii_rdy)
                    begin
                       in_dl=1'b0;
                       $display("indl %x",in_dl);
                       $display("ascii_rdy %x",ascii_rdy);
                    end
            end

            // handle I/O from CPU
            if (cs == 1'b1)
            begin
                if (address == 1'b0)
                begin
                    // RX buffer address
                    dout <= {1'b1, ascii[6:0]};
                    ascii_rdy <= 1'b0;
                end
                else
                begin
                    // RX status register
                    dout <= {ascii_rdy, 7'b0};
                end
            end
           
          end
			 end

endmodule

