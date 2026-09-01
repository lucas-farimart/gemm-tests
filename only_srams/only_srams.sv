//=====================================================================
// Teste de produto Matriz-Vetor usando duas memorias
//---------------------------------------------------------------------
// Author: Lucas Farias Martins
// Email:  lucas.martins@ee.ufcg.edu.br
// Date:   05/08/2026
//=====================================================================

module only_srams #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter MEM_WORDS  = 256,
    parameter X_SIZE     = 8,
    parameter Y_SIZE     = 8,
    parameter X_MEM_FILE = "data/x.hex",
    parameter W_MEM_FILE = "data/w.hex",
    parameter LATENCY    = 2
)(
    input  logic clk,
    input  logic rstn,
    input  logic enb,
    input  logic done,
    output logic vld_o,
    output logic partial_o,

    output logic signed [DATA_WIDTH/2-1:0] mult_o,
    output logic signed [DATA_WIDTH-1:0]   acc_o,
    output logic signed [DATA_WIDTH-1:0]   result_o,
    output logic signed [DATA_WIDTH/4-1:0] requant_o
);

    //=========================================================
    // Sinais internos
    //=========================================================
    logic req_W, req_X;
    logic vld_W, vld_X;
    logic reset_acc;
    logic partial_r;

    logic [DATA_WIDTH-1:0] X;
    logic [DATA_WIDTH-1:0] W;
    logic [DATA_WIDTH-1:0] Y;

    logic [ADDR_WIDTH-1:0] addr_aux;
    logic [ADDR_WIDTH-1:0] addr_W, addr_X;
    logic [ADDR_WIDTH-1:0] base_W, base_X;

    logic signed [7:0]  byte_W,  byte_X;
    logic        [31:0] word_W,  word_X;
    logic               valid_W, valid_X;

    //=========================================================
    //  Bases de enderecamento (tamanho)
    //=========================================================
    // always_comb base_W = MEM_WORDS/8 - 1;    // 256/8 = 32
    // always_comb base_X = MEM_WORDS/32 - 1;   // 256/32 = 8

    always_comb base_W = X_SIZE*Y_SIZE/4 - 1; // 8
    always_comb base_X = X_SIZE/4 - 1;        // 2

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) 
            addr_aux <= '0;
        else if (vld_X) 
            addr_aux <= addr_X;
    end

    //=========================================================
    //  RAM para pesos
    //=========================================================
    mem_model #(
        .ADDR_WIDTH   ( ADDR_WIDTH ),
        .DATA_WIDTH   ( DATA_WIDTH ),
        .MEM_WORDS    ( MEM_WORDS  ),
        .LATENCY      ( LATENCY    ),
        .MEM_FILE     ( W_MEM_FILE )
    ) weight_mem (
        .clk          ( clk    ),
        .rstn         ( rstn   ),
        .req          ( req_W  ),
        .valid        ( vld_W  ),
        .addr         ( addr_W ),
        .rdata        ( W      )
    );

    mem_controller u_weight_mem_ctrl
    (
        .clk        ( clk       ),
        .rstn       ( rstn      ),
        .start_i    ( enb       ),
        .done_i     ( done      ),

        .base_i     ( base_W    ),
        .rdata_i    ( W         ),
        .valid_i    ( vld_W     ),
        .addr_o     ( addr_W    ),
        .req_o      ( req_W     ),

        .out_byte   ( byte_W  ),
        .out_word   ( word_W  ),
        .out_valid  ( valid_W )
    );

    //=========================================================
    //  RAM para entrada (actv)
    //=========================================================
    mem_model #(
        .ADDR_WIDTH   ( ADDR_WIDTH ),
        .DATA_WIDTH   ( DATA_WIDTH ),
        .MEM_WORDS    ( MEM_WORDS  ),
        .LATENCY      ( LATENCY    ),
        .MEM_FILE     ( X_MEM_FILE )
    ) input_mem (
        .clk          ( clk    ),
        .rstn         ( rstn   ),
        .req          ( req_X  ),
        .valid        ( vld_X  ),
        .addr         ( addr_X ),
        .rdata        ( X      )
    );

    mem_controller u_input_mem_ctrl
    (
        .clk        ( clk       ),
        .rstn       ( rstn      ),
        .start_i    ( enb       ),
        .done_i     ( done      ),

        .base_i     ( base_X    ),
        .rdata_i    ( X         ),
        .valid_i    ( vld_X     ),
        .addr_o     ( addr_X    ),
        .req_o      ( req_X     ),

        .out_byte   ( byte_X    ),
        .out_word   ( word_X    ),
        .out_valid  ( valid_X   )
    );

    //=========================================================
    //  Multiplicador Booth Radix-4
    //=========================================================
    booth_radix4 u_mult
    (
        .rstn      ( rstn      ),
        .clk       ( clk       ),
        .valid_in  ( valid_X   ),
        .a         ( byte_X    ),
        .b         ( byte_W    ),
        .valid_out ( vld_o     ),
        .p         ( mult_o    )
    );

    //=========================================================
    //  Acumulador 
    //=========================================================
    always_comb reset_acc = (addr_aux == base_X>>2 + 1) && !vld_o;
    always_comb result_o  = (reset_acc) ? acc_o : '0; 
    always_comb partial_o = reset_acc && !partial_r; 

    always_ff @(posedge clk or negedge rstn) begin
        // if (!rstn || reset_acc)
        if (!rstn) 
            acc_o <= '0;
        else if (vld_o) 
            acc_o <= acc_o + mult_o;
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) partial_r <= '0;
        else       partial_r <= partial_o;
    end

    //=========================================================
    //  Requantizacao 
    //=========================================================
    requant_round u_reqnt
    (
        .acc_i ( acc_o     ),
        .q_o   ( requant_o )
    );

endmodule