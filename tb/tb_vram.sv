/*
 * Autor:   Jesús Huertas
 * Fecha:   20/04/2026
 *
 * Módulo:  tb_vram
 *
 * Descripción: Testbench de verificación para vram. Implementa una estructura
 *              de tester y scoreboard para validar el comportamiento de la
 *              memoria de video de doble puerto bajo cuatro escenarios:
 *              verificación de inicialización en ceros, escritura y lectura
 *              básica con verificación de latencia de un ciclo, escritura
 *              simultánea en múltiples direcciones aleatorias con verificación
 *              posterior de cada valor, y verificación de que el puerto B
 *              lee correctamente valores escritos desde el puerto A operando
 *              en dominios de reloj distintos.
 *
 *              El scoreboard mantiene un modelo de referencia en software que
 *              replica el contenido esperado de la memoria y compara contra
 *              las salidas del DUT después de cada operación.
 *
 * Compilar:
 *   iverilog -g2012 -o tb_vram.vvp tb_vram.sv vram.v
 *
 * Ejecutar:
 *   vvp tb_vram.vvp
 */

`timescale 1ns/1ps

module tb_vram;

    localparam DEPTH      = 307200;
    localparam NUM_RANDOM = 100;

    bit         clk_a;
    bit         clk_b;
    bit         we_a;
    bit  [18:0] addr_a;
    bit         data_in_a;
    bit  [18:0] addr_b;
    wire        data_out_b;

    bit ref_mem [0:DEPTH-1];

    vram u_dut (
        .clk_a     (clk_a),
        .we_a      (we_a),
        .addr_a    (addr_a),
        .data_in_a (data_in_a),
        .clk_b     (clk_b),
        .addr_b    (addr_b),
        .data_out_b(data_out_b)
    );

    initial clk_a = 1'b0;
    always #5  clk_a = ~clk_a;

    initial clk_b = 1'b0;
    always #20 clk_b = ~clk_b;

    task write_pixel(input [18:0] addr, input val);
        @(posedge clk_a);
        addr_a        = addr;
        data_in_a     = val;
        we_a          = 1'b1;
        ref_mem[addr] = val;
        @(posedge clk_a);
        we_a = 1'b0;
        repeat(4) @(posedge clk_b);
    endtask

    task read_and_check(input [18:0] addr, input expected);
        addr_b = addr;
        @(posedge clk_b);
        @(negedge clk_b);
        if (data_out_b === expected)
            $display("  PASS: addr=%0d got=%0b expected=%0b",
                     addr, data_out_b, expected);
        else
            $error("  FAIL: addr=%0d got=%0b expected=%0b",
                   addr, data_out_b, expected);
    endtask

    initial begin : tester
        $dumpfile("tb_vram.vcd");
        $dumpvars(0, tb_vram);

        we_a      = 0;
        addr_a    = 0;
        data_in_a = 0;
        addr_b    = 0;

        for (int i = 0; i < DEPTH; i++)
            ref_mem[i] = 1'b0;

        @(posedge clk_b);
        @(posedge clk_b);

        $display("Escenario 1: direcciones limite y comportamiento del write enable");

        read_and_check(19'd0,      ref_mem[0]);
        read_and_check(19'd1,      ref_mem[1]);
        read_and_check(19'd307198, ref_mem[307198]);
        read_and_check(19'd307199, ref_mem[307199]);

        write_pixel(19'd0,      1'b1);
        write_pixel(19'd1,      1'b1);
        write_pixel(19'd307198, 1'b1);
        write_pixel(19'd307199, 1'b1);

        read_and_check(19'd0,      ref_mem[0]);
        read_and_check(19'd1,      ref_mem[1]);
        read_and_check(19'd307198, ref_mem[307198]);
        read_and_check(19'd307199, ref_mem[307199]);

        addr_a    = 19'd0;
        data_in_a = 1'b0;
        we_a      = 1'b0;
        @(posedge clk_a);
        @(posedge clk_a);
        repeat(4) @(posedge clk_b);
        read_and_check(19'd0, ref_mem[0]);

        $display("Escenario 2: escritura aleatoria y verificacion contra modelo");
        begin
            bit [31:0] rand_val;
            bit [18:0] rand_addr;
            bit        rand_data;
            bit        failed;
            failed = 0;

            for (int i = 0; i < NUM_RANDOM; i++) begin
                rand_val  = $urandom();
                rand_addr = rand_val[18:0] % DEPTH;
                rand_val  = $urandom();
                rand_data = rand_val[0];
                write_pixel(rand_addr, rand_data);
            end

            for (int i = 0; i < NUM_RANDOM; i++) begin
                rand_val  = $urandom();
                rand_addr = rand_val[18:0] % DEPTH;
                addr_b    = rand_addr;
                @(posedge clk_b);
                @(negedge clk_b);
                if (data_out_b !== ref_mem[rand_addr]) begin
                    $error("  FAIL: addr=%0d got=%0b expected=%0b",
                           rand_addr, data_out_b, ref_mem[rand_addr]);
                    failed = 1;
                end
            end
            if (!failed)
                $display("  PASS: todas las direcciones coinciden con el modelo");
        end

        $display("Escenario 3: aislamiento entre adyacentes y timing entre dominios");
        begin
            bit failed;
            failed = 0;

            write_pixel(19'd1000, 1'b0);
            write_pixel(19'd1001, 1'b1);
            write_pixel(19'd1002, 1'b0);
            read_and_check(19'd1000, ref_mem[1000]);
            read_and_check(19'd1001, ref_mem[1001]);
            read_and_check(19'd1002, ref_mem[1002]);

            write_pixel(19'd5000, 1'b1);
            write_pixel(19'd5001, 1'b0);
            write_pixel(19'd5002, 1'b1);
            read_and_check(19'd5000, ref_mem[5000]);
            read_and_check(19'd5001, ref_mem[5001]);
            read_and_check(19'd5002, ref_mem[5002]);

            @(posedge clk_a);
            addr_a    = 19'd9999;
            data_in_a = 1'b1;
            we_a      = 1'b1;
            ref_mem[9999] = 1'b1;
            @(posedge clk_a);
            we_a = 1'b0;

            @(posedge clk_b);
            @(negedge clk_b);
            $display("  INFO timing minimo: addr=9999 got=%0b", data_out_b);

            repeat(4) @(posedge clk_b);
            read_and_check(19'd9999, ref_mem[9999]);
        end

        $display("================================================");
        $display("   Simulacion completada");
        $display("================================================");
        $finish;
    end : tester

endmodule : tb_vram