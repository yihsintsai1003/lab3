module fir_tap
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata, 
    input   wire                     axis_clk,
    input   wire                     axis_rst_n,

    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    output  wire                     tap_finish,

    input  wire                     output_finish
);

/*
AXI-lite:
Write channel:
    M(PS)->S(FIR):
        awvalid : Write address valid
        awaddr : Write address
        wvalid : Write valid
        wdata : Write data
    M(PS)<-S(FIR):
        awready : Write address ready
        wready : Write ready
Read channel:
    M(PS)->S(FIR):
        rready : Read ready
        arvalid : Read address valid
        araddr : Read address
    M(PS)<-S(FIR):
        arready : Read address ready
        rvalid : Read valid
        rdata : Read Data

SRAM:
FIR<-SRAM
    tap_Do

FIR->SRAM
    tap_WE
    tap_EN
    tap_Di
    tap_A

*/

reg [(pDATA_WIDTH-1):0]	mem[0:72];

always@(posedge axis_clk) begin	
	if(awvalid && wvalid) begin
		mem[awaddr] <= wdata;	
	end
	else begin
		mem[awaddr] <= mem[awaddr];
	end
end

reg [2:0] curr_state;
reg [2:0] next_state;

parameter s0   = 3'b000; // wait
parameter s1   = 3'b001; // write
parameter s2   = 3'b010; // read
parameter s3   = 3'b011; // finish
parameter s4   = 3'b100; 
parameter s5   = 3'b101;
parameter s6   = 3'b110;

always@(posedge axis_clk or negedge axis_rst_n)
	if (!axis_rst_n) curr_state <= s0;
	else        curr_state <= next_state;

always@(*)
	case(curr_state)
		s0:  next_state = (awvalid && wvalid)?s1:(rready && arvalid)?s2:s3;
		s1:  next_state = s0;
		s2:  next_state = s0;
        s3:  next_state = s4;
        s4:  next_state = (output_finish)?s5:s4;
        s5:  next_state = s6;
        s6:  next_state = s6;
        default: next_state = s0;
	endcase    

reg [3:0] we;
reg checkfinish;
wire [31:0] mem0;

always@(posedge axis_clk or negedge axis_rst_n) begin	
	if(!axis_rst_n) begin
        we <= 0;
		checkfinish <= 0;
	end	
	else 
		case(curr_state)
		s0: begin
            we <= 0; 
            checkfinish <= 0; 
		end
		s1: begin
            we <= 0; 
            checkfinish <= 0; 
		end
		s2: begin
            we <= 4'b1111;
            checkfinish <= 0;
		end
		s3: begin
            we <= 0;
            checkfinish <= 1;		 
		end
        s4: begin
            we <= 0;
            checkfinish <= 1;
            mem[0] <= 32'h0;		 
		end
        s5: begin
            mem[0] <= 32'h2;		 
		end	
        s6: begin
            mem[0] <= 32'h4;		 
		end
        default: begin
            we <= 0; 
            checkfinish <= 0; 
		end			
		endcase
end

assign awready = awvalid && wvalid;
assign wready = awvalid && wvalid;

assign rdata = (rready && arvalid)?mem[araddr]:0;
assign arready = rready && arvalid;
assign rvalid = rready && arvalid;

assign tap_WE = (rready && arvalid)?4'b1111:0;
assign tap_EN = rready && arvalid;
assign tap_Di = (rready && arvalid)?mem[araddr]:0;
assign tap_A = (rready && arvalid)?{araddr[6],araddr[4],araddr[3],araddr[2]}<<2:0;
assign tap_finish = checkfinish;

assign mem0 = mem[0];

endmodule 
