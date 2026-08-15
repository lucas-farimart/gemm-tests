//=====================================================================
// TESTBENCH: Teste de produto Matriz-Vetor usando duas memorias
//---------------------------------------------------------------------
// Author: Lucas Farias Martins
// Email:  lucas.martins@ee.ufcg.edu.br
// Date:   06/08/2026
//=====================================================================

module tb_only_srams;

    localparam ADDR_WIDTH = 16;
    localparam DATA_WIDTH = 32;
    localparam MEM_WORDS  = 256;
    localparam X_SIZE     = 8;
    localparam Y_SIZE     = 8;
    localparam LATENCY    = 2;

    logic                    clk;
    logic                    rstn;
    logic                    enb;
    logic                    done;
    logic                    vld_o;
    logic                    partial_o;
    logic [DATA_WIDTH/2-1:0] mult_o;
    logic [DATA_WIDTH-1:0]   acc_o;
    logic [DATA_WIDTH-1:0]   result_o;
    logic [DATA_WIDTH/4-1:0] requant_o;

    //=======================================
    //  TESTBENCH ARRAYS
    //=======================================
    byte X[X_SIZE], W[X_SIZE][Y_SIZE];
    int  Y[Y_SIZE], Y_ref[Y_SIZE];
    int  y_idx;

    //=======================================
    //  DUT INSTANCE
    //=======================================
    only_srams #(
        .ADDR_WIDTH ( ADDR_WIDTH  ),
        .DATA_WIDTH ( DATA_WIDTH  ), 
        .MEM_WORDS  ( MEM_WORDS   ), 
        .X_SIZE     ( X_SIZE      ),
        .Y_SIZE     ( Y_SIZE      ),
        .LATENCY    ( LATENCY     )
    ) DUT (   
        .clk        ( clk         ),
        .rstn       ( rstn        ),
        .enb        ( enb         ),
        .done       ( done        ),
        .vld_o      ( vld_o       ),
        .partial_o  ( partial_o   ),
        .mult_o     ( mult_o      ),
        .acc_o      ( acc_o       ),
        .result_o   ( result_o    ),
        .requant_o  ( requant_o   )
    );

    //=======================================
    //  CLOCK GENERATION
    //=======================================
    always #10ns clk = ~clk;

    //=======================================
    //  INITIALS
    //=======================================
    initial begin
        
        #1ns; 
        
        foreach(Y_ref[i]) Y_ref[i] = 0;

        $display("X =");
        for (int j = 0; j < X_SIZE; j++) begin
            X[j] = j; 
            $write("%02h ", X[j]);
        end
        $display("\n");

        $display("W = ");
        for (int i = 0; i < X_SIZE; i++) begin
            for (int j = 0; j < Y_SIZE; j++) begin
                W[i][j] = j;
                $write("%02h ", W[i][j]);
            end
            $display("");
        end
        $display("\n");

    end

    initial begin

        $display("");
        $display("===================================================================");
        $display("                ___                                                ");
        $display("               / __|___ _ __  _ __  __ _ _ _ ___                   ");
        $display("              | (__/ _ \\ '  \\| '_ \\/ _` | '_/ -_)               ");
        $display("               \\___\\___/_|_|_| .__/\\__,_|_| \\___|              ");
        $display("                             |_|                                   ");
        $display("===================================================================");
        $display("           Teste de arquiteturas para multiplicacao MxV            ");
        $display("===================================================================");
        $display("");
        
        clk = 0; enb = 0; rstn = 0; done = 0;

        #40ns rstn = 1;
        #20ns enb  = 1;
        #20ns enb  = 0;

        @(posedge vld_o); y_idx = 0;

        while(y_idx < Y_SIZE) begin
            @(posedge clk)
            if(partial_o) begin
                Y[y_idx] = acc_o;
                $display("Y[%0d] = %0d", y_idx, Y[y_idx]);
                y_idx += 1;
            end
        end
        $display("");

        @(negedge clk); done = 1;
        // @(negedge clk); done = 0;

        for (int i=0; i<Y_SIZE; i++) begin
            @(posedge clk)
            for (int j=0; j<X_SIZE; j++) 
                Y_ref[i] += X[j] * W[i][j];
        end

        if (Y == Y_ref) $display("Resultados de Y e Y_ref coincidem");
        else            $display("Resultados DIFEREM: Y e Y_ref");
        $display("");

        repeat(4) @(posedge clk);
        $finish(0);

    end

    initial begin
        #12us $finish(1);
    end

endmodule