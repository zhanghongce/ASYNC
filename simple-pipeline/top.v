`timescale 1 ns / 1 ps 
// Let's assume we have 3 stages

// A simple async pipeline
// that can only do add/sub/set/nand (by bit)
// with only 4 registers
// for simplicity, we even make the instruction part
// as input
// 2-bit op, 2-bit rs1, 2-bit rs2, 2-bit rd : ADD, NAND
//   ADD rs1 + rs2 --> rd
//  NAND ~( rs1 & rs2 ) --> rd

// NOP 00xxxxxx 

// 2-bit  : 2-bit op (10),   4-bit immediate (0~15),  2-bit rd


// -- IF --|-- ID --|-- EX
//

`define  OP_SET 2'b10
`define  OP_ADD 2'b01
`define  OP_NOP 2'b00
`define  OP_NAND 2'b11

module backend(
	input ipacket_req,
	output ipacket_ack,
	input [7:0] ipacket_inst,
	input [7:0] ipacket_pc,

	input rst_n,

	output [7:0] debug_pin_r0,
	output [7:0] debug_pin_r1,
	output [7:0] debug_pin_r2,
	output [7:0] debug_pin_r3
	);

//          ------------
// ---rin-->|          |---rout-->
// <--ain---|          |<--aout---
//          ------------

wire ifetch_lt;
wire ifetch_decode_req;
wire ifetch_decode_ack;
pipeline_stage_control ifetch_control (
  .rin(ipacket_req),    
  .rout(ifetch_decode_req),   
  .ain(ipacket_ack),
  .aout(ifetch_decode_ack),
  .lt(ifetch_lt),
  .rst_n(rst_n)
	);

wire [7:0] inst;
dlatch
  	# ( .W(8) ) 
ifetch_latch(
	.din(ipacket_inst),
	.dout(inst),
	.lt(ifetch_lt)
);



wire decode_lt;
wire decode_ifetch_ack;
wire decode_exec_req;
wire exec_decode_ack;

assign ifetch_decode_ack = decode_ifetch_ack; // & can_issue
wire exec_req_in = decode_exec_req ; //  & can_issue


// --------------------------------------------------------------------


wire [1:0] ex_op;
wire [1:0] ex_rd;
wire [7:0] ex_rs1_val;
wire [7:0] ex_rs2_val;
wire [3:0] ex_immd;
wire       ex_rd_en;

wire [1:0] op = inst[7:6];
wire [1:0] rs1= inst[5:4];
wire [1:0] rs2= inst[3:2];
wire [1:0] rd = inst[1:0];
wire [3:0] immd = inst[5:2];

reg [7:0] registers[3:0];  // R


wire [7:0] rs1_val =    rs1 == 2'd0 ? registers[0] :
                        rs1 == 2'd1 ? registers[1] :
                        rs1 == 2'd2 ? registers[2] :
                            registers[3];

wire [7:0] rs2_val =    rs2 == 2'd0 ? registers[0] :
                        rs2 == 2'd1 ? registers[1] :
                        rs2 == 2'd2 ? registers[2] :
                            registers[3];

wire rd_en = op != `OP_NOP;




pipeline_stage_control decode_control (
  .rin(ifetch_decode_req),    
  .rout(decode_exec_req),   
  .ain(decode_ifetch_ack),
  .aout(exec_decode_ack),
  .lt(decode_lt),
  .rst_n(rst_n)
	);

dlatch
  	# ( .W(25) ) 
decode_latch(
	.din({op, rd, rd_en, rs1_val, rs2_val, immd}),  // 2 + 2 + 8 + 8 + 4
	.dout( {ex_op, ex_rd, ex_rd_en, ex_rs1_val, ex_rs2_val, ex_immd} ),
	.lt(decode_lt)
);


// --------------------------------------------------------------------




wire exec_lt;
wire exec_rout;
wire #1 exec_aout = exec_rout; // in reality, there will be delays
pipeline_stage_control exec_control (
  .rin(exec_req_in),    
  .rout(exec_rout),   
  .ain(exec_decode_ack),
  .aout(exec_aout),
  .lt(exec_lt),
  .rst_n(rst_n)
	);

wire [7:0] rd_val = 
	ex_op == `OP_ADD ? ex_rs1_val + ex_rs2_val :
    ex_op == `OP_NAND ? ~( ex_rs1_val & ex_rs2_val ) :
    ex_op == `OP_SET ? ex_immd :
    8'bxxxxxxxx;


always @(negedge exec_lt) begin
	if (ex_rd_en) begin
		registers[ex_rd] <= rd_val;
		$display("@%t, write r%d = %d", $time, ex_rd, rd_val);
	end
end

assign debug_pin_r0 = registers[0];
assign debug_pin_r1 = registers[1];
assign debug_pin_r2 = registers[2];
assign debug_pin_r3 = registers[3];


endmodule
// write rd_ex -> 

`timescale 1 ns / 1 ps 
module pipeline_stage_control(input rin, output rout, input aout, output ain, output lt, input rst_n);
    wire B;

    assign #1 lt = (~rst_n) | ( B | lt & ((aout | B | ~rin)) );
    assign #1 ain = (rst_n & ( ~lt | ain & ((~lt | rin)) ));
    assign #1 rout = (rst_n & ( ~lt | rout & ((~aout | ~lt))) );
    assign #1 B = (rst_n & ( ain & rout | B & ((ain | rout)) ));

    // signal values at the initial state:
    // lt !ain !rout !B !rin !aout
endmodule

`timescale 1 ns / 1 ps 
module dlatch(din, dout, lt);
parameter W = 8;
input [W-1:0] din;
output reg [W-1:0] dout;
input lt;
	
	always @(*) begin
		if(!lt)
			dout = din;
	end

endmodule