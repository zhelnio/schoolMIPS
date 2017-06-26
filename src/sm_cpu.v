/*
 * schoolMIPS - small MIPS CPU for "Young Russian Chip Architects" 
 *              summer school ( yrca@googlegroups.com )
 *
 * originally based on Sarah L. Harris MIPS CPU 
 * 
 * Copyright(c) 2017 Stanislav Zhelnio 
 *                   Alexander Romanov 
 */ 

module sm_cpu
(
    input           clk,
    input           rst_n,
    input   [ 4:0]  regAddr,
    output  [31:0]  regData
);
    //control wires
    wire        pcSrc;
    wire        regDst;
    wire        regWrite;
    wire        aluSrc;
    wire        aluZero;
    wire [ 2:0] aluControl;

    //program counter
    wire [31:0] pc;
    wire [31:0] pcBranch;
    wire [31:0] pcNext  = pc + 1;
    wire [31:0] pc_new   = ~pcSrc ? pcNext : pcBranch;
    sm_register r_pc(clk ,rst_n, pc_new, pc);

    //program memory
    reg  [31:0] rom [61:0];
    wire [31:0] instr = rom [pc];

    //debug register access
    wire [31:0] rd0;
    assign regData = (regAddr != 0) ? rd0 : pc;

    //register file
    wire [ 4:0] a3  = regDst ? instr[15:11] : instr[20:16];
    wire [31:0] rd1;
    wire [31:0] rd2;
    wire [31:0] wd3;

    sm_register_file rf
    (
        .clk        ( clk          ),
        .a0         ( regAddr      ),
        .a1         ( instr[25:21] ),
        .a2         ( instr[20:16] ),
        .a3         ( a3           ),
        .rd0        ( rd0          ),
        .rd1        ( rd1          ),
        .rd2        ( rd2          ),
        .wd3        ( wd3          ),
        .we3        ( regWrite     )
    );

    //sign extension
    wire [31:0] signImm = { {16 { instr[15] }}, instr[15:0] };
    assign pcBranch = pcNext + signImm;

    //alu
    wire [31:0] srcB = aluSrc ? signImm : rd2;

    sm_alu alu
    (
        .srcA       ( rd1          ),
        .srcB       ( srcB         ),
        .oper       ( aluControl   ),
        .zero       ( aluZero      ),
        .result     ( wd3          ) 
    );

    //control
    sm_control sm_control
    (
        .cmdOper    ( instr[31:26] ),
        .cmdFunk    ( instr[ 5:0 ] ),
        .aluZero    ( aluZero      ),
        .pcSrc      ( pcSrc        ), 
        .regDst     ( regDst       ), 
        .regWrite   ( regWrite     ), 
        .aluSrc     ( aluSrc       ),
        .aluControl ( aluControl   )
    );

endmodule

module sm_control
(
    input  [5:0] cmdOper,
    input  [5:0] cmdFunk,
    input        aluZero,
    output       pcSrc, 
    output       regDst, 
    output       regWrite, 
    output       aluSrc,
    output [2:0] aluControl
);
    wire         branch;
    assign pcSrc = branch & aluZero;

    reg    [6:0] conf;
    assign { branch, regDst, regWrite, aluSrc, aluControl } = conf;

    localparam  C_SPEC  = 6'b000000,
                C_ADDIU = 6'b001001,
                C_BGEZ  = 6'b000100;

    localparam  F_ADDU  = 6'b100001,
                F_OR    = 6'b100101,
                F_ANY   = 6'b??????;

    always @ (*) begin
        casez( {cmdOper,cmdFunk} )
            default             : conf = 7'b0;
            { C_SPEC,  F_ADDU } : conf = 7'b0110000;
            { C_SPEC,  F_OR   } : conf = 7'b0110001;
            { C_ADDIU, F_ANY  } : conf = 7'b0011000;
            { C_BGEZ,  F_ANY  } : conf = 7'b1000000;
        endcase
    end
endmodule


module sm_alu
(
    input  [31:0] srcA,
    input  [31:0] srcB,
    input  [ 2:0] oper,
    output        zero,
    output reg [31:0] result 
);
    localparam ALU_ADD = 3'b000,
               ALU_OR  = 3'b001;

    always @ (*) begin
        case (oper)
            default : result = srcA + srcB;
            ALU_ADD : result = srcA + srcB;
            ALU_OR  : result = srcA | srcB;
        endcase
    end

    assign zero   = (result == 0);
endmodule

module sm_register_file
(
    input         clk,
    input  [ 4:0] a0,
    input  [ 4:0] a1,
    input  [ 4:0] a2,
    input  [ 4:0] a3,
    output [31:0] rd0,
    output [31:0] rd1,
    output [31:0] rd2,
    input  [31:0] wd3,
    input         we3
);
    reg [31:0] rf [31:0];

    assign rd0 = (a0 != 0) ? rf [a0] : 32'b0;
    assign rd1 = (a1 != 0) ? rf [a1] : 32'b0;
    assign rd2 = (a2 != 0) ? rf [a2] : 32'b0;

    always @ (posedge clk)
        if(we3) rf [a3] <= wd3;
endmodule