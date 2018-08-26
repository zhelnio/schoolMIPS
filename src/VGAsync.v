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
    wire visible;

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
        .RegAddr(   regAddr     ),
        .visible( visible )
    );

    // wire          hsync_dbg;
    // wire          vsync_dbg;
    // wire  [11:0]  line_dbg;
    // wire  [11:0]  column_dbg;
    // wire  [2:0]   PixX_dbg;
    // wire  [3:0]   PixY_dbg;
    // wire  [11:0]  SymY_dbg;
    // wire  [11:0]  SymX_dbg;
    // wire  [4:0]   RegAddr_dbg;
    // wire          visible_dbg;

    // VGAsync vgasync_1
    // (
    //     .clk    ( clk           ),
    //     .rst_n  ( rst_n         ),
    //     .en     ( 1'b0            ),
    //     .hsync  ( hsync_dbg         ),
    //     .vsync  ( vsync_dbg         ),
    //     .line   ( pixelLine_dbg     ),
    //     .column ( pixelColumn_dbg   ),
    //     .PixX   ( PixX_dbg          ),
    //     .PixY   ( PixY_dbg          ),
    //     .SymY   ( SymY_dbg          ),
    //     .SymX   ( SymX_dbg          ),
    //     .RegAddr( regAddr_dbg       ),
    //     .visible( visible_dbg       )
    // );

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

    //assign  RGBsig = ( pixelLine < 481 && pixelColumn < 641 ) ? RGB : 12'h000 ;
    assign  RGB = onoff ? fgColor : bgColor ;

    assign RGBsig = visible ? bgColor : 12'h000 ;
    //assign RGBsig = bgColor;
    //assign  RGBsig = ( pixelLine < 481 && pixelColumn < 641 ) ? bgColor : 12'h000 ;

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
    sm_register r_en(clk, rst_n, ~en, en );

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

module VGAsync_old
(
    input               clk,        // VGA clock
    input               rst_n,        // positive reset
    input               en,
    output      reg     hsync,      // hsync output
    output      reg     vsync,      // vsync output
    output      [11:0]  line,       // current line number [Y]
    output      [11:0]  column,     // current column number [X]
    output      [2:0]   PixX,
    output      [3:0]   PixY,        // Y position of pixel in the symbol
    output      [11:0]  SymY,
    output      [11:0]  SymX,
    output      [4:0]   RegAddr,
    output              visible 
);

    //TODO: add width param to all regs instances

    wire c_last_column = (column == `HWL);
    wire c_last_line   = (line   == `VWF);
    wire c_image_end   = c_last_column & c_last_line;

    wire [11:0] column_nx = c_last_column ? 12'b0 : column + 1;
    sm_register_we r_column(clk, rst_n, en, column_nx, column ); 

    wire [ 2:0] PixX_nx = c_last_column ?  3'b0 : PixX + 1;
    sm_register_we r_PixX (clk, rst_n, en, PixX_nx,   PixX   );

    wire [11:0] line_nx = ~c_last_column ? line  :
                           c_last_line   ? 12'b0 : line + 1;
    sm_register_we r_line (clk, rst_n, en, line_nx,   line   );

    wire [ 3:0] PixY_nx = PixY == 15     ? 4'b0 : // TODO: what is 15?
                          ~c_last_column ? PixY :
                           c_last_line   ? 4'b0 : PixY + 1;
    sm_register_we r_PixY (clk, rst_n, en, PixY_nx,   PixY   );

    wire [31:0] cntr;
    wire        c_next_string = cntr == `HWL * 15  + 1 * 32; // TODO: cntr refactoring
    wire [31:0] cntr_nx = c_next_string | c_image_end ? 0 : cntr + 1;
    sm_register_we r_cntr (clk, rst_n, en, cntr_nx, cntr );

    assign SymX = column >> 3 ;

    wire [11:0] SymY_nx =  c_next_string ? SymY + 80 :
                           c_image_end   ? 0         : SymY;
    sm_register_we r_SymY (clk, rst_n, en, SymY_nx, SymY );

    wire [11:0] RegAddr_nx = c_next_string ? RegAddr + 1'b1 :
                             c_image_end   ? 0              : RegAddr;
    sm_register_we r_RegAddr (clk, rst_n, en, RegAddr_nx, RegAddr );

    always @(posedge clk)
    begin
        if( rst_n  )
        begin
            if( en )
            begin
                if( c_last_column )
                begin
                    
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
            hsync <= 1'b1 ;
            vsync <= 1'b1 ;
        end
    end

    initial begin
        hsync = 1'b1 ;
        vsync = 1'b1 ;
    end

endmodule

module VGAsync
(
    input               clk,        // VGA clock
    input               rst_n,        // positive reset
    output              hsync,      // hsync output
    output              vsync,      // vsync output
    input en,
    output      [11:0]  line,       // current line number [Y]
    output      [11:0]  column,     // current column number [X]
    output      [2:0]   PixX,
    output      [3:0]   PixY,        // Y position of pixel in the symbol
    output      [11:0]  SymY,
    output      [11:0]  SymX,
    output      [4:0]   RegAddr,
    output              visible 
);
    // Total redesign
    wire h_pixel_valid;
    wire h_pixel_last;
    wire v_pixel_valid;
    wire v_pixel_last;
    
    wire pixel_valid = h_pixel_valid & v_pixel_valid;
    wire picture_end = h_pixel_last & v_pixel_last;

    wire [11:0] column_nx = h_pixel_last ? 12'b0 : column + 1;
    sm_register_we r_column(clk, rst_n, h_pixel_valid, column_nx, column );

    wire [11:0] line_nx = v_pixel_last ? 12'b0 : line + 1;
    sm_register_we r_line(clk, rst_n, v_pixel_valid, line_nx, line );

    assign PixX = column [2:0];
    assign PixY = line   [3:0];
    assign SymX = column >> 3 ;

    wire string_last = h_pixel_last & line [3:0] == 4'hF;

    wire [11:0] SymY_nx =  string_last ? SymY + 80 :
                           picture_end ? 0         : SymY;
    sm_register r_SymY (clk, rst_n, SymY_nx, SymY );

    wire [11:0] RegAddr_nx = string_last ? RegAddr + 1'b1 :
                             picture_end ? 0              : RegAddr;
    sm_register r_RegAddr (clk, rst_n, RegAddr_nx, RegAddr );

    // clock_divider
    wire vga_clk;
    sm_register r_cntr(clk, rst_n, ~vga_clk, vga_clk);

    wire h_visible;
    wire v_visible;
    assign visible = h_visible & v_visible;

    sync_strobe
    #(
        .SYNC_VA ( `HVA          ),
        .SYNC_FP ( `HFP          ),
        .SYNC_SP ( `HSP          ),
        .SYNC_BP ( `HBP          ) 
    )
    sync_strobe_h
    (
        .clk     ( clk           ),
        .rst_n   ( rst_n         ),
        .valid   ( vga_clk       ),
        .sync    ( hsync         ),
        .visible ( h_visible     ),
        .pixel   ( h_pixel_valid ),
        .last    ( h_pixel_last  ) 
    );

    sync_strobe
    #(
        .SYNC_VA ( `VVA          ),
        .SYNC_FP ( `VFP          ),
        .SYNC_SP ( `VSP          ),
        .SYNC_BP ( `VBP          ) 
    )
    sync_strobe_v
    (
        .clk     ( clk           ),
        .rst_n   ( rst_n         ),
        .valid   ( h_pixel_last  ),
        .sync    ( vsync         ),
        .visible ( v_visible     ),
        .pixel   ( v_pixel_valid ),
        .last    ( v_pixel_last  ) 
    );

endmodule

module sync_strobe
#(
    parameter SYNC_VA = 640, // Visible area
              SYNC_FP = 16,  // Front porch
              SYNC_SP = 96,  // Sync pulse
              SYNC_BP = 48   // Back porch
)(
    input   clk,
    input   rst_n,
    input   valid,
    output  sync,
    output  visible,
    output  pixel,
    output  last 
);
    localparam SYNC_DOWN    = SYNC_VA + SYNC_FP - 1;
    localparam SYNC_UP      = SYNC_VA + SYNC_FP + SYNC_SP - 1;
    localparam VISIBLE_UP   = SYNC_VA + SYNC_FP + SYNC_SP + SYNC_BP - 1;
    localparam VISIBLE_DOWN = SYNC_VA - 1;

    wire [11:0] cntr;

    wire cntr_clr    = valid & cntr == VISIBLE_UP;
    wire sync_set    = valid & cntr == SYNC_UP;
    wire sync_clr    = valid & cntr == SYNC_DOWN;
    wire visible_set = valid & cntr == VISIBLE_UP;
    wire visible_clr = valid & cntr == VISIBLE_DOWN;

    wire [11:0] cntr_nx  = cntr_clr ? 12'b0 : cntr + 1;
    sm_register_we r_cntr(clk, rst_n, valid, cntr_nx, cntr);

    // output: sync
    wire sync_n;
    wire sync_n_nx = sync_set ? 1'b0 :
                     sync_clr ? 1'b1 : sync_n;
    sm_register r_sync_n(clk, rst_n, sync_n_nx, sync_n);
    assign sync = ~sync_n;

    // output: visible
    wire visible_nx = visible_set ? 1'b1 :
                      visible_clr ? 1'b0 : visible;
    sm_register r_visible(clk, rst_n, visible_nx, visible);

    // output: pixel
    assign pixel = valid & visible;

    // output: last
    assign last = valid & cntr == VISIBLE_DOWN;
    
endmodule



/*
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

*/
