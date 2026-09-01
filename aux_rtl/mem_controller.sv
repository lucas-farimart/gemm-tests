//=====================================================================
// Controlador de Memoria com Ping-Pong Buffers 
//   - Esconde latencia por meio de double-buffering
//   - Envia bytes sequencialmente (stream) 
//---------------------------------------------------------------------
// Author: Lucas Farias Martins
// Email:  lucas.martins@ee.ufcg.edu.br
// Date:   18/05/2026
//=====================================================================

module mem_controller
(
    input  logic clk,
    input  logic rstn,

    input  logic        start_i,
    input  logic        done_i,
    input  logic        valid_i,
    input  logic [15:0] base_i,
    input  logic [31:0] rdata_i,

    output logic        req_o,
    output logic [15:0] addr_o,
    output logic [7:0]  out_byte,
    output logic [31:0] out_word,
    output logic        out_valid
);

    //======================================================
    //  INTERNALS
    //======================================================
    localparam   BYTES = 4;
    logic        streamed;
    logic        ping_read;
    logic  [1:0] stream_ptr;
    logic [15:0] current_addr;
    logic [31:0] ping;
    logic  [7:0] pong [4];

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
    //  BUFFERS ADDRESS
    //======================================================
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) 
            current_addr <= 'h0;
        else if (valid_i) 
            current_addr <= (current_addr == base_i) ? '0 : current_addr + 1;
    end

    always_comb req_o  = (CS==REQ) || (CS==STREAM && !out_valid);
    always_comb addr_o = current_addr;

    //======================================================
    //  DOUBLE BUFFERING (PING and PONG)
    //======================================================
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn)  
            ping <= 'h0;
        else if (valid_i) 
            ping <= rdata_i;
    end

    always_ff @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            ping_read <= 0;
            out_valid <= 0;
        end else begin
            ping_read <= (NS==STREAM) && (CS==WAIT);
            out_valid <= (CS==STREAM);
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn ) 
            pong <= '{default: 0};
        else begin 
            if (ping_read) begin
                pong[0] <= ping[31:24];
                pong[1] <= ping[23:16];
                pong[2] <= ping[15:8];
                pong[3] <= ping[7:0];
            end
            else begin
                pong[3] <= pong[2];
                pong[2] <= pong[1];
                pong[1] <= pong[0];
                pong[0] <= 'h0; 
            end
        end
    end

    //======================================================
    //  STREAM POINTER 
    //======================================================
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn)         stream_ptr <= 'h0;
        else if(out_valid) stream_ptr <= stream_ptr+1;
    end

    always_comb streamed = (stream_ptr == $clog2(BYTES));
    always_comb out_byte = out_word[7:0];
    always_comb out_word = {pong[0],pong[1],pong[2],pong[3]};
    // always_comb out_word = {pong[3],pong[2],pong[1],pong[0]};
    // always_comb out_byte = pong[BYTES-1];

endmodule 