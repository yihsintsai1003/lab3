module fir 
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

    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready,

    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast,  
    
    // bram for tap RAM
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);
    wire                     tap_finish;
    wire                     valid;
    wire                     rst;
    wire                     tail;      
    wire                     last;

    fir_data d1(
        .data_WE(data_WE),
        .data_EN(data_EN),
        .data_Di(data_Di),
        .data_A(data_A),
        .tap_finish(tap_finish),
        .valid(valid),
        .rst(rst),
        .tail(tail),
        .last(last),

        .ss_tvalid(ss_tvalid),
        .ss_tdata(ss_tdata),
        .ss_tlast(ss_tlast),
        .ss_tready(ss_tready),
        .axis_clk(axis_clk),
        .axis_rst_n(axis_rst_n)
);

wire [(pADDR_WIDTH-1):0] tapaddr;
wire tapen;
wire [3:0] tapwe;

assign tap_A = (!tap_finish)?tapaddr:data_A;
assign tap_EN = (!tap_finish)?tapen:data_EN;
assign tap_WE = (!tap_finish)?tapwe:0;

    fir_tap t1(
        .awready(awready),
        .wready(wready),
        .awvalid(awvalid),
        .awaddr(awaddr),
        .wvalid(wvalid),
        .wdata(wdata),
        .arready(arready),
        .rready(rready),
        .arvalid(arvalid),
        .araddr(araddr),
        .rvalid(rvalid),
        .rdata(rdata),
        .axis_clk(axis_clk),
        .axis_rst_n(axis_rst_n),

        // ram for tap
        .tapwe(tapwe),
        .tapen(tapen),
        .tap_Di(tap_Di),
        .tapaddr(tapaddr),
        .tap_finish(tap_finish),

        .sm_tlast(sm_tlast)

);

    fir_output o1(
        .tap_Do(tap_Do),
        .data_Do(data_Do),
        .valid(valid),
        .rst(rst),
        .tail(tail),
        .last(last),

        .sm_tready(sm_tready),
        .sm_tvalid(sm_tvalid),
        .sm_tdata(sm_tdata),
        .sm_tlast(sm_tlast),

        .axis_clk(axis_clk),
        .axis_rst_n(axis_rst_n)
);

endmodule
