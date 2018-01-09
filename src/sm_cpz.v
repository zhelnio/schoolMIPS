/*
 * schoolMIPS - small MIPS CPU for "Young Russian Chip Architects" 
 *              summer school ( yrca@googlegroups.com )
 *
 * originally based on Sarah L. Harris MIPS CPU 
 * 
 * Copyright(c) 2017 Stanislav Zhelnio 
 */ 

`define CP0_REG_NUM_COUNT   5'd9
`define CP0_REG_SEL_COUNT   3'd0
`define CP0_REG_NUM_COMPARE 5'd11
`define CP0_REG_SEL_COMPARE 3'd0
`define CP0_REG_NUM_STATUS  5'd12
`define CP0_REG_SEL_STATUS  3'd0
`define CP0_REG_NUM_CAUSE   5'd13
`define CP0_REG_SEL_CAUSE   3'd0
`define CP0_REG_NUM_EPC     5'd14
`define CP0_REG_SEL_EPC     3'd0

`define CP0_EXCCODE_INT     5'h00
`define CP0_EXCCODE_RI      5'h0a
`define CP0_EXCCODE_OV      5'h0c

module sm_cpz
(
    input         clk,
    input         rst_n,

    input  [31:0] cp0_PC,           // next PC addr
    output [31:0] cp0_EPC,          // the address at which processing resumes
                                    // after an exception has been serviced
    output [31:0] cp0_ExcHandler,   // Exception Handler Addr
    output        cp0_ExcRequest,   // request for Exception
    input         co0_ExcEret,      // return from Exception

    input  [ 4:0] cp0_regNum,       // cp0 register access num
    input  [ 2:0] cp0_regSel,       // cp0 register access sel
    output [31:0] cp0_regRD,        // cp0 register access Read Data
    input  [31:0] cp0_regWD,        // cp0 register access Write Data
    input         cp0_regWE,        // cp0 register access Write Enable

    input         cp0_ExcIP2,       // Hardware Interrupt 0
    input         cp0_ExcRI,        // Reserved Instruction exception
    input         cp0_ExcOv         // Arithmetic Overflow exception
);
    assign cp0_ExcHandler = `SM_CONFIG_EXCEPTION_HANDLER_ADDR;

    // CP0 Registers & Fields
    wire [31:0] cp0_Status;         // Status Register:
    wire [ 7:0] cp0_StatusIM;       //    [15:8] - Interrupt Mask
    wire        cp0_StatusEXL;      //    [   1] - Exception Level
    wire        cp0_StatusIE;       //    [   0] - Interrupt Enable
    wire [31:0] cp0_Cause;          // Cause Register:
    wire        cp0_CauseTI;        //    [  30] - Timer Interrupt
    wire        cp0_CauseDC;        //    [  27] - Disable Count Register
    wire [ 7:0] cp0_CauseIP;        //    [15:8] - Interrupt is pending
    wire [ 4:0] cp0_CauseExcCode;   //    [ 6:2] - Exception Code
    wire [31:0] cp0_Compare;        // Compare register
    wire [31:0] cp0_Count;          // Count register

    // ####################################################################
    // Registers read access

    assign cp0_Status = {   16'b0,
                            cp0_StatusIM, 
                            6'b0, 
                            cp0_StatusEXL, 
                            cp0_StatusIE 
                        };

    assign cp0_Cause  = {   1'b0, 
                            cp0_CauseTI, 
                            2'b0, 
                            cp0_CauseDC, 
                            11'b0, 
                            cp0_CauseIP, 
                            1'b0, 
                            cp0_CauseExcCode, 
                            2'b0 
                        };

    // select flags from register access interface
    wire cp0_Status_sel  =  (cp0_regNum == `CP0_REG_NUM_STATUS)
                         && (cp0_regSel == `CP0_REG_SEL_STATUS);
    wire cp0_Cause_sel   =  (cp0_regNum == `CP0_REG_NUM_CAUSE)
                         && (cp0_regSel == `CP0_REG_SEL_CAUSE);
    wire cp0_EPC_sel     =  (cp0_regNum == `CP0_REG_NUM_EPC)
                         && (cp0_regSel == `CP0_REG_SEL_EPC);
    wire cp0_Compare_sel =  (cp0_regNum == `CP0_REG_NUM_COMPARE)
                         && (cp0_regSel == `CP0_REG_SEL_COMPARE);
    wire cp0_Count_sel   =  (cp0_regNum == `CP0_REG_NUM_COUNT)
                         && (cp0_regSel == `CP0_REG_SEL_COUNT);

    assign cp0_regRD =  cp0_Compare_sel ? cp0_Compare : (
                        cp0_Count_sel   ? cp0_Count   : (
                        cp0_Status_sel  ? cp0_Status  : (
                        cp0_Cause_sel   ? cp0_Cause   : (
                        cp0_EPC_sel     ? cp0_EPC     : 32'b0 ))));

    // ####################################################################
    // Compare register

    wire        cp0_Compare_load  = cp0_Compare_sel & cp0_regWE;
    sm_register_we #(32) r_cp0_Compare(clk, rst_n, cp0_Compare_load, cp0_regWD, cp0_Compare);

    // ####################################################################
    // Count register

    wire        cp0_Count_load  = cp0_Count_sel  & cp0_regWE;
    wire [31:0] cp0_Count_new   = cp0_Count_load ? cp0_regWD : cp0_Count + 1;
    wire        cp0_Count_we    = cp0_Count_load | ~cp0_CauseDC;
    sm_register_we #(32) r_cp0_Count(clk, rst_n, cp0_Count_we, cp0_Count_new, cp0_Count);

    // ####################################################################
    // Status register

    // Register Write Enable
    wire cp0_Status_load = (cp0_regWE && cp0_Status_sel);

    // Interrupt Enable
    wire cp0_StatusIE_new = cp0_regWD [0];
    sm_register_we r_cp0_StatusIE(clk, rst_n, cp0_Status_load, cp0_StatusIE_new, cp0_StatusIE);
    
    // Interrupt Mask
    wire [ 7:0] cp0_StatusIM_new = cp0_regWD [15:8];
    sm_register_we #(8) r_cp0_StatusIM(clk, rst_n, cp0_Status_load, cp0_StatusIM_new, cp0_StatusIM);

    // Exception Level
    wire cp0_RequestForIrq = cp0_CauseIP && cp0_StatusIM;
    wire cp0_RequestForExc = cp0_RequestForIrq | cp0_ExcRI | cp0_ExcOv;
    wire cp0_StatusEXL_new = cp0_Status_load ? cp0_regWD [1] : (
                             co0_ExcEret     ? 1'b0          
                                             : cp0_StatusEXL | cp0_RequestForExc );
    sm_register_c  r_cp0_StatusEXL(clk, rst_n, cp0_StatusEXL_new, cp0_StatusEXL);
    
    // Exception Request Strobe (not register field)
    wire cp0_ExcRequest_new = cp0_RequestForExc & ~cp0_StatusEXL;
    sm_register_c  r_cp0_ExcRequest(clk, rst_n, cp0_ExcRequest_new, cp0_ExcRequest);

    // ####################################################################
    // Cause register

    // Register load
    wire cp0_Cause_load = (cp0_regWE && cp0_Cause_sel);

    // Disable Count Register
    wire cp0_CauseDC_next = cp0_regWD [27];
    sm_register_we r_cp0_CauseDC(clk, rst_n, cp0_Cause_load, cp0_CauseDC_next, cp0_CauseDC);

    // Timer Interrupt flag
    wire cp0_CauseTI_next = cp0_Compare_load ? 1'b0 :
                            cp0_CauseTI      ? 1'b1 :
                            cp0_StatusIE & ~cp0_CauseDC & (cp0_Compare == cp0_Count);
    sm_register_c r_cp0_CauseTI(clk, rst_n, cp0_CauseTI_next, cp0_CauseTI);

    // Interrupt is pending
    wire [ 7:0] cp0_CauseIP_next;
    assign cp0_CauseIP_next [1:0] = cp0_Cause_load ? cp0_regWD [9:8] : cp0_CauseIP [1:0];
    assign cp0_CauseIP_next [7:2] = { 
                                        cp0_CauseTI_next, 
                                        4'b0,
                                        cp0_CauseIP [2] | (cp0_StatusIE & cp0_ExcIP2)
                                    };
    sm_register_c #(8) r_cp0_CauseIP(clk, rst_n, cp0_CauseIP_next, cp0_CauseIP);

    // Exception Code
    wire [ 4:0] cp0_CauseExcCode_next = cp0_ExcRI ? `CP0_EXCCODE_RI : (
                                        cp0_ExcOv ? `CP0_EXCCODE_OV : `CP0_EXCCODE_INT );

    // ####################################################################
    // Exception Program Counter (EPC) Register

    wire cp0_EPC_we;
    sm_register_we #(32) r_cp0_epc(clk, rst_n, cp0_ExcRequest, cp0_PC, cp0_EPC);

endmodule