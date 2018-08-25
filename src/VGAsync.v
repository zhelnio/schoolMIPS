/*
 * schoolMIPS - small MIPS CPU for "Young Russian Chip Architects" 
 *              summer school ( yrca@googlegroups.com )
 *
 * VGA_debug_screen_top
 * 
 * Copyright(c) 2017-2018 Stanislav Zhelnio
 *                        Barsukov Dmitriy
 *                        Vlasov Dmitriy
 */

    //  VGA constants 640*480
    //  Horizontal timing
    `define     HVA             640     //Visible area
    `define     HFP             16      //Front porch
    `define     HSP             96      //Sync pulse
    `define     HBP             48      //Back porch
    `define     HWL             800     //Whole line
    //  Vertical timing
    `define     VVA             480     //Visible area
    `define     VFP             10      //Front porch
    `define     VSP             2       //Sync pulse
    `define     VBP             33      //Back porch
    `define     VWF             525     //Whole frame
    //  Reg pos
    `define     REG_VALUE_POS   6 // X position of registers values
    `define     REG_VALUE_WIDTH 8 // X position of registers values

module VGAdebugScreen
(
    input               clk,        // VGA clock 108 MHz
    input               rst_n,
    input               en,
    output      [4:0]   regAddr,    // Used to request registers value from SchoolMIPS core
    input       [31:0]  regData,    // Register value from SchoolMIPS
    input               reset,      // positive reset
    input       [11:0]  bgColor,    // Background color in format: RRRRGGGGBBBB, MSB first
    input       [11:0]  fgColor,    // Foreground color in format: RRRRGGGGBBBB, MSB first
    output      [11:0]  RGBsig,     // Output VGA video signal in format: RRRRGGGGBBBB, MSB first
    output              hsync,      // VGA hsync
    output              vsync       // VGA vsync
);

    wire    [11:0]  pixelLine;          // pixel Y coordinate
    wire    [11:0]  pixelColumn;        // pixel X coordinate
    wire    [7:0]   symbolCode;         // Current symbol code
    wire            onoff;              // Is pixel on or off
    wire    [12:0]  RGB;
    wire    [7:0]   symbolCodeFromConv; // Symbol code from bin2ascii converter
    wire    [7:0]   symbolCodeFromROM;  // Symbol code from displayROM
    wire    [3:0]   tetrad;             // 4-byte value to be converted to 0...9, A...F symbol
    wire    [2:0]   PixX;
    wire    [3:0]   PixY;
    wire    [11:0]  SymY;
    wire    [11:0]  SymX;

    assign tetrad = regData >> ( 28 - ( SymX - `REG_VALUE_POS ) * 4 ) ;

    VGAsync vgasync_0
    (
        .clk    ( clk           ),
        .rst_n  ( rst_n         ),
        .en     ( en            ),
        .hsync  ( hsync         ),
        .vsync  ( vsync         ),
        .line   ( pixelLine     ),
        .column ( pixelColumn   ),
        .PixX   ( PixX          ),
        .PixY   ( PixY          ),
        .SymY   ( SymY          ),
        .SymX   ( SymX          ),
        .RegAddr(   regAddr     )
    );

    fontROM font_0
    (
        .clk        ( clk           ),
        .x          ( PixX          ),
        .y          ( PixY          ),
        .symbolCode ( symbolCode    ),
        .onoff      ( onoff         )
    );

    displayROM dispROM_0
    (
        .symbolLine     ( SymY              ),
        .symbolColumn   ( SymX              ),
        .symbolCode     ( symbolCodeFromROM )
    );

    Bin2ASCII bin2asciiconv_0
    (
        .tetrad     ( tetrad                ),
        .symbolCode ( symbolCodeFromConv    )
    );

    assign  RGBsig = ( pixelLine < 481 && pixelColumn < 641 ) ? RGB : 12'h000 ;
    assign  RGB = onoff ? fgColor : bgColor ;

    assign symbolCode = ( SymX >= `REG_VALUE_POS && SymX < `REG_VALUE_POS + `REG_VALUE_WIDTH ) ?
                        symbolCodeFromConv :
                        symbolCodeFromROM ;
    
endmodule


module Bin2ASCII
(
    input       [3:0]   tetrad,
    output      [7:0]   symbolCode
);
    assign symbolCode = ( tetrad < 10 ) ? 
                        tetrad + 8'h30 :       // 0...9
                        tetrad - 10 + 8'h41 ;  // A...F
endmodule


module displayROM
(
    input   [11:0]  symbolLine,    // 0...31
    input   [11:0]  symbolColumn,  // 0...79
    output  [7:0]   symbolCode
);

    reg [7:0] dispROM [2560-1:0];

    assign symbolCode = dispROM[symbolLine + symbolColumn];

    initial
    begin
        $readmemh("displayROM.hex", dispROM);
    end
endmodule

module fontROM
(
    input               clk,
    input       [7:0]   symbolCode, // ASCII symbol code
    input       [2:0]   x,          // X position of pixel in the symbol
    input       [3:0]   y,          // Y position of pixel in the symbol
    output reg          onoff       // Is pixel on or off
);
    
    reg [7:0] glyphROM [4096-1:0];

    always @(posedge clk)
        onoff <= glyphROM[ { symbolCode , y } ][x] ;    //[7-x] ; for testing and Xilinx
                                                        //[x]for Altera

    initial
    begin
        $readmemh("displayfont.hex", glyphROM,4095,0);  //4095,0) ; for Altera
                                                        //) ; for testing and Xilinx
    end
endmodule

module VGA_top
(
    input               clk,
    input               rst_n,
    output              hsync,
    output              vsync,
    output  [3:0]       R,
    output  [3:0]       G,
    output  [3:0]       B,
    output              buzz,
    output  [4:0]       regAddr,
    input   [31:0]      regData
);
    assign buzz = 0 ;

    wire [11:0] line ;

    wire en;
    sm_register en_r(clk, rst_n, ~en, en );

    VGAdebugScreen VGAdebugScreen_0
    (
        .clk        ( clk       ),  // VGA clock 108 MHz
        .rst_n      ( rst_n     ),
        .en         ( en        ),
        .regAddr    ( regAddr   ),    // Used to request registers value from SchoolMIPS core
        .regData    ( regData   ),    // Register value from SchoolMIPS
        .bgColor    ( 12'hFF0   ),    // Background color in format: RRRRGGGGBBBB, MSB first
        .fgColor    ( 12'h00F   ),    // Foreground color in format: RRRRGGGGBBBB, MSB first
        .RGBsig     ( {R,G,B}   ),     // Output VGA video signal in format: RRRRGGGGBBBB, MSB first
        .hsync      ( hsync     ),      // VGA hsync
        .vsync      ( vsync     )       // VGA vsync
    );

endmodule

module VGAsync
(
    input               clk,        // VGA clock
    input               rst_n,        // positive reset
    input               en,
    output reg          hsync,      // hsync output
    output reg          vsync,      // vsync output
    output reg  [11:0]  line,       // current line number [Y]
    output reg  [11:0]  column,     // current column number [X]
    output reg  [2:0]   PixX,
    output reg  [3:0]   PixY,        // Y position of pixel in the symbol
    output reg  [11:0]  SymY,
    output      [11:0]  SymX,
    output reg  [4:0]   RegAddr
);
    integer counter;

    assign SymX = column >> 3 ;

    always @(posedge clk)
    begin
        if( rst_n  )
        begin
            if( en )
            begin
                column <= column + 1'b1 ;
                counter <= counter + 1'b1 ;
                if( counter == `HWL * 15 + 1 * 32 )
                begin
                    counter <= 0 ;
                    SymY <= SymY + 80 ;
                    RegAddr <= RegAddr + 1'b1 ;
                end
                PixX <= PixX + 1'b1 ;
                if ( PixY == 15 )
                        PixY <= 0 ;
                if( column == `HWL )
                begin
                    PixX<=0;
                    PixY <= PixY + 1'b1 ;
                    
                    column <= 12'h0 ;
                    line <= line + 1'b1 ;
                    
                    if( line == `VWF )
                    begin
                        line <= 12'h0 ;
                        PixY <= 0 ;
                        SymY <= 0 ;
                        RegAddr <= 5'h0 ;
                        counter <= 0 ;
                    end
                    
                    if( ( line >= ( `VVA + `VFP ) ) && ( line < ( `VVA + `VFP + `VSP ) ) )
                        vsync <= 1'b0 ;
                    else
                        vsync <= 1'b1 ;                
                end
                
                if( ( column >= ( `HVA + `HFP ) ) && ( column < ( `HVA + `HFP + `HSP ) ) )
                    hsync <= 1'b0 ;
                else
                    hsync <= 1'b1 ; 
            end               
        end
        else 
        begin
            counter <= 0 ;
            PixY  <= 4'b0 ;
            PixX  <= 3'b0 ;
            hsync <= 1'b1 ;
            vsync <= 1'b1 ;
            SymY <= 12'h0 ;
        end
    end

    initial begin
        counter = 0 ;
        PixX = 3'b0 ;
        SymY = 12'h0 ;
        RegAddr = 5'h0 ;
        line = 12'h0 ;
        column = 12'h0 ;
        hsync = 1'b1 ;
        vsync = 1'b1 ;
    end
    
endmodule
