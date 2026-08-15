//=====================================================================
// Modulo de requantizacao simples com arredondamento
//   atualmente usado apenas para fechar o ciclo arquitetural
//---------------------------------------------------------------------
// Author: Lucas Farias Martins
// Email:  lucas.martins@ee.ufcg.edu.br
// Date:   20/05/2026
//=====================================================================

module requant_round #(
    parameter SHIFT = 7
)(
    input  logic signed [31:0] acc_i,
    output logic signed [7:0]  q_o
);

    localparam logic signed [31:0] ROUND = (1 <<< (SHIFT-1));
    logic signed [31:0] rounded, shifted;

    always_comb begin
        rounded = acc_i + ROUND;     // rounding
        shifted = rounded >>> SHIFT; // shifting

        if (shifted > 127)       q_o = 8'sd127; // saturationing ...?
        else if (shifted < -128) q_o = -8'sd128;
        else                     q_o = shifted[7:0];
    end

endmodule

//=======================================
//  Top Requant Module
//=======================================
module requant_unit #(
    parameter OUTPUTS = 4,
    parameter SHIFT   = 7
)(
    input  logic clk,
    input  logic rst_n,
    input  logic signed [31:0] acc0_i,
    input  logic signed [31:0] acc1_i,
    input  logic signed [31:0] acc2_i,
    input  logic signed [31:0] acc3_i,
    output logic        [31:0] neuron_pkt  
);

    logic signed [7:0]  q0;
    logic signed [7:0]  q1;
    logic signed [7:0]  q2;
    logic signed [7:0]  q3;

    requant_round #( .SHIFT (7) ) req1_u ( .acc_i(acc0_i), .q_o(q0) );
    requant_round #( .SHIFT (7) ) req2_u ( .acc_i(acc1_i), .q_o(q1) );
    requant_round #( .SHIFT (7) ) req3_u ( .acc_i(acc2_i), .q_o(q2) );
    requant_round #( .SHIFT (7) ) req4_u ( .acc_i(acc3_i), .q_o(q3) );

    always_ff @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) neuron_pkt <= 'h0;
        else        neuron_pkt <= {q3,q2,q1,q0};
    end

endmodule