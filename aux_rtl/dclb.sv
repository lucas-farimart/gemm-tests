//=====================================================================
// Stack bidirecional de neuronios
//---------------------------------------------------------------------
// Author: Lucas Farias Martins
// Email:  lucas.martins@ee.ufcg.edu.br
// Date:   07/05/2026
// Update: 05/06/2026
//=====================================================================

module DCLB #(
    parameter DEPTH    = 32,
    parameter DATA_W   = 8,
    parameter ADDR_W   = $clog2(DEPTH+1),
	parameter MEM_FILE = "data/x_dclb.hex"
)(
    input  logic              clk,
    input  logic              rstn,
    //------------------------------ Controle 
    input  logic              push_i,
    input  logic              pop_i,
    input  logic              recirc_push_i,
    input  logic              recirc_pop_i,
    //--------------------------------- Dados 
    input  logic [DATA_W-1:0] data_i,
    output logic [DATA_W-1:0] data_head_o,
    output logic [DATA_W-1:0] data_tail_o,
    //-------------------------------- Status 
    output logic              full_o,
    output logic              empty_o
);

    //========================================================
    //  Internos
    //========================================================
    logic [DATA_W-1:0] stack [DEPTH];  // Memoria
    logic [DATA_W-1:0] data_stack0;    // Buffer de entrada/saida
    logic [DATA_W-1:0] data_stackN;    // Outra ponta
    logic [ADDR_W-1:0] s_ptr;          // Stack pointer

    logic push_valid;
    logic pop_valid;
    logic ctrl_rst;

    always_comb ctrl_rst = push_i && pop_i;

    // initial begin
    //     #81ns;
    //     $readmemh(MEM_FILE, stack);
    // end
    //========================================================
    //  Ponteiro, Flags e Controle de Head/Tail
    //========================================================
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) 
            s_ptr <= '1;
        else begin
            case ({push_i, pop_i})
                2'b10:   s_ptr <= (!full_o)  ? s_ptr + 1'b1 : s_ptr;
                2'b01:   s_ptr <= (!empty_o) ? s_ptr - 1'b1 : s_ptr;
                default: s_ptr <= s_ptr;
            endcase
        end
    end

    always_comb empty_o    = (s_ptr == 0);
    always_comb full_o     = (s_ptr == DEPTH);
    always_comb push_valid = ((push_i || recirc_push_i) && !full_o);
    always_comb pop_valid  = ((pop_i  || recirc_pop_i)  && !empty_o);

    always_comb data_stack0 = (recirc_push_i) ? stack[DEPTH-1] : data_i;
    always_comb data_stackN = (recirc_pop_i)  ? stack[0] : 'h0;

    // Por algum motivo nao funciona always comb nessas saidas
    assign data_head_o = data_stackN;
    assign data_tail_o = data_stack0;

    //========================================================
    //  Pilha (stack)
    //========================================================

    // PRIMEIRA (head)
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn ) 
            stack[0] <= '0;
        else begin
            case ({push_valid, pop_valid})
                2'b10:   stack[0] <= data_stack0;
                2'b01:   stack[0] <= stack[1];
                // default: stack[0] <= 'h0;
            endcase
        end
    end

    // INTERMEDIARIAS
    generate
        for (genvar i=1; i<DEPTH-1; ++i) begin 
            always_ff @(posedge clk or negedge rstn) begin
                if (!rstn ) 
                    stack[i] <= 'h0;
                else begin
                    case ({push_valid, pop_valid})
                        2'b10:  stack[i] <= stack[i-1];
                        2'b01:  stack[i] <= stack[i+1];
                    endcase
                    end  
                end
        end
    endgenerate

    // ULTIMA (tail)
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn ) 
            stack[DEPTH-1] <= '0;
        else begin
            case ({push_valid, pop_valid})
                2'b10:   stack[DEPTH-1] <= stack[DEPTH-2];
                2'b01:   stack[DEPTH-1] <= data_stackN;
                // default: stack[DEPTH-1] <= 'h0;
            endcase       
        end
    end

endmodule