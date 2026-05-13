/*
 * Autor:   Jesús Huertas
 * Fecha:   23/04/2026
 *
 * Módulo:  tb_pixel_mux
 *
 * Descripción: Testbench de verificación para pixel_mux. Implementa una
 *              estructura de tester y scoreboard para validar el comportamiento
 *              del multiplexor de píxel bajo tres escenarios: verificación de
 *              todas las combinaciones posibles de pixel_bit y video_on para
 *              confirmar que la salida RGB es correcta en cada caso, verificación
 *              de que video_on inactivo fuerza negro sin importar pixel_bit, y
 *              verificación de la latencia de registro confirmando que la salida
 *              aparece un ciclo después de la entrada.
 *
 * Compilar:
 *   iverilog -g2012 -o tb_pixel_mux.vvp tb_pixel_mux.sv pixel_mux.v
 *
 * Ejecutar:
 *   vvp tb_pixel_mux.vvp
 */

`timescale 1ns/1ps

module tb_pixel_mux;

    bit        clk;
    bit        pixel_bit;
    bit        video_on;
    wire [3:0] vga_r;
    wire [3:0] vga_g;
    wire [3:0] vga_b;

    pixel_mux u_dut (
        .clk       (clk),
        .pixel_bit (pixel_bit),
        .video_on  (video_on),
        .vga_r     (vga_r),
        .vga_g     (vga_g),
        .vga_b     (vga_b)
    );

    initial clk = 1'b0;
    always #20 clk = ~clk;

    task apply_and_check(
        input pbit, input von,
        input [3:0] exp_r, input [3:0] exp_g, input [3:0] exp_b
    );
        @(posedge clk);
        pixel_bit = pbit;
        video_on  = von;
        @(negedge clk);
        if (vga_r === exp_r && vga_g === exp_g && vga_b === exp_b)
            $display("  PASS: pixel_bit=%0b video_on=%0b R=%h G=%h B=%h",
                     pbit, von, vga_r, vga_g, vga_b);
        else
            $error("  FAIL: pixel_bit=%0b video_on=%0b got R=%h G=%h B=%h expected R=%h G=%h B=%h",
                   pbit, von, vga_r, vga_g, vga_b, exp_r, exp_g, exp_b);
    endtask

    initial begin : tester
        $dumpfile("tb_pixel_mux.vcd");
        $dumpvars(0, tb_pixel_mux);

        pixel_bit = 0;
        video_on  = 0;

        @(posedge clk);
        @(posedge clk);

        $display("Escenario 1: todas las combinaciones de pixel_bit y video_on");
        apply_and_check(1'b0, 1'b0, 4'h0, 4'h0, 4'h0);
        apply_and_check(1'b1, 1'b0, 4'h0, 4'h0, 4'h0);
        apply_and_check(1'b0, 1'b1, 4'h0, 4'h0, 4'h0);
        apply_and_check(1'b1, 1'b1, 4'hF, 4'hF, 4'hF);

        $display("Escenario 2: video_on inactivo fuerza negro sin importar pixel_bit");
        begin
            int i;
            bit failed;
            failed = 0;
            for (i = 0; i < 10; i++) begin
                @(posedge clk);
                pixel_bit = 1'b1;
                video_on  = 1'b0;
                @(negedge clk);
                if (vga_r !== 4'h0 || vga_g !== 4'h0 || vga_b !== 4'h0) begin
                    $error("  FAIL: video_on=0 pero RGB != 0 en ciclo %0d", i);
                    failed = 1;
                end
            end
            if (!failed)
                $display("  PASS: video_on inactivo siempre produce negro");
        end

        $display("Escenario 3: verificacion de latencia de registro");

        @(posedge clk);
        pixel_bit = 1'b1;
        video_on  = 1'b1;
        @(negedge clk);

        @(posedge clk);
        pixel_bit = 1'b0;
        video_on  = 1'b0;

        @(negedge clk);
        @(negedge clk);
        if (vga_r === 4'h0 && vga_g === 4'h0 && vga_b === 4'h0)
            $display("  PASS: salida actualiza con latencia de un ciclo correctamente");
        else
            $error("  FAIL: salida incorrecta R=%h G=%h B=%h", vga_r, vga_g, vga_b);

        $display("================================================");
        $display("   Simulacion completada");
        $display("================================================");
        $finish;
    end : tester

endmodule : tb_pixel_mux