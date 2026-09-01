//=====================================================================
// Módulo de produto Matriz-Vetor usando memoria SRAM para modelo 
// (pesos) e DCLB para ativacoes (entrada)
//---------------------------------------------------------------------
// Author: Lucas Farias Martins
// Email:  lucas.martins@ee.ufcg.edu.br
// Date:   17/08/2026
//=====================================================================

module sram_dclb #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter MEM_WORDS  = 256,
    parameter X_SIZE     = 8,
    parameter Y_SIZE     = 8,
    parameter X_MEM_FILE = "data/x_dclb.hex",
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

    logic vec_len;
    logic push, rc_push;        
    logic pop,  rc_pop;         
    logic full;        
    logic empty;       

    logic        [7:0] size_count;
    logic signed [7:0] data;        
    logic signed [7:0] data_head;   
    logic signed [7:0] data_tail;   
    
    logic [DATA_WIDTH-1:0] X;
    logic [DATA_WIDTH-1:0] W;
    logic [DATA_WIDTH-1:0] Y;

    logic [ADDR_WIDTH-1:0]   addr_W;
    logic [ADDR_WIDTH-1:0]   base_W;
    logic [ADDR_WIDTH/2-1:0] base_X;

    logic signed [7:0]  byte_W,  byte_X;
    logic        [31:0] word_W;
    logic               valid_W, valid_X;

    //=========================================================
    //  Bases de endereçamento (tamanho)
    //=========================================================
    always_comb base_W = X_SIZE*Y_SIZE/4 - 1; // 8 palavras de 32b
    always_comb base_X = X_SIZE - 1;          // 8 bytes

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
    //  DCLB para entrada (actv)
    //=========================================================
    localparam ADDR_DCLB = $clog2(MEM_WORDS+1);

    DCLB #(
        .DEPTH          ( MEM_WORDS     ),
        .DATA_W         ( DATA_WIDTH/4  ),
        .ADDR_W         ( ADDR_DCLB     ),
        .MEM_FILE       ( X_MEM_FILE    ) 
    ) u_input_dclb (
        .clk            ( clk          ),
        .rstn           ( rstn         ),
        .push_i         ( '0           ),
        .pop_i          ( '0           ),
        .recirc_push_i  ( rc_push      ),
        .recirc_pop_i   ( rc_pop       ),
        
        .data_i         ( 8'h0         ),
        .data_head_o    ( data_head    ),
        .data_tail_o    ( data_tail    ),
        .full_o         ( full         ),
        .empty_o        ( empty        )
    );

    dclb_controller u_input_dclb_ctrl
    (
        .clk        ( clk       ),
        .rstn       ( rstn      ),
        .start_i    ( enb       ),
        .done_i     ( done      ),
        .valid_i    ( vld_W     ), // Sincronizado com memoria SRAM
        .x_size_i   ( base_X    ),

        .vec_len_o  ( vec_len   ),
        .push_o     ( push      ),
        .pop_o      ( pop       ),
        .rc_push_o  ( rc_push   ),
        .rc_pop_o   ( rc_pop    ),
        .valid_o    ( valid_X   )
    );

    always_comb begin
        case ({rc_pop,rc_push})
            2'b01:   byte_X = data_tail;
            2'b10:   byte_X = data_head;
            default: byte_X = 'h0;
        endcase
    end

    //=========================================================
    //  Multiplicador Booth Radix-4
    //=========================================================
    booth_radix4 u_mult
    (
        .rstn      ( rstn      ),
        .clk       ( clk       ),
        .valid_in  ( valid_W   ),
        .a         ( byte_W    ),
        .b         ( byte_X    ),
        .valid_out ( vld_o     ),
        .p         ( mult_o    )
    );

    //=========================================================
    //  Acumulador 
    //=========================================================
    always_comb reset_acc = (size_count == base_X+1);
    always_comb result_o  = (reset_acc) ? acc_o : '0; 
    always_comb partial_o =  reset_acc && !partial_r; 

    always_ff @(posedge clk or negedge rstn) begin
        // if (!rstn || reset_acc)
        if (!rstn) 
            acc_o <= '0;
        else if (vld_o) 
            acc_o <= acc_o + mult_o;
    end

    always_ff @(posedge clk or negedge rstn) begin
        // if (!rstn || reset_acc)
        if (!rstn) 
            size_count <= '0;
        else if (vld_o) 
            size_count <= size_count + 1;
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