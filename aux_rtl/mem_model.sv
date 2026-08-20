//=====================================================================
// Modelo de memoria com latencia ajustavel
//---------------------------------------------------------------------
// Author: Lucas Farias Martins
// Email:  lucas.martins@ee.ufcg.edu.br
// Date:   05/08/2026
//=====================================================================

module mem_model #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter MEM_WORDS  = 256,
    parameter LATENCY    = 2,
	parameter MEM_FILE   = "../data/w.hex"
)(
    input  logic                  clk,
    input  logic                  rstn,
    input  logic                  req,
    output logic                  valid,
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [DATA_WIDTH-1:0] rdata
);

    //=========================================================
    // Memoria / Controle interno
    //=========================================================
    logic [DATA_WIDTH-1:0] mem [0:MEM_WORDS-1];
    logic                  busy;
    logic                  cooldown;
    logic [ADDR_WIDTH-1:0] latched_addr;
    integer                latency_counter;

    initial $readmemh(MEM_FILE, mem);

    //=========================================================
    // Modelo
    //=========================================================

    always_ff @(posedge clk or posedge rstn) begin

        if (!rstn) begin
            valid  <= 0;     cooldown         <= 0;
            rdata  <= 0;     latched_addr     <= 0;
            busy   <= 0;     latency_counter  <= 0;
        end
        else begin

            if (cooldown) 
            cooldown <= 0; // Cooldown de 1 ciclo apos resposta valida
            valid    <= 0; // Valid dura apenas 1 ciclo

            if (busy) begin

                latency_counter <= latency_counter - 1;
                
                if (latency_counter == 1) begin
                    rdata    <= mem[latched_addr];
                    valid    <= 1;
                    busy     <= 0;
                    cooldown <= 1;
                end
            end
            
            // Nova requisicao
            else if (req && !cooldown) begin
                busy <= 1;
                latched_addr <= addr;
                latency_counter <= LATENCY + 2;
                // latency_counter <= LATENCY + $urandom_range(1,2);
            end
        end
    end

endmodule
