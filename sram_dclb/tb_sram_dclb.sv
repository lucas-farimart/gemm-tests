//=====================================================================
// Teste de produto Matriz-Vetor usando uma memoria e um DCLB
// com dados aleatorios INT8 e arquivos HEX de 32 e 8 bits, 
// respectivamente
//---------------------------------------------------------------------
// Author: Lucas Farias Martins
// Email:  lucas.martins@ee.ufcg.edu.br
// Date:   18/08/2026
//=====================================================================

module tb_sram_dclb;

    localparam ADDR_WIDTH = 16;
    localparam DATA_WIDTH = 32;
    localparam MEM_WORDS  = 256;
    localparam X_SIZE     = 8;
    localparam Y_SIZE     = 8;
    localparam LATENCY    = 2;

    localparam NUM_TESTS  = 10;
    localparam X_HEX_FILE = "data/x_dclb.hex";
    localparam W_HEX_FILE = "data/w.hex";

    //=============================================================
    // SIGNALS
    //=============================================================
    logic  clk;
    logic  rstn;
    logic  enb;
    logic  done;

    logic                           vld_o;
    logic                           partial_o;
    logic signed [DATA_WIDTH/2-1:0] mult_o;
    logic signed [DATA_WIDTH-1:0]   acc_o;
    logic signed [DATA_WIDTH-1:0]   result_o;
    logic signed [DATA_WIDTH/4-1:0] requant_o;

    //=============================================================
    // TESTBENCH ARRAYS
    //=============================================================

    // INT8
    byte X[X_SIZE];
    byte W[X_SIZE][Y_SIZE];

    // Resultados
    int Y[Y_SIZE];
    int Y_ref[Y_SIZE];

    int y_idx;

    //=============================================================
    // HEX MEMORY ARRAYS
    //=============================================================

    logic [31:0] X_MEM [(X_SIZE+3)/4];
    logic [31:0] W_MEM [(X_SIZE*Y_SIZE+3)/4];

    //=============================================================
    // DUT
    //=============================================================

    sram_dclb #(
        .ADDR_WIDTH ( ADDR_WIDTH ),
        .DATA_WIDTH ( DATA_WIDTH ),
        .MEM_WORDS  ( MEM_WORDS  ),
        .X_SIZE     ( X_SIZE     ),
        .Y_SIZE     ( Y_SIZE     ),
        .X_MEM_FILE ( X_HEX_FILE ),
        .W_MEM_FILE ( W_HEX_FILE ),
        .LATENCY    ( LATENCY    )
    ) DUT (
        .clk        ( clk        ),
        .rstn       ( rstn       ),
        .enb        ( enb        ),
        .done       ( done       ),
        .vld_o      ( vld_o      ),
        .partial_o  ( partial_o  ),
        .mult_o     ( mult_o     ),
        .acc_o      ( acc_o      ),
        .result_o   ( result_o   ),
        .requant_o  ( requant_o  )
    );

    //=============================================================
    // CLOCK
    //=============================================================
    always #10ns clk = ~clk;

    //=============================================================
    //======================================== GENERATE RANDOM INT8
    task generate_random_data();

        for (int i = 0; i < X_SIZE; i++) X[i] = $urandom_range(0,255);

        for (int i = 0; i < X_SIZE; i++) begin
            for (int j = 0; j < Y_SIZE; j++) 
            W[i][j] = $urandom_range(0,255);
        end

    endtask

    //=============================================================
    //================================================== PRINT DATA
    task print_data();

        $display("\n=================================");
        $display(" Activations (%0d,1)", X_SIZE       );
        $display("=================================\n");

        for (int i = 0; i < X_SIZE; i++) 
            $write("%4d (%02h)  ",$signed(X[i]),X[i]);

        $display("\n");
        $display("\n=================================");
        $display(" Weights (%0d,%0d)", X_SIZE, Y_SIZE );
        $display("=================================\n");

        for (int i = 0; i < X_SIZE; i++) begin
            for (int j = 0; j < Y_SIZE; j++) begin
                $write("%4d (%02h)  ", $signed(W[i][j]), W[i][j]);
            end
            $display("");
        end

        $display("");

    endtask

    //=============================================================
    //============================================ PACK X and WRITE
    task pack_X();

        for (int word = 0; word < (X_SIZE+3)/4; word++) begin
            X_MEM[word] = 32'b0;
            for (int byte_idx = 0; byte_idx < 4; byte_idx++) begin
                int index;
                index = word*4 + byte_idx;
                if (index < X_SIZE) X_MEM[word][byte_idx*8 +: 8] = X[index];
            end
        end

    endtask

    task write_X_hex();

        integer fd;
        fd = $fopen(X_HEX_FILE, "w");

        if (fd == 0) begin
            $display("ERRO: nao foi possivel abrir %s",X_HEX_FILE);
            $finish(1);
        end

        for (int i=0; i<X_SIZE; i++) $fdisplay(fd,"%02h",X[i]);

        $fclose(fd);
        $display("Arquivo gerado: %s",X_HEX_FILE);

    endtask

    //=============================================================
    //============================================ PACK W and WRITE
    // Agora invertendo as linhas necessarias

    task pack_W();

        for (int word = 0; word < (X_SIZE*Y_SIZE+3)/4; word++) begin

            W_MEM[word] = 32'b0;
            for (int byte_idx = 0; byte_idx < 4; byte_idx++) begin
                int index, row, col;

                index = word*4 + byte_idx;
                if (index < X_SIZE*Y_SIZE) begin
                    row = index / Y_SIZE;
                    col = index % Y_SIZE;
                    if (row % 2 == 1) col = Y_SIZE - 1 - col; // Inverte linhas impares
                    W_MEM[word][byte_idx*8 +: 8] = W[row][col];
                end

            end

        end

    endtask

    task write_W_hex();

        integer fd;
        fd = $fopen(W_HEX_FILE, "w");

        if (fd == 0) begin
            $display("ERRO: nao foi possivel abrir %s",W_HEX_FILE);
            $finish(1);
        end

        for (int i = 0; i < (X_SIZE*Y_SIZE+3)/4; i++) 
            $fdisplay(fd, "%08h", W_MEM[i]);

        $fclose(fd);
        $display("Arquivo gerado: %s",W_HEX_FILE);

    endtask

    //=============================================================
    // GENERATE HEX FILES
    //=============================================================
    task generate_hex_files();
        $display("\n=================================");
        $display(" Files                             ");
        $display("=================================\n");
        pack_W();
        write_W_hex();
        write_X_hex();
    endtask

    //=============================================================
    // REFERENCE MODEL
    //=============================================================
    task calculate_reference();
        for (int i = 0; i < Y_SIZE; i++) begin
            Y_ref[i] = 0;
            for (int j = 0; j < X_SIZE; j++) begin
                Y_ref[i] += $signed(X[j]) * $signed(W[i][j]);
            end
        end
    endtask

    //=============================================================
    // INITIALIZATION
    //=============================================================

    initial begin

        clk = 0; rstn = 0; 
        enb = 0; done = 0;

        #1ns;

        //---------------------- Generate DATA and print
        generate_random_data();
        print_data();

        //------------------------------ Reference model
        calculate_reference();

        //--------------------------- Generate HEX files
        generate_hex_files();

        //---------------------------------------- Reset
        #39ns;
        rstn = 1;
        #20ns;

        //=========================================================
        // START DUT
        enb = 1; #20ns;
        enb = 0;

    end

    //=============================================================
    // RESULT MONITOR
    //=============================================================

    initial begin

        y_idx = 0;

        // Espera valid
        @(posedge vld_o);

        $display("\n");
        while (y_idx < Y_SIZE) begin
            @(posedge clk);
            if (partial_o) begin
                Y[y_idx] = $signed(acc_o);
                $display("[%0tns] DUT: Y[%0d] = %0d", $time, y_idx, $signed(acc_o));
                y_idx++;
            end
        end

        @(negedge clk); done = 1;

        #1ns;

        $display("");
        $display("==========================================================");
        $display("                        COMPARACAO                        ");
        $display("==========================================================");

        $display("");                     
        $display("----------------------------------------------------");
        $display(" STATUS |   Y index    |     DUT     |     REF     |");
        $display("----------------------------------------------------");
        for (int i = 0; i < Y_SIZE; i++) begin
            if (Y[i] === Y_ref[i]) 
                $display(" PASS   | %d  | %d | %d |", i, Y[i], Y_ref[i]);
            else 
                $display(" ERRO   | %d  | %d | %d |", i, Y[i], Y_ref[i]);
        end
        $display("----------------------------------------------------");
        $display("");

        if (Y == Y_ref) begin
            $display("");
            $display("*************************************");
            $display("         ___  ___   ________         ");
            $display("        / _ \\/ _ | / __/ __/        ");
            $display("       / ___/ __ |_\\ \\_\\ \\       ");
            $display("      /_/  /_/ |_/___/___/           ");
            $display("                                     ");
            $display("*************************************");
        end
        else begin
            $display("");
            $display("*************************************");
            $display("          _______   ______           ");
            $display("         / __/ _ | /  _/ /           ");
            $display("        / _// __ |_/ // /__          ");
            $display("       /_/ /_/ |_/___/____/          ");
            $display("                                     ");
            $display("*************************************");
        end

        $display("");

        repeat(4) @(posedge clk);

        $finish(0);

    end

    //=============================================================
    // TIMEOUT
    //=============================================================

    initial begin
        #15us;
        $error("ERRO: TIMEOUT");
        $finish(2);
    end

endmodule