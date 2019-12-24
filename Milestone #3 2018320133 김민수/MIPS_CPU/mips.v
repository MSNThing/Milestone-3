`timescale 1ns/1ps
`define mydelay 1

//--------------------------------------------------------------
// mips.v
// David_Harris@hmc.edu and Sarah_Harris@hmc.edu 23 October 2005
// Single-cycle MIPS processor
//--------------------------------------------------------------

// single-cycle MIPS processor
module mips(input         clk, reset,
            output [31:0] pc,
            input  [31:0] instr,
            output        memwrite,
            output [31:0] memaddr,
            output [31:0] memwritedata,
            input  [31:0] memreaddata);

  wire        isjal, isjr, signext, shiftl16, memtoreg, branch;
  wire        pcsrc, zero;
  wire        alusrc, regdst, regwrite, jump;
  wire [3:0]  alucontrol;

  // Instantiate Controller
  controller c(
    .op         (instr[31:26]), 
		.funct      (instr[5:0]), 
		.zero       (zero),
    .isjal      (isjal),
    .isjr       (isjr),
		.signext    (signext),
		.shiftl16   (shiftl16),
		.memtoreg   (memtoreg),
		.memwrite   (memwrite),
		.pcsrc      (pcsrc),
		.alusrc     (alusrc),
		.regdst     (regdst),
		.regwrite   (regwrite),
		.jump       (jump),
		.alucontrol (alucontrol));

  // Instantiate Datapath
  datapath dp(
    .clk        (clk),
    .reset      (reset),
    .isjal      (isjal),
    .isjr       (isjr),
    .signext    (signext),
    .shiftl16   (shiftl16),
    .memtoreg   (memtoreg),
    .pcsrc      (pcsrc),
    .alusrc     (alusrc),
    .regdst     (regdst),
    .regwrite   (regwrite),
    .jump       (jump),
    .alucontrol (alucontrol),
    .zero       (zero),
    .pc         (pc),
    .instr      (instr),
    .aluout     (memaddr), 
    .writedata  (memwritedata),
    .readdata   (memreaddata));

endmodule

module controller(input  [5:0] op, funct,
                  input        zero,
                  output       isjal,
                  output       isjr,
                  output       signext,
                  output       shiftl16,
                  output       memtoreg, memwrite,
                  output       pcsrc, alusrc,
                  output       regdst, regwrite,
                  output       jump,
                  output [3:0] alucontrol);

  wire [1:0] aluop;
  wire       branch;
  wire       reversezero;

  maindec md(
    .op          (op),
    .isjal       (isjal),
    .reversezero (reversezero),
    .signext     (signext),
    .shiftl16    (shiftl16),
    .memtoreg    (memtoreg),
    .memwrite    (memwrite),
    .branch      (branch),
    .alusrc      (alusrc),
    .regdst      (regdst),
    .regwrite    (regwrite),
    .jump        (jump),
    .aluop       (aluop));

  aludec ad( 
    .funct      (funct),
    .aluop      (aluop), 
    .alucontrol (alucontrol));

  assign pcsrc = branch & (zero ^ reversezero);
  assign isjr = (funct[5:0] == 6'b001000) && (op[5:0] == 6'b000000);

endmodule


module maindec(input  [5:0] op,
               output       isjal,
               output       reversezero,
               output       signext,
               output       shiftl16,
               output       memtoreg, memwrite,
               output       branch, alusrc,
               output       regdst, regwrite,
               output       jump,
               output [1:0] aluop);

  reg [12:0] controls;

  assign {isjal, reversezero, signext, shiftl16, regwrite, regdst, alusrc, branch, memwrite,
          memtoreg, jump, aluop} = controls;

  always @(*)
    case(op)
      6'b000000: controls <= #`mydelay 13'b0000110000011; // Rtype
      6'b100011: controls <= #`mydelay 13'b0010101001000; // LW
      6'b101011: controls <= #`mydelay 13'b0010001010000; // SW
      6'b000100: controls <= #`mydelay 13'b0010000100001; // BEQ (signext, branch, aluop)
      6'b000101: controls <= #`mydelay 13'b0110000100001; // BNE (signext, aluop)
      6'b001000, 
      6'b001001: controls <= #`mydelay 13'b0010101000000; // ADDI, ADDIU: only difference is exception
      6'b001101: controls <= #`mydelay 13'b0000101000010; // ORI
      6'b001111: controls <= #`mydelay 13'b0001101000000; // LUI
      6'b000010: controls <= #`mydelay 13'b0000000000100; // J
      6'b000011: controls <= #`mydelay 13'b1000100000100; // JAL
      default:   controls <= #`mydelay 13'bxxxxxxxxxxxxx; // ???
    endcase

endmodule

module aludec(input      [5:0] funct,
              input      [1:0] aluop,
              output reg [3:0] alucontrol);

  always @(*)
    case(aluop)
      2'b00: alucontrol <= #`mydelay 4'b0010;  // add
      2'b01: alucontrol <= #`mydelay 4'b1010;  // sub
      2'b10: alucontrol <= #`mydelay 4'b0001;  // or
      default: case(funct)          // RTYPE
          6'b100000,
          6'b100001: alucontrol <= #`mydelay 4'b0010; // ADD, ADDU: only difference is exception
          6'b100010,
          6'b100011: alucontrol <= #`mydelay 4'b1010; // SUB, SUBU: only difference is exception
          6'b100100: alucontrol <= #`mydelay 4'b0000; // AND
          6'b100101: alucontrol <= #`mydelay 4'b0001; // OR
          6'b101010: alucontrol <= #`mydelay 4'b1011; // SLT
          6'b101011: alucontrol <= #`mydelay 4'b1100; // SLTU
          default:   alucontrol <= #`mydelay 4'bxxx; // ???
        endcase
    endcase
    
endmodule

module datapath(input         clk, reset,
                input         isjal,
                input         isjr,
                input         signext,
                input         shiftl16,
                input         memtoreg, pcsrc,
                input         alusrc, regdst,
                input         regwrite, jump,
                input  [3:0]  alucontrol,
                output        zero,
                output [31:0] pc,
                input  [31:0] instr,
                output [31:0] aluout, writedata,
                input  [31:0] readdata);

  wire [4:0]  writereg;
  wire [31:0] pcnext, pcnextbr, pcplus4, pcbranch;
  wire [31:0] signimm, signimmsh, shiftedimm;
  wire [31:0] srca, srcb;
  wire [31:0] result;
  wire [31:0] resmux_result;
  wire [31:0] wrmux_result, jrmux_result;
  wire        shift;

  // next PC logic
  flopr #(32) pcreg(
    .clk   (clk),
    .reset (reset),
    .d     (jrmux_result),
    .q     (pc));

  adder pcadd1(
    .a (pc),
    .b (32'b100),
    .y (pcplus4));

  sl2 immsh(
    .a (signimm),
    .y (signimmsh));
				 
  adder pcadd2(
    .a (pcplus4),
    .b (signimmsh),
    .y (pcbranch));

  mux2 #(32) pcbrmux(
    .d0  (pcplus4),
    .d1  (pcbranch),
    .s   (pcsrc),
    .y   (pcnextbr));

  mux2 #(32) pcmux(
    .d0   (pcnextbr),
    .d1   ({pcplus4[31:28], instr[25:0], 2'b00}),
    .s    (jump),
    .y    (pcnext));

  // register file logic
  regfile rf(
    .clk     (clk),
    .we      (regwrite),
    .ra1     (instr[25:21]),
    .ra2     (instr[20:16]),
    .wa      (writereg),
    .wd      (result),
    .rd1     (srca),
    .rd2     (writedata));

  mux2 #(32) jrmux(
    .d0 (pcnext),
    .d1 (srca),
    .s  (isjr),
    .y  (jrmux_result)
  );

  mux2 #(5) wrmux(
    .d0  (instr[20:16]),
    .d1  (instr[15:11]),
    .s   (regdst),
    .y   (wrmux_result));

  mux2 #(5) jal_address(
    .d0 (wrmux_result),
    .d1 (5'b11111),
    .s  (isjal),
    .y  (writereg)
  );

  mux2 #(32) resmux(
    .d0 (aluout),
    .d1 (readdata),
    .s  (memtoreg),
    .y  (resmux_result));

  mux2 #(32) jal_value_mux(
    .d0 (resmux_result),
    .d1 (pcplus4),
    .s  (isjal),
    .y  (result)
  );

  sign_zero_ext sze(
    .a       (instr[15:0]),
    .signext (signext),
    .y       (signimm[31:0]));

  shift_left_16 sl16(
    .a         (signimm[31:0]),
    .shiftl16  (shiftl16),
    .y         (shiftedimm[31:0]));

  // ALU logic
  mux2 #(32) srcbmux(
    .d0 (writedata),
    .d1 (shiftedimm[31:0]),
    .s  (alusrc),
    .y  (srcb));

  alu alu(
    .a       (srca),
    .b       (srcb),
    .alucont (alucontrol),
    .result  (aluout),
    .zero    (zero));
    
endmodule
