`timescale 1 ns / 1 ps 

module backend_tb();

reg ipacket_req;
wire ipacket_ack;
reg [7:0] ipacket_pc;
reg [3:0] pc;
reg rst_n;
reg[7:0] instmem[0:15];
wire [7:0] ipacket_inst = instmem[pc];
integer idx;

reg dummy_clk;
// the problem is that there is no new events!!!

initial begin
  instmem[0] = 8'd0;// 15
  instmem[1] = 8'b10_00_00_00; // 0 SET R0 = 0,
  instmem[2] = 8'b10_00_01_01; // 1 SET R1 = 1,
  instmem[3] = 8'b10_00_10_10; // 2 SET R2 = 2,
  instmem[4] = 8'b10_00_11_11; // 3 SET R3 = 3,
  instmem[5] = 8'b01_10_11_00; // 4 ADD R0 = R2 + R3 , R0 = 5
  instmem[6] = 8'b01_00_10_00; // 5 ADD R0 = R0 + R2, R0 = 7
  instmem[7] = 8'b01_10_00_10; // 6 ADD R2 = R2 + R0, R2 = 9
  instmem[8] = 8'b11_10_00_10; // 7 NAND R2 = ~( R2 & R0 ), R2 = 11111110
  instmem[9] = 8'b00_01_01_10; // 8 NOP
  instmem[10] = 8'b00_11_10_00; // 9 NOP
  instmem[11] = 8'b11_01_01_01; // 10 R1 = ~ (R1 & R1), R1 = 11111110
  instmem[12] = 8'b01_01_10_00; // 11 ADD R0 = R1 + R2 = 0b01111100
  instmem[13] = 8'd0; // 12
  instmem[14] = 8'd0; // 13
  instmem[15] = 8'd0; // 14

  $dumpfile("wave.vcd");
  $dumpvars;

      
  rst_n = 0;
  pc = 0;
  ipacket_pc = 0;
  ipacket_req = 0;
  dummy_clk = 0;
  # 10
  rst_n = 1;
  #1 
   ipacket_req <= 1;
  // forever #5 dummy_clk = ~ dummy_clk;
end

always @(negedge ipacket_ack) begin
  if(rst_n) begin
    pc <= #1 (pc + 1);
    ipacket_req <= #2 1;
  end
end

always @(posedge ipacket_ack) begin
  ipacket_req = #2 0;
end



wire [7:0] r0,r1,r2,r3;

backend dut(
  .ipacket_req(ipacket_req),
  .ipacket_ack(ipacket_ack),
  .ipacket_pc(ipacket_pc),
  .ipacket_inst(ipacket_inst),
  
  .rst_n(rst_n),
  .debug_pin_r0(r0),
  .debug_pin_r1(r1),
  .debug_pin_r2(r2),
  .debug_pin_r3(r3)
);



always @(pc) begin
  $display ("pc : %x", pc);
  if(pc == 15)
    $finish;
end

endmodule
