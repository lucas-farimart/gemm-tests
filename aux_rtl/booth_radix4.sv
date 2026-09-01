//=====================================================================
// Testbench: Booth algorithm for 8b multiplication 
// Description: vou ficar devendo
//---------------------------------------------------------------------
// Author: Lucas Farias Martins
// Email:  lucas.martins@ee.ufcg.edu.br
// Date:   07/05/2026
//=====================================================================

module booth_radix4 (
    input  logic               clk,
    input  logic               rstn,
    input  logic               valid_in,
    output logic               valid_out,
    input  logic signed  [7:0] a,
    input  logic signed  [7:0] b,
    output logic signed [15:0] p
);

    logic               valid_s1;
    logic               valid_s2;
    logic signed [15:0] pp0_s1, pp0_r;
    logic signed [15:0] pp1_s1, pp1_r;
    logic signed [15:0] pp2_s1, pp2_r;
    logic signed [15:0] pp3_s1, pp3_r;
    logic signed [15:0] sum_s2;
    logic signed [15:0] p_r;
    logic         [8:0] b_ext;

    //-------------------------------------------------
    // STAGE 1
    //-------------------------------------------------
    always_comb begin
        b_ext = {b,1'b0};
        pp0_s1 = booth_pp(a, b_ext[2:0], 0);
        pp1_s1 = booth_pp(a, b_ext[4:2], 2);
        pp2_s1 = booth_pp(a, b_ext[6:4], 4);
        pp3_s1 = booth_pp(a, b_ext[8:6], 6);
    end

    //-------------------------------------------------
    // PIPE REG 1
    //-------------------------------------------------
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            pp0_r    <= '0;
            pp1_r    <= '0;
            pp2_r    <= '0;
            pp3_r    <= '0;
            valid_s1 <= 1'b0;
        end
        else begin
            pp0_r    <= pp0_s1;
            pp1_r    <= pp1_s1;
            pp2_r    <= pp2_s1;
            pp3_r    <= pp3_s1;
            valid_s1 <= valid_in;
        end
    end

    //-------------------------------------------------
    // STAGE 2
    //-------------------------------------------------
    always_comb sum_s2 = pp0_r + pp1_r + pp2_r + pp3_r;

    //-------------------------------------------------
    // PIPE REG 2
    //-------------------------------------------------
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            p_r       <= '0;
            valid_s2  <= 1'b0;
        end
        else begin
            p_r       <= sum_s2;
            valid_s2  <= valid_s1;
        end
    end

    //-------------------------------------------------
    // OUTPUTS
    //-------------------------------------------------
    always_comb p = p_r;
    always_comb valid_out = valid_s2;

    //-------------------------------------------------
    // BOOTH FUNCTION
    //-------------------------------------------------
    function automatic signed [15:0] booth_pp (
        input signed [7:0] multiplicand,
        input        [2:0] booth_bits,
        input integer      shift
    );
        logic signed [15:0] m;

        case (booth_bits)
            3'b000,3'b111: booth_pp = 16'sd0;
            3'b001,3'b010: booth_pp =  (multiplicand <<< shift);
            3'b011:        booth_pp =  (multiplicand <<< 1) <<< shift;
            3'b100:        booth_pp = -((multiplicand <<< 1) <<< shift);
            3'b101,3'b110: booth_pp = -(multiplicand <<< shift);
            // default:       booth_pp = 16'sd0;
        endcase

    endfunction

endmodule