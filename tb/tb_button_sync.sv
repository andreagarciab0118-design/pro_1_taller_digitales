/*
 * Autor:   Andrea García Borges
 * Fecha:   23/04/2026
 *
 * Módulo:  tb_button_sync
 *
 * Descripción: Testbench de verificación para button_sync. Implementa una
 *              estructura de tester y scoreboard para validar el comportamiento
 *              del sincronizador de dos flip-flops bajo tres escenarios:
 *              verificación de propagación correcta de nivel alto y bajo,
 *              verificación de la latencia de registro ciclo a ciclo, y
 *              verificación de estabilidad ante señal sostenida sin glitches.
 *
 * Compilar:
 *   iverilog -g2012 -o tb_button_sync.vvp tb_button_sync.sv button_sync.v
 *
 * Ejecutar:
 *   vvp tb_button_sync.vvp
 */
`timescale 1ns/1ps
 
module tb_button_sync;
 
    bit  clk;
    bit  btn_in;
    wire btn_sync;
 
    int pass_count = 0;
    int fail_count = 0;
 
    button_sync u_dut (
        .clk     (clk),
        .btn_in  (btn_in),
        .btn_sync(btn_sync)
    );
 
    initial clk = 1'b0;
    always #5 clk = ~clk;
 
    // Aplica btn_in y verifica btn_sync exactamente dos ciclos despues.
    // Ciclo 1: ff1 captura btn_in
    // Ciclo 2: btn_sync captura ff1, punto de verificacion
    task automatic apply_and_check(
        input bit    in_val,
        input bit    exp_sync,
        input string descripcion
    );
        btn_in = in_val;
        @(posedge clk);
        @(posedge clk); #1;
 
        if (btn_sync === exp_sync) begin
            $display("  PASS: %-45s | btn_in=%b btn_sync=%b",
                     descripcion, in_val, btn_sync);
            pass_count++;
        end else begin
            $error("  FAIL: %-45s | btn_in=%b got btn_sync=%b expected %b",
                   descripcion, in_val, btn_sync, exp_sync);
            fail_count++;
        end
    endtask
 
    initial begin : tester
        $dumpfile("tb_button_sync.vcd");
        $dumpvars(0, tb_button_sync);
 
        btn_in = 1'b0;
        @(posedge clk);
        @(posedge clk);
 
        // Escenario 1: propagacion correcta de nivel alto y nivel bajo.
        // Confirma que btn_sync refleja btn_in exactamente dos ciclos despues.
        $display("");
        $display("Escenario 1: propagacion correcta de nivel alto y nivel bajo");
 
        apply_and_check(1'b0, 1'b0, "btn_in=0, btn_sync debe ser 0");
        apply_and_check(1'b1, 1'b1, "btn_in=1, btn_sync debe ser 1");
        apply_and_check(1'b0, 1'b0, "btn_in=0, btn_sync vuelve a 0");
        apply_and_check(1'b1, 1'b1, "btn_in=1, btn_sync vuelve a 1");
 
        // Escenario 2: latencia de registro ciclo a ciclo.
        // La salida NO cambia en el primer ciclo tras el cambio de entrada
        // y SI cambia en el segundo, verificando latencia de exactamente 2 posedges.
        $display("");
        $display("Escenario 2: latencia de registro ciclo a ciclo");
 
        apply_and_check(1'b0, 1'b0, "precondicion: btn_sync=0 estable");
 
        begin : blk_latencia_subida
            bit snap;
            btn_in = 1'b1;
            @(posedge clk); #1;
            snap = btn_sync;
            if (snap === 1'b0) begin
                $display("  PASS: %-45s | btn_sync=%b (sin cambio en ciclo 1)",
                         "latencia subida: ciclo 1", snap);
                pass_count++;
            end else begin
                $error("  FAIL: %-45s | btn_sync=%b esperado 0",
                       "latencia subida: ciclo 1", snap);
                fail_count++;
            end
            @(posedge clk); #1;
            if (btn_sync === 1'b1) begin
                $display("  PASS: %-45s | btn_sync=%b (actualizado en ciclo 2)",
                         "latencia subida: ciclo 2", btn_sync);
                pass_count++;
            end else begin
                $error("  FAIL: %-45s | btn_sync=%b esperado 1",
                       "latencia subida: ciclo 2", btn_sync);
                fail_count++;
            end
        end : blk_latencia_subida
 
        begin : blk_latencia_bajada
            bit snap;
            btn_in = 1'b0;
            @(posedge clk); #1;
            snap = btn_sync;
            if (snap === 1'b1) begin
                $display("  PASS: %-45s | btn_sync=%b (sin cambio en ciclo 1)",
                         "latencia bajada: ciclo 1", snap);
                pass_count++;
            end else begin
                $error("  FAIL: %-45s | btn_sync=%b esperado 1",
                       "latencia bajada: ciclo 1", snap);
                fail_count++;
            end
            @(posedge clk); #1;
            if (btn_sync === 1'b0) begin
                $display("  PASS: %-45s | btn_sync=%b (actualizado en ciclo 2)",
                         "latencia bajada: ciclo 2", btn_sync);
                pass_count++;
            end else begin
                $error("  FAIL: %-45s | btn_sync=%b esperado 0",
                       "latencia bajada: ciclo 2", btn_sync);
                fail_count++;
            end
        end : blk_latencia_bajada
 
        // Escenario 3: estabilidad ante señal sostenida.
        // btn_sync no debe generar glitches cuando btn_in permanece constante
        // durante multiples ciclos, tanto en nivel alto como en nivel bajo.
        $display("");
        $display("Escenario 3: estabilidad ante señal sostenida (sin glitches)");
 
        begin : blk_estabilidad_alta
            int i;
            bit fallo;
            fallo = 0;
            btn_in = 1'b1;
            @(posedge clk); @(posedge clk); #1;
            for (i = 0; i < 8; i++) begin
                if (btn_sync !== 1'b1) begin
                    $error("  FAIL: glitch btn_sync=%b en ciclo %0d (esperado 1)",
                           btn_sync, i);
                    fallo = 1;
                    fail_count++;
                end
                @(posedge clk); #1;
            end
            if (!fallo) begin
                $display("  PASS: %-45s | btn_sync=1 estable 8 ciclos",
                         "sin glitches con btn_in=1 sostenido");
                pass_count++;
            end
        end : blk_estabilidad_alta
 
        begin : blk_estabilidad_baja
            int i;
            bit fallo;
            fallo = 0;
            btn_in = 1'b0;
            @(posedge clk); @(posedge clk); #1;
            for (i = 0; i < 8; i++) begin
                if (btn_sync !== 1'b0) begin
                    $error("  FAIL: glitch btn_sync=%b en ciclo %0d (esperado 0)",
                           btn_sync, i);
                    fallo = 1;
                    fail_count++;
                end
                @(posedge clk); #1;
            end
            if (!fallo) begin
                $display("  PASS: %-45s | btn_sync=0 estable 8 ciclos",
                         "sin glitches con btn_in=0 sostenido");
                pass_count++;
            end
        end : blk_estabilidad_baja
 
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
 
endmodule : tb_button_sync
