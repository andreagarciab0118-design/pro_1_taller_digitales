/*
 * Módulo:  tb_edge_detector
 *
 * Descripción: Testbench de verificación para edge_detector. Implementa una
 *              estructura de tester y scoreboard para validar el comportamiento
 *              del detector de flanco bajo tres escenarios: verificación de
 *              que un flanco de subida genera exactamente un pulso de un ciclo,
 *              verificación de que el flanco de bajada y el nivel sostenido no
 *              generan pulso adicional, y verificación del comportamiento ante
 *              múltiples flancos consecutivos y reset en medio de operación.
 *
 * Compilar:
 *   iverilog -g2012 -o tb_edge_detector.vvp tb_edge_detector.sv edge_detector.v
 *
 * Ejecutar:
 *   vvp tb_edge_detector.vvp
 */
`timescale 1ns/1ps
 
module tb_edge_detector;
 
    bit  clk;
    bit  rst;
    bit  signal_in;
    wire pulse_out;
 
    int pass_count = 0;
    int fail_count = 0;
 
    edge_detector u_dut (
        .clk       (clk),
        .rst       (rst),
        .signal_in (signal_in),
        .pulse_out (pulse_out)
    );
 
    initial clk = 1'b0;
    always #5 clk = ~clk;
 
    // Aplica signal_in y verifica pulse_out un ciclo despues.
    // El modulo registra en posedge, pulse_out refleja el flanco detectado
    // en el ciclo inmediatamente siguiente al cambio de entrada.
    task automatic apply_and_check(
        input bit    in_val,
        input bit    exp_pulse,
        input string descripcion
    );
        signal_in = in_val;
        @(posedge clk); #1;
 
        if (pulse_out === exp_pulse) begin
            $display("  PASS: %-45s | signal_in=%b pulse_out=%b",
                     descripcion, in_val, pulse_out);
            pass_count++;
        end else begin
            $error("  FAIL: %-45s | signal_in=%b got pulse_out=%b expected %b",
                   descripcion, in_val, pulse_out, exp_pulse);
            fail_count++;
        end
    endtask
 
    initial begin : tester
        $dumpfile("tb_edge_detector.vcd");
        $dumpvars(0, tb_edge_detector);
 
        rst       = 1'b1;
        signal_in = 1'b0;
        @(posedge clk); @(posedge clk);
        rst = 1'b0;
        @(posedge clk); #1;
 
        // Escenario 1: flanco de subida genera pulso de exactamente un ciclo.
        // La transicion de 0 a 1 debe producir pulse_out=1 durante un unico
        // ciclo y volver a 0 en el siguiente sin actividad adicional.
        $display("");
        $display("Escenario 1: flanco de subida genera pulso de un ciclo");
 
        apply_and_check(1'b0, 1'b0, "signal_in=0 estable, sin flanco, pulse_out=0");
        apply_and_check(1'b1, 1'b1, "flanco 0 a 1, pulse_out=1 en ciclo del flanco");
        apply_and_check(1'b1, 1'b0, "signal_in=1 sostenido ciclo 1, pulse_out vuelve a 0");
        apply_and_check(1'b1, 1'b0, "signal_in=1 sostenido ciclo 2, pulse_out=0");
 
        // Escenario 2: flanco de bajada y nivel sostenido no generan pulso.
        // La transicion de 1 a 0 no debe producir pulso. La señal baja
        // sostenida tampoco debe generar actividad en pulse_out.
        $display("");
        $display("Escenario 2: flanco de bajada y nivel sostenido no generan pulso");
 
        apply_and_check(1'b0, 1'b0, "flanco 1 a 0, pulse_out debe ser 0");
        apply_and_check(1'b0, 1'b0, "signal_in=0 sostenido ciclo 1, pulse_out=0");
        apply_and_check(1'b0, 1'b0, "signal_in=0 sostenido ciclo 2, pulse_out=0");
 
        begin : blk_sostenido_alto
            int i;
            bit fallo;
            fallo = 0;
            signal_in = 1'b1;
            @(posedge clk);           // ciclo del flanco: pulse_out=1
            @(posedge clk); #1;       // ciclo siguiente: pulse_out vuelve a 0
            for (i = 0; i < 6; i++) begin
                if (pulse_out !== 1'b0) begin
                    $error("  FAIL: glitch pulse_out=%b en ciclo sostenido %0d (esperado 0)",
                           pulse_out, i);
                    fallo = 1;
                    fail_count++;
                end
                @(posedge clk); #1;
            end
            if (!fallo) begin
                $display("  PASS: %-45s | pulse_out=0 estable 6 ciclos",
                         "sin glitches con signal_in=1 sostenido");
                pass_count++;
            end
        end : blk_sostenido_alto
 
        // Escenario 3: multiples flancos consecutivos y reset en operacion.
        // Cada transicion de 0 a 1 debe generar un pulso independiente.
        // El reset debe limpiar la salida de inmediato sin pulso residual.
        $display("");
        $display("Escenario 3: multiples flancos consecutivos y reset");
 
        apply_and_check(1'b0, 1'b0, "precondicion: signal_in=0, pulse_out=0");
        apply_and_check(1'b1, 1'b1, "flanco 1: pulse_out=1");
        apply_and_check(1'b0, 1'b0, "bajada entre flancos: pulse_out=0");
        apply_and_check(1'b1, 1'b1, "flanco 2: pulse_out=1");
        apply_and_check(1'b0, 1'b0, "bajada entre flancos: pulse_out=0");
        apply_and_check(1'b1, 1'b1, "flanco 3: pulse_out=1");
 
        begin : blk_reset
            signal_in = 1'b1;
            rst = 1'b1;
            @(posedge clk); #1;
            if (pulse_out === 1'b0) begin
                $display("  PASS: %-45s | pulse_out=%b (reset limpia salida)",
                         "reset activo fuerza pulse_out a 0", pulse_out);
                pass_count++;
            end else begin
                $error("  FAIL: %-45s | pulse_out=%b esperado 0",
                       "reset activo fuerza pulse_out a 0", pulse_out);
                fail_count++;
            end
            rst = 1'b0;
            signal_in = 1'b0;
            @(posedge clk); #1;
            if (pulse_out === 1'b0) begin
                $display("  PASS: %-45s | pulse_out=%b (sin pulso espurio)",
                         "post-reset sin pulso espurio en salida", pulse_out);
                pass_count++;
            end else begin
                $error("  FAIL: %-45s | pulse_out=%b esperado 0",
                       "post-reset sin pulso espurio en salida", pulse_out);
                fail_count++;
            end
        end : blk_reset
 
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
 
endmodule : tb_edge_detector
