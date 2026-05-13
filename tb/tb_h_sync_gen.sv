/*
 * Autor:   Jesús Huertas
 * Fecha:   20/04/2026
 *
 * Módulo:  tb_h_sync_gen
 *
 * Descripción: Testbench de verificación para h_sync_gen. Implementa una
 *              estructura de tester y scoreboard para validar el comportamiento
 *              del generador de sincronización horizontal bajo tres escenarios:
 *              operación normal durante múltiples líneas completas, reset
 *              aplicado en un ciclo aleatorio para verificar que el contador
 *              regresa a cero limpiamente, y verificación ciclo a ciclo de
 *              que hsync y hblank coinciden con los rangos definidos por el
 *              estándar VGA 640x480 , 60Hz.
 *
 * Compilar:
 *   iverilog -g2012 -o tb_h_sync_gen.vvp tb_h_sync_gen.sv h_sync_gen.v
 *
 * Ejecutar:
 *   vvp tb_h_sync_gen.vvp
 */

`timescale 1ns/1ps

module tb_h_sync_gen;

    localparam H_VISIBLE    = 640;
    localparam H_SYNC_START = 656;
    localparam H_SYNC_END   = 752;
    localparam H_TOTAL      = 800;
    localparam NUM_LINES    = 5;

    bit        clk;
    bit        rst;
    wire [9:0] hcount;
    wire       hsync;
    wire       hblank;

    bit        check_enable;

    h_sync_gen u_dut (
        .clk    (clk),
        .rst    (rst),
        .hcount (hcount),
        .hsync  (hsync),
        .hblank (hblank)
    );

    initial clk = 1'b0;
    always #20 clk = ~clk;

    initial begin : tester
        $dumpfile("tb_h_sync_gen.vcd");
        $dumpvars(0, tb_h_sync_gen);

        check_enable = 0;
        rst          = 1'b1;

        @(posedge clk);
        @(posedge clk);
        rst = 1'b0;

        $display("Escenario 1: operacion normal %0d lineas", NUM_LINES);
        check_enable = 1;
        repeat (H_TOTAL * NUM_LINES - 1) @(posedge clk);
        check_enable = 0;
        @(posedge clk);

        $display("Escenario 2: reset en ciclo aleatorio");
        begin
            int unsigned rand_cycles;
            rand_cycles = ($urandom % (H_TOTAL - 1)) + 1;
            $display("  Aplicando reset en el ciclo %0d de la linea", rand_cycles);

            repeat (rand_cycles) @(posedge clk);

            rst = 1'b1;
            @(posedge clk);
            #1;
            rst = 1'b0;

            if (hcount === 10'd0)
                $display("  PASS: hcount regreso a 0 tras reset");
            else
                $error("  FAIL: hcount = %0d tras reset, se esperaba 0", hcount);
        end

        $display("Escenario 3: verificacion de rollover 799 a 0");
        rst = 1'b1;
        @(posedge clk);
        rst = 1'b0;

        while (hcount !== 10'd799) @(posedge clk);
        #1;
        $display("  PASS: contador llego a 799 correctamente");

        @(negedge clk);

        if (hcount === 10'd0)
            $display("  PASS: rollover correcto de 799 a 0");
        else
            $error("  FAIL: hcount = %0d tras rollover, se esperaba 0", hcount);

        $display("================================================");
        $display("   Simulacion completada");
        $display("================================================");
        $finish;
    end : tester

    bit [9:0] ref_hcount   = 10'd0;
    bit [9:0] score_hcount = 10'd0;

    always @(posedge clk) begin : ref_model
        if (rst)
            ref_hcount <= 10'd0;
        else if (ref_hcount == H_TOTAL - 1)
            ref_hcount <= 10'd0;
        else
            ref_hcount <= ref_hcount + 10'd1;
    end : ref_model

    always @(negedge clk) begin : scoreboard
        if (check_enable) begin

            if (hcount !== score_hcount)
                $error("FAIL hcount: got %0d expected %0d", hcount, score_hcount);

            if (hsync !== ~((score_hcount >= H_SYNC_START) && (score_hcount < H_SYNC_END)))
                $error("FAIL hsync:  got %0b expected %0b en hcount=%0d",
                       hsync,
                       ~((score_hcount >= H_SYNC_START) && (score_hcount < H_SYNC_END)),
                       hcount);

            if (hblank !== (score_hcount >= H_VISIBLE))
                $error("FAIL hblank: got %0b expected %0b en hcount=%0d",
                       hblank, (score_hcount >= H_VISIBLE), hcount);

            if (hcount === score_hcount &&
                hsync  === ~((score_hcount >= H_SYNC_START) && (score_hcount < H_SYNC_END)) &&
                hblank === (score_hcount >= H_VISIBLE))
                $display("PASS ciclo hcount=%0d hsync=%0b hblank=%0b",
                         hcount, hsync, hblank);
        end

        if (rst)
            score_hcount <= 10'd0;
        else if (score_hcount == H_TOTAL - 1)
            score_hcount <= 10'd0;
        else
            score_hcount <= score_hcount + 10'd1;
    end : scoreboard

endmodule : tb_h_sync_gen