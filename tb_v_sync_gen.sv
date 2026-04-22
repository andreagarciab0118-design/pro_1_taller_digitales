/*
 * Autor:   Jesús Huertas
 * Fecha:   20/04/2026
 *
 * Módulo:  tb_v_sync_gen
 *
 * Descripción: Testbench que prueba el v_sync_gen usando un h_sync_gen real 
 *              (no simulado), para verificar que ambos módulos funcionan correctamente 
 *              juntos, igual que en el hardware real.
 *
 *              Se verifican tres escenarios: operación normal durante múltiples
 *              cuadros completos comprobando por línea que vcount, vsync y
 *              vblank coinciden con el estándar VGA 640x480 , 60Hz, reset
 *              aplicado en una línea aleatoria para verificar que vcount regresa
 *              a cero limpiamente, y verificación del rollover de 524 a 0 con
 *              timeout de seguridad para detectar ciclos infinitos.
 *
 * Compilar:
 *   iverilog -g2012 -o tb_v_sync_gen.vvp tb_v_sync_gen.sv v_sync_gen.v h_sync_gen.v
 *
 * Ejecutar:
 *   vvp tb_v_sync_gen.vvp
 */

`timescale 1ns/1ps

module tb_v_sync_gen;

    localparam H_TOTAL      = 800;
    localparam V_VISIBLE    = 480;
    localparam V_SYNC_START = 490;
    localparam V_SYNC_END   = 492;
    localparam V_TOTAL      = 525;
    localparam NUM_FRAMES   = 2;

    bit        clk;
    bit        rst;
    wire       h_end;
    wire [9:0] hcount;
    wire       hsync;
    wire       hblank;
    wire [9:0] vcount;
    wire       vsync;
    wire       vblank;

    bit        check_enable;

    h_sync_gen u_h_sync (
        .clk    (clk),
        .rst    (rst),
        .hcount (hcount),
        .hsync  (hsync),
        .hblank (hblank),
        .h_end  (h_end)
    );

    v_sync_gen u_dut (
        .clk    (clk),
        .rst    (rst),
        .h_end  (h_end),
        .vcount (vcount),
        .vsync  (vsync),
        .vblank (vblank)
    );

    initial clk = 1'b0;
    always #20 clk = ~clk;

    initial begin : tester
        $dumpfile("tb_v_sync_gen.vcd");
        $dumpvars(0, tb_v_sync_gen);

        check_enable = 0;
        rst          = 1'b1;

        @(posedge clk);
        @(posedge clk);
        rst = 1'b0;

        $display("Escenario 1: operacion normal %0d cuadros", NUM_FRAMES);
        check_enable = 1;
        repeat (H_TOTAL * V_TOTAL * NUM_FRAMES - 1) @(posedge clk);
        check_enable = 0;
        @(posedge clk);

        $display("Escenario 2: reset en linea aleatoria");
        begin
            int unsigned rand_lines;
            rand_lines = ($urandom % (V_TOTAL - 1)) + 1;
            $display("  Aplicando reset en la linea %0d del cuadro", rand_lines);

            repeat (rand_lines * H_TOTAL) @(posedge clk);

            rst = 1'b1;
            @(posedge clk);
            #1;
            rst = 1'b0;

            if (vcount === 10'd0)
                $display("  PASS: vcount regreso a 0 tras reset");
            else
                $error("  FAIL: vcount = %0d tras reset, se esperaba 0", vcount);
        end

        $display("Escenario 3: verificacion de rollover 524 a 0");
        rst = 1'b1;
        @(posedge clk);
        rst = 1'b0;

        fork
            begin
                while (vcount !== 10'd524) @(posedge clk);
                #1;
                $display("  PASS: vcount llego a 524 correctamente");

                // esperamos el proximo h_end donde ocurre el rollover
                while (!h_end) @(posedge clk);
                @(negedge clk);

                if (vcount === 10'd0)
                $display("  PASS: todas correctas de 524 a 0");
                else
                $error("  FAIL: vcount = %0d tras rollover, se esperaba 0", vcount);
            end
            begin
                repeat (H_TOTAL * V_TOTAL + 100) @(posedge clk);
                $error("  TIMEOUT: vcount nunca llego a 524");
            end
        join_any
        disable fork;

        $display("================================================");
        $display("   Simulacion completada");
        $display("================================================");
        $finish;
    end : tester

    bit [9:0] score_vcount = 10'd0;
    bit       h_end_prev   = 1'b0;

    always @(negedge clk) begin : scoreboard
    if (check_enable) begin
        if (h_end) begin
            if (vcount !== score_vcount)
                $error("FAIL vcount: got %0d expected %0d", vcount, score_vcount);

            if (vsync !== ~((score_vcount >= V_SYNC_START) && (score_vcount < V_SYNC_END)))
                $error("FAIL vsync:  got %0b expected %0b en vcount=%0d",
                       vsync,
                       ~((score_vcount >= V_SYNC_START) && (score_vcount < V_SYNC_END)),
                       vcount);

            if (vblank !== (score_vcount >= V_VISIBLE))
                $error("FAIL vblank: got %0b expected %0b en vcount=%0d",
                       vblank, (score_vcount >= V_VISIBLE), vcount);

            if (vcount === score_vcount &&
                vsync  === ~((score_vcount >= V_SYNC_START) && (score_vcount < V_SYNC_END)) &&
                vblank === (score_vcount >= V_VISIBLE))
                $display("PASS linea vcount=%0d vsync=%0b vblank=%0b",
                         vcount, vsync, vblank);

            if (score_vcount == V_TOTAL - 1)
                score_vcount <= 10'd0;
            else
                score_vcount <= score_vcount + 10'd1;
        end

        if (rst)
            score_vcount <= 10'd0;
    end else begin
        if (rst)
            score_vcount <= 10'd0;
    end
end : scoreboard

endmodule : tb_v_sync_gen