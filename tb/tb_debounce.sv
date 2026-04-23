/*
 * Módulo:  tb_debounce
 *
 * Descripción: Testbench de verificación para debounce. Implementa una
 *              estructura de tester y scoreboard para validar el comportamiento
 *              del filtro anti-rebote bajo tres escenarios: verificación de
 *              que una señal estable durante MAX_COUNT ciclos se propaga
 *              correctamente en clean_out, verificación de que pulsos cortos
 *              menores a MAX_COUNT ciclos son rechazados como rebote mecánico,
 *              y verificación de que el reset cancela cualquier conteo en curso.
 *
 * Compilar:
 *   iverilog -g2012 -o tb_debounce.vvp tb_debounce.sv debounce.v
 *
 * Ejecutar:
 *   vvp tb_debounce.vvp
 */
`timescale 1ns/1ps
 
module tb_debounce;
 
    localparam MAX = 5;
 
    bit  clk;
    bit  rst;
    bit  noisy_in;
    wire clean_out;
 
    int pass_count = 0;
    int fail_count = 0;
 
    debounce #(.MAX_COUNT(MAX)) u_dut (
        .clk      (clk),
        .rst      (rst),
        .noisy_in (noisy_in),
        .clean_out(clean_out)
    );
 
    initial clk = 1'b0;
    always #5 clk = ~clk;
 
    // Aplica noisy_in y verifica clean_out tras MAX+2 ciclos.
    // Ciclo 1    : deteccion del cambio, contador a cero
    // Ciclos 2-N : acumulacion hasta MAX_COUNT
    // Ciclo N+1  : propagacion a clean_out, punto de verificacion
    task automatic apply_and_check(
        input bit    in_val,
        input bit    exp_out,
        input string descripcion
    );
        noisy_in = in_val;
        repeat (MAX + 2) @(posedge clk); #1;
 
        if (clean_out === exp_out) begin
            $display("  PASS: %-45s | noisy_in=%b clean_out=%b",
                     descripcion, in_val, clean_out);
            pass_count++;
        end else begin
            $error("  FAIL: %-45s | noisy_in=%b got clean_out=%b expected %b",
                   descripcion, in_val, clean_out, exp_out);
            fail_count++;
        end
    endtask
 
    initial begin : tester
        $dumpfile("tb_debounce.vcd");
        $dumpvars(0, tb_debounce);
 
        rst      = 1'b1;
        noisy_in = 1'b0;
        @(posedge clk); @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
 
        // Escenario 1: propagacion correcta de señal estable.
        // Una señal constante durante MAX_COUNT ciclos debe actualizarse
        // en clean_out tanto en la transicion de subida como en la de bajada.
        $display("");
        $display("Escenario 1: propagacion correcta de señal estable");
 
        apply_and_check(1'b0, 1'b0, "noisy_in=0 estable, clean_out debe ser 0");
        apply_and_check(1'b1, 1'b1, "noisy_in=1 estable, clean_out debe ser 1");
        apply_and_check(1'b0, 1'b0, "noisy_in=0 estable, clean_out vuelve a 0");
 
        begin : blk_latencia
            bit snap;
            noisy_in = 1'b1;
            repeat (MAX) @(posedge clk); #1;
            snap = clean_out;
            if (snap === 1'b0) begin
                $display("  PASS: %-45s | clean_out=%b (sin cambio antes de MAX)",
                         "latencia: clean_out no cambia antes de MAX", snap);
                pass_count++;
            end else begin
                $error("  FAIL: %-45s | clean_out=%b esperado 0",
                       "latencia: clean_out no cambia antes de MAX", snap);
                fail_count++;
            end
            repeat (2) @(posedge clk); #1;
            if (clean_out === 1'b1) begin
                $display("  PASS: %-45s | clean_out=%b (propagado tras MAX+2)",
                         "latencia: clean_out cambia tras MAX+2 ciclos", clean_out);
                pass_count++;
            end else begin
                $error("  FAIL: %-45s | clean_out=%b esperado 1",
                       "latencia: clean_out cambia tras MAX+2 ciclos", clean_out);
                fail_count++;
            end
        end : blk_latencia
 
        // Escenario 2: rechazo de pulsos cortos como rebote mecanico.
        // Pulsos de duracion menor a MAX_COUNT ciclos deben ser ignorados
        // y clean_out debe mantenerse en su ultimo valor valido propagado.
        $display("");
        $display("Escenario 2: rechazo de pulsos cortos como rebote mecanico");
 
        apply_and_check(1'b1, 1'b1, "precondicion: clean_out=1 estable");
 
        begin : blk_rebote_simple
            noisy_in = 1'b0;
            repeat (MAX - 1) @(posedge clk);
            noisy_in = 1'b1;
            repeat (MAX + 2) @(posedge clk); #1;
            if (clean_out === 1'b1) begin
                $display("  PASS: %-45s | clean_out=%b (rebote ignorado)",
                         "pulso corto de bajada < MAX ciclos ignorado", clean_out);
                pass_count++;
            end else begin
                $error("  FAIL: %-45s | clean_out=%b esperado 1",
                       "pulso corto de bajada < MAX ciclos ignorado", clean_out);
                fail_count++;
            end
        end : blk_rebote_simple
 
        begin : blk_rebote_multiple
            int i;
            for (i = 0; i < 4; i++) begin
                noisy_in = ~noisy_in;
                repeat (MAX - 1) @(posedge clk);
            end
            noisy_in = 1'b1;
            repeat (MAX + 2) @(posedge clk); #1;
            if (clean_out === 1'b1) begin
                $display("  PASS: %-45s | clean_out=%b (todos los rebotes ignorados)",
                         "multiples rebotes rapidos consecutivos ignorados", clean_out);
                pass_count++;
            end else begin
                $error("  FAIL: %-45s | clean_out=%b esperado 1",
                       "multiples rebotes rapidos consecutivos ignorados", clean_out);
                fail_count++;
            end
        end : blk_rebote_multiple
 
        // Escenario 3: reset cancela conteo en curso.
        // Si rst se activa mientras el contador acumula, clean_out vuelve
        // a cero y el cambio pendiente se descarta por completo.
        $display("");
        $display("Escenario 3: reset cancela conteo en curso");
 
        apply_and_check(1'b0, 1'b0, "precondicion: clean_out=0 estable");
 
        begin : blk_reset_en_conteo
            noisy_in = 1'b1;
            repeat (MAX - 2) @(posedge clk);
            rst = 1'b1;
            @(posedge clk); @(posedge clk);
            rst = 1'b0;
            @(posedge clk); #1;
            if (clean_out === 1'b0) begin
                $display("  PASS: %-45s | clean_out=%b (conteo descartado)",
                         "reset descarta conteo pendiente en curso", clean_out);
                pass_count++;
            end else begin
                $error("  FAIL: %-45s | clean_out=%b esperado 0",
                       "reset descarta conteo pendiente en curso", clean_out);
                fail_count++;
            end
        end : blk_reset_en_conteo
 
        begin : blk_reset_desde_uno
            noisy_in = 1'b1;
            repeat (MAX + 2) @(posedge clk);
            rst = 1'b1;
            @(posedge clk); @(posedge clk);
            rst = 1'b0;
            @(posedge clk); #1;
            if (clean_out === 1'b0) begin
                $display("  PASS: %-45s | clean_out=%b (reset desde clean_out=1)",
                         "reset desde estado propagado fuerza clean_out a 0", clean_out);
                pass_count++;
            end else begin
                $error("  FAIL: %-45s | clean_out=%b esperado 0",
                       "reset desde estado propagado fuerza clean_out a 0", clean_out);
                fail_count++;
            end
        end : blk_reset_desde_uno
 
        $display("");
        $display("================================================");
        $display("   SCOREBOARD FINAL");
        $display("   PASS : %0d", pass_count);
        $display("   FAIL : %0d", fail_count);
        $display("   TOTAL: %0d", pass_count + fail_count);
        $display("================================================");
        if (fail_count == 0)
            $display("   *** Todos los checks pasaron correctamente ***");
        else
            $display("   *** ATENCION: %0d check(s) fallaron ***", fail_count);
        $display("================================================");
 
        $finish;
    end : tester
 
endmodule : tb_debounce
