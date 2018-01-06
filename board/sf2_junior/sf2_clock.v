module sf2_clk
(
    output   RCOSC_25_50MHZ_O2F
);
    wire N_RCOSC_25_50MHZ_CLKOUT, N_RCOSC_25_50MHZ_CLKINT;
    
    RCOSC_25_50MHZ_FAB I_RCOSC_25_50MHZ_FAB (.A(
        N_RCOSC_25_50MHZ_CLKOUT), .CLKOUT(N_RCOSC_25_50MHZ_CLKINT));
    RCOSC_25_50MHZ #( .FREQUENCY(50.0) )  I_RCOSC_25_50MHZ (.CLKOUT(
        N_RCOSC_25_50MHZ_CLKOUT));
    CLKINT I_RCOSC_25_50MHZ_FAB_CLKINT (.A(N_RCOSC_25_50MHZ_CLKINT), 
        .Y(RCOSC_25_50MHZ_O2F));
    
endmodule

module RCOSC_25_50MHZ_FAB ( 
  CLKOUT,
  A );

/* synthesis syn_black_box */
/* synthesis syn_noprune=1 */

output CLKOUT;
input A;

endmodule

module RCOSC_25_50MHZ ( 
  CLKOUT );

/* synthesis syn_black_box */
/* synthesis syn_noprune=1 */

output CLKOUT;

parameter FREQUENCY = 50.0;

endmodule
