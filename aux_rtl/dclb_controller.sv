//=====================================================================
// Controlador do Buffer DCL: 
//   - Esconde latencia por meio de double buff
//   - Envia bytes sequencialmente (stream) 
//---------------------------------------------------------------------
// Author: Lucas Farias Martins
// Email:  lucas.martins@ee.ufcg.edu.br
// Date:   18/05/2026
//=====================================================================

module dclb_controller
(
    input  logic       clk,
    input  logic       rstn,
    input  logic       start_i,
    input  logic       done_i,
    input  logic       valid_i,
    input  logic [7:0] x_size_i,

    output logic       vec_len_o,
    output logic       push_o,
    output logic       pop_o,
    output logic       rc_push_o,
    output logic       rc_pop_o,
    output logic       valid_o
);

    //======================================================
    //  INTERNALS
    //======================================================
    localparam   BYTES = 4;
    logic  [1:0] stream_ptr;
    logic  [7:0] vector_ptr;
    logic        streamed;
    logic        vec_len;
    logic        switch_dir;

    typedef enum logic [3:0] {IDLE,REQ,WAIT,STREAM,DONE} state_t;
    state_t CS, NS;
    
    //======================================================
    //  STATES
    //======================================================
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) 
             CS <= IDLE;
        else CS <= NS;
    end

    always_comb begin
        case(CS)
            IDLE:    NS = (start_i)  ? REQ    : IDLE;
            WAIT:    NS = (valid_i)  ? STREAM : WAIT;
            STREAM:  NS = (streamed) ? DONE   : STREAM;
            REQ:     NS = WAIT;
            DONE:    NS = WAIT;
            default: NS = CS;
        endcase
    end

    //======================================================
    //  VALID OUTPUT CONTROL
    //======================================================
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) valid_o <= '0;
        else       valid_o <= (CS==STREAM);
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) 
            switch_dir <= '0;
        else if(vector_ptr == x_size_i)     
            switch_dir <= ~switch_dir;
    end
    
    //======================================================
    //  STREAM POINTER 
    //======================================================
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) stream_ptr <= 'h0;
        else if(valid_o)     stream_ptr <= stream_ptr+1;
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) vector_ptr <= 'h0;
        else if(vec_len_o)   vector_ptr <= 'h0;
        else if(valid_o)     vector_ptr <= vector_ptr+1;
    end

    always_comb streamed  = (stream_ptr == $clog2(BYTES));
    always_comb vec_len_o = (vector_ptr == x_size_i);
    always_comb rc_pop_o  = valid_o && (vector_ptr <= x_size_i) && ~switch_dir;
    always_comb rc_push_o = valid_o && (vector_ptr <= x_size_i) &&  switch_dir;

endmodule 