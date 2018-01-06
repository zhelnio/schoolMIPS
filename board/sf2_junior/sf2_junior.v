
module sf2_junior
(
    output [ 6:0] HEX,
    output        HEX_DP,
    output [ 3:0] HEX_AN,
    output        LED_B,
    output        LED_G,
    output        LED_Y,
    output        LED_R,

    input  [ 3:0] SW,
    input  [ 2:0] KEY
);
    // wires & inputs
    wire          clkCpu;
    wire          clkIn;
    wire          rst_n     =  KEY[0];
    wire          clkEnable = ~KEY[1];
    wire [  3:0 ] clkDevide =  4'b1000;
    wire [  4:0 ] regAddr   = { KEY[2], ~SW };
    wire [ 31:0 ] regData;

    //SmartFusion2 internal oscillator (black box)
    sf2_clk clock (clkIn);

    //cores
    sm_top sm_top
    (
        .clkIn      ( clkIn     ),
        .rst_n      ( rst_n     ),
        .clkDevide  ( clkDevide ),
        .clkEnable  ( clkEnable ),
        .clk        ( clkCpu    ),
        .regAddr    ( regAddr   ),
        .regData    ( regData   )
    );

    //outputs
    assign LED_B[0] = clkCpu;
    assign LED_G    = 1'b0;
    assign LED_Y    = 1'b0;
    assign LED_R    = 1'b0;

    //hex out
    wire clkHex;

    sm_clk_divider hex_clk_divider
    (
        .clkIn   ( clkIn  ),
        .rst_n   ( rst_n  ),
        .devide  ( 4'b1   ),
        .enable  ( 1'b1   ),
        .clkOut  ( clkHex )
    );

    wire [ 31:0 ] h7segment = regData;
    wire [  7:0 ] anodes;
    assign HEX_AN = ~anodes[3:0];

    sm_hex_display_8 sm_hex_display_8
    (
        .clock          ( clkHex    ),
        .resetn         ( rst_n     ),
        .number         ( h7segment ),

        .seven_segments ( HEX       ),
        .dot            ( HEX_DP    ),
        .anodes         ( anodes    )
    );

endmodule
