
//hardware top level module
module sm_top
(
    input           clkIn,
    input           rst_n,
    input   [ 3:0 ] clkDevide,
    input           clkEnable,
    output          clk,
    //input   [ 4:0 ] regAddr,
    //output  [31:0 ] regData,
    output              hsync,
    output              vsync,
    output  [3:0]       R,
    output  [3:0]       G,
    output  [3:0]       B,
    output              buzz,
    output  [3:0]       led
);
    //metastability input filters
    wire    [ 3:0 ] devide;
    wire            enable;
    //wire    [ 4:0 ] addr;
    assign led = 0 ;

    sm_debouncer #(.SIZE(4)) f0(clkIn, 4'b1000, devide);
    sm_debouncer #(.SIZE(1)) f1(clkIn, clkEnable, enable);
    //sm_debouncer #(.SIZE(5)) f2(clkIn, regAddr,   addr  );

    wire   [ 4:0 ] addr;
    wire   [31:0 ] regData;

    VGA_top VGA_top_0
    (
        .clk    ( clkIn     ),
        .rst_n  ( rst_n     ),
        .hsync  ( hsync     ),
        .vsync  ( vsync     ),
        .R      ( R         ),
        .G      ( G         ),
        .B      ( B         ),
        .buzz   ( buzz      ),
        .regAddr( addr      ),
        .regData( regData   )
    );

    //cores
    //clock devider
    sm_clk_divider sm_clk_divider
    (
        .clkIn      ( clkIn     ),
        .rst_n      ( rst_n     ),
        .devide     ( devide    ),
        .enable     ( enable    ),
        .clkOut     ( clk       )
    );

    //instruction memory
    wire    [31:0]  imAddr;
    wire    [31:0]  imData;
    sm_rom reset_rom(imAddr, imData);

    sm_cpu sm_cpu
    (
        .clk        ( clk       ),
        .rst_n      ( rst_n     ),
        .regAddr    ( addr      ),
        .regData    ( regData   ),
        .imAddr     ( imAddr    ),
        .imData     ( imData    )
    );

endmodule

//metastability input debouncer module
module sm_debouncer
#(
    parameter SIZE = 1
)
(
    input                      clk,
    input      [ SIZE - 1 : 0] d,
    output reg [ SIZE - 1 : 0] q
);
    reg        [ SIZE - 1 : 0] data;

    always @ (posedge clk) begin
        data <= d;
        q    <= data;
    end

endmodule

//tunable clock devider
module sm_clk_divider
#(
    parameter shift  = 16,
              bypass = 0
)
(
    input           clkIn,
    input           rst_n,
    input   [ 3:0 ] devide,
    input           enable,
    output          clkOut
);
    wire [31:0] cntr;
    wire [31:0] cntrNext = cntr + 1;
    sm_register_we r_cntr(clkIn, rst_n, enable, cntrNext, cntr);

    assign clkOut = bypass ? clkIn 
                           : cntr[shift + devide];
endmodule
