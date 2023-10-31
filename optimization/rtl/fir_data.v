module fir_data
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(  
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
	input	wire					 tap_finish,
    output  wire [(pADDR_WIDTH-1):0] tap_addr,	
	output  wire					 valid,
	output  wire					 rst,
	output  wire					 tail,
	output  wire					 last,

    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready,  
	
    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);

/*
AXI-stream:
   M(PS)->S(FIR):
        ss_tdata
        ss_tlast
		ss_tvalid
    M(PS)<-S(FIR):
        ss_tready

SRAM:
FIR<-SRAM
    data_Do

FIR->SRAM
    data_WE
    data_EN
    data_Di
    data_A


*/
reg sslast;
reg tready;

reg [4:0] curr_state;
reg [4:0] next_state;

parameter s0   = 5'b00000; // reset ram[0] 
parameter s1   = 5'b00001; // reset ram[1] 
parameter s2   = 5'b00010; // reset ram[2]
parameter s3   = 5'b00011; // reset ram[3]
parameter s4   = 5'b00100; // reset ram[4]
parameter s5   = 5'b00101; // reset ram[5]
parameter s6   = 5'b00110; // reset ram[6]
parameter s7   = 5'b00111; // reset ram[7]
parameter s8   = 5'b01000; // reset ram[8]
parameter s9   = 5'b01001; // reset ram[9]
parameter s10  = 5'b01010; // reset ram[10]

parameter s11  = 5'b01011; // load data to mem
parameter s12  = 5'b01100; // write ram 

parameter s13  = 5'b01101; // read sram mem[0]
parameter s14  = 5'b01110; // read sram mem[1]
parameter s15  = 5'b01111; // read sram mem[2]
parameter s16  = 5'b10000; // read sram mem[3]
parameter s17  = 5'b10001; // read sram mem[4]
parameter s18  = 5'b10010; // read sram mem[5]
parameter s19  = 5'b10011; // read sram mem[6]
parameter s20  = 5'b10100; // read sram mem[7]
parameter s21  = 5'b10101; // read sram mem[8]
parameter s22  = 5'b10110; // read sram mem[9]
parameter s23  = 5'b10111; // read sram mem[10]
parameter s24  = 5'b11000; // wait

parameter s25  = 5'b11001; // last load


always@(posedge axis_clk or negedge axis_rst_n)
	if (!axis_rst_n) curr_state <= s0;
	else        curr_state <= next_state;

always@(*)
	case(curr_state)
		s0:  if(ss_tvalid) next_state = s1;
		     else next_state = s0;
		s1:  if(ss_tvalid) next_state = s2;
		     else next_state = s1;
		s2:  if(ss_tvalid) next_state = s3;
		     else next_state = s2;
		s3:  if(ss_tvalid) next_state = s4;
		     else next_state = s3;
		s4:  if(ss_tvalid) next_state = s5;
		     else next_state = s4;
		s5:  if(ss_tvalid) next_state = s6;
		     else next_state = s5;
		s6:  if(ss_tvalid) next_state = s7;
		     else next_state = s6;
		s7:  if(ss_tvalid) next_state = s8;
		     else next_state = s7;
		s8:  if(ss_tvalid) next_state = s9;
		     else next_state = s8;
		s9:  if(ss_tvalid) next_state = s10;		     
		     else next_state = s9;
		s10: if(tap_finish) next_state = s11;
		     else next_state = s10;
		s11: if(tap_finish) next_state = s12;
		     else next_state = s11;
		s12: if(tap_finish) next_state = s13;
		     else next_state = s12;
		s13: if(tap_finish) next_state = s14;
		     else next_state = s13;
		s14: if(tap_finish) next_state = s15;
		     else next_state = s14;
		s15: if(tap_finish) next_state = s16;
		     else next_state = s15;
		s16: if(tap_finish) next_state = s17;
		     else next_state = s16;
		s17: if(tap_finish) next_state = s18;
		     else next_state = s17;
		s18: if(tap_finish) next_state = s19;
		     else next_state = s18;
		s19: if(tap_finish) next_state = s20;
		     else next_state = s19;
		s20: if(tap_finish) next_state = s21;
		     else next_state = s20;
		s21: if(tap_finish) next_state = s22;
		     else next_state = s21;
		s22: if(tap_finish) next_state = s23;
		     else next_state = s22;
		s23: if(tap_finish) next_state = s24;
		     else next_state = s23;
		s24: if(tap_finish) next_state = (ss_tlast)?s25:s11;
		     else next_state = s24;
		s25: if(tap_finish) next_state = s12;
		     else next_state = s25; 
		default : next_state = s0;		 			 			 			 			 			 			 			 			 			 				 			 
	endcase

reg [3:0] ramwenin;
reg [(pDATA_WIDTH-1):0] ramdatain;
reg [(pADDR_WIDTH-1):0] ramaddrin;
reg ramenin;

reg datavalid;
reg datarst;
reg datatail;
reg datalast;

reg [10:0] ptr;

reg [(pADDR_WIDTH-1):0] tapramaddrin;

always@(posedge axis_clk or negedge axis_rst_n) begin	
	if(!axis_rst_n) begin
		tready <= 0;

		ramwenin <= 4'b0000;
		ramdatain <= 0;
		ramaddrin <= 0;
		ramenin <= 0;

		datavalid <= 0;
		datarst <= 0;
		datatail <= 0;

		ptr <=0;	
		tapramaddrin <= 0;	
	end	
	else 
		case(curr_state)
		s0:  begin 
		     tready <= 0;

			 ramwenin <= 4'b1111;
			 ramdatain <= 0;
			 ramaddrin <= 0;
			 ramenin <= 1;
			 
			 datavalid <= 0;
			 datarst <= 0;
			 datatail <= 0;
			 datalast <= 0;
		end
		s1:  begin
			 tready <= 0;

			 ramwenin <= 4'b1111;
			 ramdatain <= 0;
			 ramaddrin <= 4;
			 ramenin <= 1;

			 datavalid <= 0;
			 datarst <= 0;
			 datatail <= 0;
			 datalast <= 0;
		end
		s2:  begin
			 tready <= 0;

			 ramwenin <= 4'b1111;
			 ramdatain <= 0;
			 ramaddrin <= 8;
			 ramenin <= 1;

			 datavalid <= 0;
			 datarst <= 0;
			 datatail <= 0;
			 datalast <= 0;
			 
		end
		s3:  begin
			 tready <= 0;

			 ramwenin <= 4'b1111;
			 ramdatain <= 0;
			 ramaddrin <= 12;
			 ramenin <= 1;

			 datavalid <= 0;
			 datarst <= 0;
			 datatail <= 0;
			 datalast <= 0;			 
		end
		s4:  begin
			 tready <= 0;

			 ramwenin <= 4'b1111;
			 ramdatain <= 0;
			 ramaddrin <= 16;
			 datavalid <= 0;
			 datarst <= 0;
			 datatail <= 0;
			 datalast <= 0;			 
		end
		s5:  begin
			 tready <= 0;

			 ramwenin <= 4'b1111;
			 ramdatain <= 0;
			 ramaddrin <= 20;
			 ramenin <= 1;

			 datavalid <= 0;
			 datarst <= 0;
			 datatail <= 0;
			 datalast <= 0;			 
		end
		s6:  begin
			 tready <= 0;

			 ramwenin <= 4'b1111;
			 ramdatain <= 0;
			 ramaddrin <= 24;
			 ramenin <= 1;

			 datavalid <= 0;
			 datarst <= 0;
			 datatail <= 0;
			 datalast <= 0;			 
		end
		s7:  begin
			 tready <= 0;

			 ramwenin <= 4'b1111;
			 ramdatain <= 0;
			 ramaddrin <= 28;
			 ramenin <= 1;

			 datavalid <= 0;
			 datarst <= 0;
			 datatail <= 0;
			 datalast <= 0;		 
		end
		s8:  begin
			 tready <= 0;

			 ramwenin <= 4'b1111;
			 ramdatain <= 0;
			 ramaddrin <= 32;
			 ramenin <= 1;

			 datavalid <= 0;
			 datarst <= 0;
			 datatail <= 0;
			 datalast <= 0;			 
		end
		s9:  begin
			 tready <= 0;

			 ramwenin <= 4'b1111;
			 ramdatain <= 0;
			 ramaddrin <= 36;

			 datavalid <= 0;
			 datarst <= 0;
			 datatail <= 0;
			 datalast <= 0;
		end
		s10: begin
			 tready <= 0;

			 ramwenin <= 4'b1111;
			 ramdatain <= 0;
			 ramaddrin <= 40;
			 ramenin <= 1;

			 datavalid <= 0;
			 datarst <= 0;
			 datatail <= 0;
			 datalast <= 0;
		end
		s11: begin
			 tready <= 0;

			 datavalid <= 0;
			 datarst <= 0;
			 datatail <= 0;
		end
		s12: begin
			 tready <= 1;

			 ramwenin <= 4'b1111;
			 ramdatain <= ss_tdata;
			 ramaddrin <= ptr << 2;

			 datavalid <= 0;
			 datarst <= 0;
			 datatail <= 0;
		end		
		s13: begin
			 tready <= 0;
			 ramwenin <= 4'b0000;

			 case(ptr)
			 	4'd0: ramaddrin <= 0;
				4'd1: ramaddrin <= 4;
				4'd2: ramaddrin <= 8;
				4'd3: ramaddrin <= 12;
				4'd4: ramaddrin <= 16; 
				4'd5: ramaddrin <= 20;
				4'd6: ramaddrin <= 24;
				4'd7: ramaddrin <= 28;
				4'd8: ramaddrin <= 32;
				4'd9: ramaddrin <= 36;
				4'd10: ramaddrin <= 40;
				default: ramaddrin <= 0;
			 endcase

			 datavalid <= 0;
			 datarst <= 1;
			 datatail <= 0;
			 tapramaddrin <= 0;
		end
		s14: begin
			 tready <= 0;

			 ramwenin <= 4'b0000;
			 ramenin <= 1;

			 case(ptr)
			 	4'd0: ramaddrin <= 40;
				4'd1: ramaddrin <= 0;
				4'd2: ramaddrin <= 4;
				4'd3: ramaddrin <= 8;
				4'd4: ramaddrin <= 12; 
				4'd5: ramaddrin <= 16;
				4'd6: ramaddrin <= 20;
				4'd7: ramaddrin <= 24;
				4'd8: ramaddrin <= 28;
				4'd9: ramaddrin <= 32;
				4'd10: ramaddrin <= 36;
				default: ramaddrin <= 0;
			 endcase

			 datavalid <= 1;
			 datarst <= 0;
			 datatail <= 0;
			 tapramaddrin <= 4;
		end	
		s15: begin
			 tready <= 0;

			 ramwenin <= 4'b0000;
			 ramenin <= 1;	

			 case(ptr)
			 	4'd0: ramaddrin <= 36;
				4'd1: ramaddrin <= 40;
				4'd2: ramaddrin <= 0;
				4'd3: ramaddrin <= 4;
				4'd4: ramaddrin <= 8; 
				4'd5: ramaddrin <= 12;
				4'd6: ramaddrin <= 16;
				4'd7: ramaddrin <= 20;
				4'd8: ramaddrin <= 24;
				4'd9: ramaddrin <= 28;
				4'd10: ramaddrin <= 32;
				default: ramaddrin <= 0;
			 endcase

			 datavalid <= 1;
			 datarst <= 0;
			 datatail <= 0;
			 tapramaddrin <= 8;
		end	
		s16: begin
			 tready <= 0;

			 ramwenin <= 4'b0000;
			 ramenin <= 1;

			 case(ptr)
			 	4'd0: ramaddrin <= 32;
				4'd1: ramaddrin <= 36;
				4'd2: ramaddrin <= 40;
				4'd3: ramaddrin <= 0;
				4'd4: ramaddrin <= 4; 
				4'd5: ramaddrin <= 8;
				4'd6: ramaddrin <= 12;
				4'd7: ramaddrin <= 16;
				4'd8: ramaddrin <= 20;
				4'd9: ramaddrin <= 24;
				4'd10: ramaddrin <= 28;
				default: ramaddrin <= 0;
			 endcase

			 datavalid <= 1;
			 datarst <= 0;
			 datatail <= 0;	
			 tapramaddrin <= 12;	 
		end	
		s17: begin
			 tready <= 0;

			 ramwenin <= 4'b0000;
			 ramenin <= 1;	

			 case(ptr)
			 	4'd0: ramaddrin <= 28;
				4'd1: ramaddrin <= 32;
				4'd2: ramaddrin <= 36;
				4'd3: ramaddrin <= 40;
				4'd4: ramaddrin <= 0; 
				4'd5: ramaddrin <= 4;
				4'd6: ramaddrin <= 8;
				4'd7: ramaddrin <= 12;
				4'd8: ramaddrin <= 16;
				4'd9: ramaddrin <= 20;
				4'd10: ramaddrin <= 24;
				default: ramaddrin <= 0;
			 endcase

			 datavalid <= 1;
			 datarst <= 0;
			 datatail <= 0;
			 tapramaddrin <= 16;
		end	
		s18: begin
			 tready <= 0;

			 ramwenin <= 4'b0000;
			 ramenin <= 1;

			 case(ptr)
			 	4'd0: ramaddrin <= 24;
				4'd1: ramaddrin <= 28;
				4'd2: ramaddrin <= 32;
				4'd3: ramaddrin <= 36;
				4'd4: ramaddrin <= 40; 
				4'd5: ramaddrin <= 0;
				4'd6: ramaddrin <= 4;
				4'd7: ramaddrin <= 8;
				4'd8: ramaddrin <= 12;
				4'd9: ramaddrin <= 16;
				4'd10: ramaddrin <= 20;
				default: ramaddrin <= 0;
			 endcase

			 datavalid <= 1;
			 datarst <= 0;
			 datatail <= 0;	 
			 tapramaddrin <= 20;
		end	
		s19: begin
			 tready <= 0;

			 ramwenin <= 4'b0000;
			 ramenin <= 1;	

			 case(ptr)
			 	4'd0: ramaddrin <= 20;
				4'd1: ramaddrin <= 24;
				4'd2: ramaddrin <= 28;
				4'd3: ramaddrin <= 32;
				4'd4: ramaddrin <= 36; 
				4'd5: ramaddrin <= 40;
				4'd6: ramaddrin <= 0;
				4'd7: ramaddrin <= 4;
				4'd8: ramaddrin <= 8;
				4'd9: ramaddrin <= 12;
				4'd10: ramaddrin <= 16;
				default: ramaddrin <= 0;
			 endcase

			 datavalid <= 1;
			 datarst <= 0;
			 datatail <= 0;	
			 tapramaddrin <= 24;	 
		end									
		s20: begin
			 tready <= 0;

			 ramwenin <= 4'b0000;
			 ramenin <= 1;

			 case(ptr)
			 	4'd0: ramaddrin <= 16;
				4'd1: ramaddrin <= 20;
				4'd2: ramaddrin <= 24;
				4'd3: ramaddrin <= 28;
				4'd4: ramaddrin <= 32; 
				4'd5: ramaddrin <= 36;
				4'd6: ramaddrin <= 40;
				4'd7: ramaddrin <= 0;
				4'd8: ramaddrin <= 4;
				4'd9: ramaddrin <= 8;
				4'd10: ramaddrin <= 12;
				default: ramaddrin <= 0;
			 endcase			 

			 datavalid <= 1;
			 datarst <= 0;
			 datatail <= 0;
			 tapramaddrin <= 28;
		end	
		s21: begin
			 tready <= 0;

			 ramwenin <= 4'b0000;
			 ramenin <= 1;

			 case(ptr)
			 	4'd0: ramaddrin <= 12;
				4'd1: ramaddrin <= 16;
				4'd2: ramaddrin <= 20;
				4'd3: ramaddrin <= 24;
				4'd4: ramaddrin <= 28; 
				4'd5: ramaddrin <= 32;
				4'd6: ramaddrin <= 36;
				4'd7: ramaddrin <= 40;
				4'd8: ramaddrin <= 0;
				4'd9: ramaddrin <= 4;
				4'd10: ramaddrin <= 8;
				default: ramaddrin <= 0;
			 endcase

			 datavalid <= 1;
			 datarst <= 0;
			 datatail <= 0;	
			 tapramaddrin <= 32;	 
		end	
		s22: begin
			 tready <= 0;

			 ramwenin <= 4'b0000;
			 ramenin <= 1;	
			 
			 case(ptr)
			 	4'd0: ramaddrin <= 8;
				4'd1: ramaddrin <= 12;
				4'd2: ramaddrin <= 16;
				4'd3: ramaddrin <= 20;
				4'd4: ramaddrin <= 24; 
				4'd5: ramaddrin <= 28;
				4'd6: ramaddrin <= 32;
				4'd7: ramaddrin <= 36;
				4'd8: ramaddrin <= 40;
				4'd9: ramaddrin <= 0;
				4'd10: ramaddrin <= 4;
				default: ramaddrin <= 0;
			 endcase

			 datavalid <= 1;
			 datarst <= 0;
			 datatail <= 0;
			 tapramaddrin <= 36;
		end	
		s23: begin
			 tready <= 0;

			 ramwenin <= 4'b0000;
			 ramenin <= 1;

			 case(ptr)
			 	4'd0: ramaddrin <= 4;
				4'd1: ramaddrin <= 8;
				4'd2: ramaddrin <= 12;
				4'd3: ramaddrin <= 16;
				4'd4: ramaddrin <= 20; 
				4'd5: ramaddrin <= 24;
				4'd6: ramaddrin <= 28;
				4'd7: ramaddrin <= 32;
				4'd8: ramaddrin <= 36;
				4'd9: ramaddrin <= 40;
				4'd10: ramaddrin <= 0;
				default: ramaddrin <= 0;
			 endcase

			 datavalid <= 1;
			 datarst <= 0;
			 datatail <= 0;
			 tapramaddrin <= 40;
		end												
		s24: begin
			 tready <= 0;

			 ramdatain <= 0;
			 ramaddrin <= 0;
			 ramenin <= 1;	

			 datavalid <= 1;
			 datarst <= 0;
			 datatail <= 1;
			 ptr <= (ptr==10)?0:ptr+1;
		end
		s25:  begin 
		     tready <= 0;

			 datavalid <= 0;
			 datarst <= 0;
			 datatail <= 0 ;

			 datalast <= 1;
		end
		default: begin
			 tready <= 0;

			 ramwenin <= 4'b0000;
		 	 ramdatain <= 0;
		 	 ramaddrin <= 0;
		 	 ramenin <= 0;

		 	 datavalid <= 0;
		 	 datarst <= 0;
			 datatail <= 0;
		end				 			
		endcase
end

assign ss_tready = tready;

assign data_WE = ramwenin;
assign data_EN = ramenin;
assign data_Di = ramdatain;
assign data_A = ramaddrin;

assign valid = datavalid;
assign rst = datarst;
assign tail = datatail;
assign last = datalast && datatail;
assign tap_addr = tapramaddrin;


endmodule 
