module fir_output
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    input   wire                     axis_clk,
    input   wire                     axis_rst_n,
    input   wire [(pDATA_WIDTH-1):0] tap,
    input   wire [(pDATA_WIDTH-1):0] data,
	input   wire					 valid,
	input   wire					 rst,
    input   wire					 tail,
    input   wire					 last,

    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast
);

/*
AXI-stream:
   M(PS)->S(FIR):
        sm_tready

    M(PS)<-S(FIR):
        sm_tdata
        sm_tlast
		sm_tvalid

*/

reg [(pDATA_WIDTH-1):0] outputdata;
reg outputvalid;
reg outputlast;

always@(posedge axis_clk)
	if ( (!axis_rst_n) || rst) 
        outputdata <= 0;
	else begin
        if(sm_tready && valid) 
            outputdata <= tap*data + outputdata;    
        else outputdata <= outputdata;
    end

always@(posedge axis_clk)
    if(tail) begin
        if(last) begin
            outputvalid <= 1;
            outputlast <= 1;
            end
            else begin
            outputvalid <= 1;
            outputlast <= 0;
            end
        end
    else begin
        outputvalid <= 0;
        outputlast <= 0;
    end    

assign sm_tvalid = outputvalid;
assign sm_tdata = outputdata;
assign sm_tlast = outputlast;

endmodule 
