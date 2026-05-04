/*
 * Autor:   Andrea García Borges
 * Fecha:   23/04/2026
 *
 * Módulo:  tb_clock_counter
 *
 * Descripción: Testbench de verificación para clock_counter. Implementa una
 *              estructura de tester y scoreboard para validar el comportamiento
 *              del módulo de reloj bajo tres escenarios: verificación del conteo
 *              normal de segundos, minutos y horas con sus rollovers en cadena,
 *              verificación del modo ajuste mediante botones confirmando que cada
 *              pulsación limpia incrementa correctamente y que el debounce rechaza
 *              el rebote mecánico, y verificación de que los segundos se congelan
 *              durante el modo ajuste y reanudan al volver al modo normal.
 *
 * Compilar:
 *   iverilog -g2012 -o tb_clock_counter.vvp tb/tb_clock_counter.sv
 *            src/clock_counter.v src/button_sync.v src/debounce.v src/edge_detector.v
 *
 * Ejecutar:
 *   vvp tb_clock_counter.vvp
 */
`timescale 1ns/1ps
 
module tb_clock_counter;
 
    localparam CLK_F = 12;
    localparam DEB   = 3;
 
    bit        clk;
    bit        rst;
    bit        sw_adjust;
    bit        btn_inc_hour;
    bit        btn_inc_min;
    wire [3:0] hour;
    wire [5:0] minute;
    wire [5:0] second;
 
    int pass_count = 0;
    int fail_count = 0;
 
    clock_counter #(.CLK_FREQ(CLK_F), .DEBOUNCE_MAX(DEB)) u_dut (
        .clk         (clk),
        .rst         (rst),
        .sw_adjust   (sw_adjust),
        .btn_inc_hour(btn_inc_hour),
        .btn_inc_min (btn_inc_min),
        .hour        (hour),
        .minute      (minute),
        .second      (second)
    );
 
    initial clk = 1'b0;
    always #5 clk = ~clk;
 
    // Avanza n segundos en modo normal y verifica la hora resultante.
    task automatic advance_and_check(
        input int    n,
        input [3:0]  exp_h,
        input [5:0]  exp_m,
        input [5:0]  exp_s,
        input string descripcion
    );
        repeat (n * CLK_F) @(posedge clk); #1;
        if (hour === exp_h && minute === exp_m && second === exp_s) begin
            $display("  PASS: %-45s | %02d:%02d:%02d",
                     descripcion, hour, minute, second);
            pass_count++;
        end else begin
            $error("  FAIL: %-45s | got %02d:%02d:%02d expected %02d:%02d:%02d",
                   descripcion, hour, minute, second, exp_h, exp_m, exp_s);
            fail_count++;
        end
    endtask
 
    // Pulsa btn_inc_min una vez y verifica la hora resultante.
    task automatic press_min_and_check(
        input [3:0]  exp_h,
        input [5:0]  exp_m,
        input [5:0]  exp_s,
        input string descripcion
    );
        btn_inc_min = 1'b1; repeat (DEB + 4) @(posedge clk);
        btn_inc_min = 1'b0; repeat (DEB + 4) @(posedge clk); #1;
        if (hour === exp_h && minute === exp_m && second === exp_s) begin
            $display("  PASS: %-45s | %02d:%02d:%02d",
                     descripcion, hour, minute, second);
            pass_count++;
        end else begin
            $error("  FAIL: %-45s | got %02d:%02d:%02d expected %02d:%02d:%02d",
                   descripcion, hour, minute, second, exp_h, exp_m, exp_s);
            fail_count++;
        end
    endtask
 
    // Pulsa btn_inc_hour una vez y verifica la hora resultante.
    task automatic press_hour_and_check(
        input [3:0]  exp_h,
        input [5:0]  exp_m,
        input [5:0]  exp_s,
        input string descripcion
    );
        btn_inc_hour = 1'b1; repeat (DEB + 4) @(posedge clk);
        btn_inc_hour = 1'b0; repeat (DEB + 4) @(posedge clk); #1;
        if (hour === exp_h && minute === exp_m && second === exp_s) begin
            $display("  PASS: %-45s | %02d:%02d:%02d",
                     descripcion, hour, minute, second);
            pass_count++;
        end else begin
            $error("  FAIL: %-45s | got %02d:%02d:%02d expected %02d:%02d:%02d",
                   descripcion, hour, minute, second, exp_h, exp_m, exp_s);
            fail_count++;
        end
    endtask
 
    initial begin : tester
        $dumpfile("tb_clock_counter.vcd");
        $dumpvars(0, tb_clock_counter);
 
        rst          = 1'b1;
        sw_adjust    = 1'b0;
        btn_inc_hour = 1'b0;
        btn_inc_min  = 1'b0;
        @(posedge clk); @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
 
        // Escenario 1: conteo normal y rollovers en cadena.
        // Verifica el estado inicial, el avance de cada unidad de tiempo
        // y los rollovers: segundo 59 incrementa minuto, minuto 59 incrementa
        // hora, hora 12 vuelve a 1 en formato 12 h.
        $display("");
        $display("Escenario 1: conteo normal y rollovers en cadena");
 
        #1;
        if (hour===12 && minute===0 && second===0) begin
            $display("  PASS: %-45s | %02d:%02d:%02d",
                     "estado inicial tras reset", hour, minute, second);
            pass_count++;
        end else begin
            $error("  FAIL: %-45s | got %02d:%02d:%02d expected 12:00:00",
                   "estado inicial tras reset", hour, minute, second);
            fail_count++;
        end
 
        advance_and_check(1,     12,  0,  1,  "segundo 1 tras 1 tick");
        advance_and_check(1,     12,  0,  2,  "segundo 2 tras 2 ticks");
        advance_and_check(57,    12,  0,  59, "segundo 59 antes del rollover");
        advance_and_check(1,     12,  1,  0,  "rollover: segundo 59 a 0, minuto incrementa a 1");
        advance_and_check(3539,  12,  59, 59, "12:59:59 antes del rollover doble");
        advance_and_check(1,     1,   0,  0,  "rollover doble: 12:59:59 pasa a 01:00:00");
        advance_and_check(43199, 12,  59, 59, "12:59:59 antes del rollover de hora");
        advance_and_check(1,     1,   0,  0,  "rollover: hora 12 vuelve a 1 en formato 12 h");
 
        // Escenario 2: modo ajuste mediante botones y rechazo de rebote.
        // Cada pulsacion limpia incrementa el contador correspondiente y
        // los rollovers aplican igual que en modo normal. El rebote mecanico
        // con pulsos menores a DEB ciclos no debe producir incremento.
        $display("");
        $display("Escenario 2: modo ajuste mediante botones y rechazo de rebote");
 
        rst = 1'b1; @(posedge clk); @(posedge clk);
        rst = 1'b0; @(posedge clk);
        sw_adjust = 1'b1;
        @(posedge clk);
 
        press_min_and_check(12, 1,  0, "btn_inc_min: minuto pasa de 0 a 1");
        press_min_and_check(12, 2,  0, "btn_inc_min: minuto pasa de 1 a 2");
 
        begin : blk_min_a_59
            int i;
            for (i = 0; i < 57; i++) begin
                btn_inc_min = 1'b1; repeat (DEB + 4) @(posedge clk);
                btn_inc_min = 1'b0; repeat (DEB + 4) @(posedge clk);
            end
            #1;
            if (hour===12 && minute===59 && second===0) begin
                $display("  PASS: %-45s | %02d:%02d:%02d",
                         "btn_inc_min: minuto llega a 59", hour, minute, second);
                pass_count++;
            end else begin
                $error("  FAIL: %-45s | got %02d:%02d:%02d expected 12:59:00",
                       "btn_inc_min: minuto llega a 59", hour, minute, second);
                fail_count++;
            end
        end : blk_min_a_59
 
        press_min_and_check(12, 0, 0, "btn_inc_min: rollover minuto 59 a 0");
 
        press_hour_and_check(1,  0, 0, "btn_inc_hour: hora pasa de 12 a 1");
        press_hour_and_check(2,  0, 0, "btn_inc_hour: hora pasa de 1 a 2");
 
        begin : blk_hour_a_12
            int i;
            for (i = 0; i < 10; i++) begin
                btn_inc_hour = 1'b1; repeat (DEB + 4) @(posedge clk);
                btn_inc_hour = 1'b0; repeat (DEB + 4) @(posedge clk);
            end
            #1;
            if (hour===12 && minute===0 && second===0) begin
                $display("  PASS: %-45s | %02d:%02d:%02d",
                         "btn_inc_hour: hora llega a 12", hour, minute, second);
                pass_count++;
            end else begin
                $error("  FAIL: %-45s | got %02d:%02d:%02d expected 12:00:00",
                       "btn_inc_hour: hora llega a 12", hour, minute, second);
                fail_count++;
            end
        end : blk_hour_a_12
 
        press_hour_and_check(1, 0, 0, "btn_inc_hour: rollover hora 12 a 1");
 
        begin : blk_rebote
            bit [3:0] h_antes;
            h_antes = hour;
            repeat (4) begin
                btn_inc_hour = 1'b1; repeat (DEB - 1) @(posedge clk);
                btn_inc_hour = 1'b0; repeat (2)       @(posedge clk);
            end
            @(posedge clk); #1;
            if (hour === h_antes) begin
                $display("  PASS: %-45s | hour=%02d sin cambio",
                         "rebote mecanico ignorado por debounce", hour);
                pass_count++;
            end else begin
                $error("  FAIL: %-45s | hour=%02d esperado %02d",
                       "rebote mecanico ignorado por debounce", hour, h_antes);
                fail_count++;
            end
        end : blk_rebote
 
        sw_adjust = 1'b0;
 
        // Escenario 3: segundos congelados en modo ajuste.
        // Al activar sw_adjust el divisor se congela y second deja de avanzar.
        // Al desactivarlo el conteo se reanuda desde cero, por lo que el primer
        // tick adicional tarda un periodo completo mas de lo esperado.
        $display("");
        $display("Escenario 3: segundos congelados en modo ajuste");
 
        rst = 1'b1; @(posedge clk); @(posedge clk);
        rst = 1'b0; @(posedge clk);
 
        advance_and_check(3, 12, 0, 3, "segundo 3 en modo normal antes del ajuste");
 
        sw_adjust = 1'b1;
        repeat (CLK_F * 5) @(posedge clk); #1;
        if (hour===12 && minute===0 && second===3) begin
            $display("  PASS: %-45s | %02d:%02d:%02d",
                     "segundo 3 congelado durante el modo ajuste", hour, minute, second);
            pass_count++;
        end else begin
            $error("  FAIL: %-45s | got %02d:%02d:%02d expected 12:00:03",
                   "segundo 3 congelado durante el modo ajuste", hour, minute, second);
            fail_count++;
        end
 
        sw_adjust = 1'b0;
        repeat (2 * CLK_F) @(posedge clk); @(negedge clk); #1;
        if (hour===12 && minute===0 && second===5) begin
            $display("  PASS: %-45s | %02d:%02d:%02d",
                     "segundo 5 tras reanudar el modo normal", hour, minute, second);
            pass_count++;
        end else begin
            $error("  FAIL: %-45s | got %02d:%02d:%02d expected 12:00:05",
                   "segundo 5 tras reanudar el modo normal", hour, minute, second);
            fail_count++;
        end
 
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
 
endmodule : tb_clock_counter
 
