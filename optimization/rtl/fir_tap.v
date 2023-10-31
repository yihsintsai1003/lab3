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

    output  wire [3:0]               tapwe,
    output  wire                     tapen,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tapaddr,
    output  wire                     tap_finish,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    input  wire                      sm_tlast
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

reg [(pDATA_WIDTH-1):0]	mem;

always@(posedge axis_clk) begin	
	if(awvalid && wvalid) begin
		mem <= wdata;	
	end
	else begin
		mem <= mem;
	end
end

reg [2:0] curr_state;
reg [2:0] next_state;

parameter s0   = 3'b000; // wait
parameter s1   = 3'b001; // write
parameter s2   = 3'b010; // read
parameter s3   = 3'b011; // read2 
parameter s4   = 3'b100; // finish
parameter s5   = 3'b101; // ap_start = 0
parameter s6   = 3'b110; // ap_done
parameter s7   = 3'b111; // ap_idle

reg last;
reg checkfinish;
reg writefinish;
reg readfinish;
reg readvalid;

always@(posedge axis_clk or negedge axis_rst_n)
	if (!axis_rst_n) curr_state <= s0;
	else        curr_state <= next_state;

always@(*)
	case(curr_state)
		s0:  next_state = (readvalid && wvalid)?s4:(awvalid && wvalid)?s1:(rready && arvalid)?s2:s0;
		s1:  next_state = s0;
		s2:  next_state = s3;
        s3:  next_state = (awvalid && arvalid)?s4:s0;
        s4:  next_state = (sm_tlast)?s5:s4;
        s5:  next_state = s6;
        s6:  next_state = s6;
        default: next_state = s0;
	endcase   

always@(posedge axis_clk or negedge axis_rst_n) begin	
	if(!axis_rst_n) begin
		checkfinish <= 0;
        writefinish <= 0;
        readfinish <= 0;
        last <= 0;
        readvalid <= 0;
	end	
	else 
		case(curr_state)
		s0: begin
            checkfinish <= 0;
            readvalid <= 0;

		end
		s1: begin
            checkfinish <= 0;
            writefinish <= 1;
		end
		s2: begin
            checkfinish <= 0;
            writefinish <= 0; 
            readfinish <= 1;
            readvalid <= 0;

		end
		s3: begin
            checkfinish <= 0;
            writefinish <= 0; 
            readfinish <= 1;
            readvalid <= 1;
		end
		s4: begin
            checkfinish <= 1;
            readfinish <= 0;
            mem <= 32'h0;	 
		end
        s5: begin
            checkfinish <= 1;
            mem <= 32'h2;		 
		end
        s6: begin
            mem <= 32'h4;
            last <= 1;
		end	
        s7: begin
            mem <= 32'h4;
            last <= 1;		 
		end
        default: begin 
            checkfinish <= 0; 
		end			
		endcase
end


assign awready = awvalid && wvalid;
assign wready = awvalid && wvalid;


assign rdata = (checkfinish)?mem:(rready)?tap_Do:0;
assign arready = rready && arvalid;
assign rvalid = (!checkfinish)?readvalid:rready && arvalid;

assign tapwe = (awvalid && wvalid)?4'b1111:0;
assign tapen = writefinish||readfinish;
assign tap_Di = (awvalid && wvalid)&&(!readfinish)?wdata:0;
assign tapaddr = (awvalid && wvalid)?{awaddr[6],awaddr[4],awaddr[3],awaddr[2]}<<2:{araddr[6],araddr[4],araddr[3],araddr[2]}<<2;
assign tap_finish = checkfinish;

endmodule 
