/*
 * Autor:   Andrea García Borges
 * Fecha:   23/04/2026
 *
 * Módulo:  tb_top
 *
 * Descripción: Testbench de integración para el sistema VGA Clock completo.
 *              Instancia top_sim (que incluye el stub de clk_wiz_0) y verifica
 *              que cada módulo funcione correctamente en conjunto:
 *
 *                [1] clock_counter  — reset y hora inicial 12:00:00
 *                [2] button_sync    — sincronización de botones
 *                [3] debounce       — filtro anti-rebote
 *                [4] edge_detector  — detección de flanco
 *                [5] background_gen — píxel escrito en VRAM desde image_generator
 *                [6] font_rom       — escritura activa en VRAM
 *                [7] image_generator — we_a siempre activo
 *                [8] vram           — lectura del puerto B
 *                [9] h_sync_gen     — pulso hsync detectado
 *               [10] v_sync_gen     — pulso vsync detectado
 *               [11] pixel_mux      — salida RGB correcta
 *               [12] vga_controller — hsync y vsync integrados
 *               [13] seg7_driver    — displays activos y segmentos válidos
 *               [14] clock_counter  — modo ajuste incrementa minuto
 *               [15] clock_counter  — modo ajuste incrementa hora
 *
 * Compilar:
 *   iverilog -g2012 -o sim/tb_top.vvp \
 *       tb/tb_top.sv \
 *       src/top_sim.v \
 *       src/background_gen.v \
 *       src/button_sync.v \
 *       src/clock_counter.v \
 *       src/debounce.v \
 *       src/edge_detector.v \
 *       src/font_rom.v \
 *       src/h_sync_gen.v \
 *       src/image_generator.v \
 *       src/pixel_mux.v \
 *       src/seg7_driver.v \
 *       src/v_sync_gen.v \
 *       src/vga_controller.v \
 *       src/vram.v
 *
 * Ejecutar:
 *   vvp sim/tb_top.vvp
 */
`timescale 1ns/1ps

module tb_top;

    // ----------------------------------------------------------------
    // Señales del DUT
    // ----------------------------------------------------------------
    reg        clk;
    reg        rst;
    reg        sw_adjust;
    reg        btn_inc_hour;
    reg        btn_inc_min;

    wire [6:0] seg;
    wire [7:0] an;
    wire       dp;
    wire [3:0] vga_r, vga_g, vga_b;
    wire       hsync, vsync;

    // ----------------------------------------------------------------
    // Contadores globales de resultado
    // ----------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    // ----------------------------------------------------------------
    // Instancia del DUT
    // ----------------------------------------------------------------
    top u_top (
        .clk         (clk),
        .rst         (rst),
        .sw_adjust   (sw_adjust),
        .btn_inc_hour(btn_inc_hour),
        .btn_inc_min (btn_inc_min),
        .seg         (seg),
        .an          (an),
        .dp          (dp),
        .vga_r       (vga_r),
        .vga_g       (vga_g),
        .vga_b       (vga_b),
        .hsync       (hsync),
        .vsync       (vsync)
    );

    // ----------------------------------------------------------------
    // Reloj: 100 MHz → periodo 10 ns
    // ----------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ----------------------------------------------------------------
    // Tarea de verificación — mismo formato que tb_background_gen
    // ----------------------------------------------------------------
    task automatic apply_and_check(
        input bit    condition,
        input string descripcion
    );
        if (condition) begin
            $display("  PASS: %s", descripcion);
            pass_count++;
        end else begin
            $error("  FAIL: %s", descripcion);
            fail_count++;
        end
    endtask

    // ----------------------------------------------------------------
    // Acceso interno a submódulos para verificación
    // ----------------------------------------------------------------
    wire [3:0] hour_i    = u_top.u_clock.hour;
    wire [5:0] minute_i  = u_top.u_clock.minute;
    wire [5:0] second_i  = u_top.u_clock.second;
    wire       we_a_i    = u_top.we_a;
    wire       btn_h_sync = u_top.u_clock.btn_hour_sync;
    wire       btn_h_cln  = u_top.u_clock.btn_hour_clean;
    wire       btn_h_pls  = u_top.u_clock.btn_hour_pulse;
    wire       btn_m_sync = u_top.u_clock.btn_min_sync;
    wire       btn_m_cln  = u_top.u_clock.btn_min_clean;
    wire       btn_m_pls  = u_top.u_clock.btn_min_pulse;

    // ----------------------------------------------------------------
    // Bloque principal
    // ----------------------------------------------------------------
    initial begin : tester
        $dumpfile("sim/tb_top.vcd");
        $dumpvars(0, tb_top);

        rst          = 1'b1;
        sw_adjust    = 1'b0;
        btn_inc_hour = 1'b0;
        btn_inc_min  = 1'b0;

        repeat(10) @(posedge clk);
        rst = 1'b0;
        @(posedge clk); #1;

        // ============================================================
        // Módulo 1: clock_counter — reset deja hora en 12:00:00
        // ============================================================
        $display("");
        $display("--------------------------------------------------------");
        $display("  Modulo: clock_counter  [reset y hora inicial]");
        $display("--------------------------------------------------------");

        apply_and_check(hour_i   == 4'd12, "hora  == 12 tras reset");
        apply_and_check(minute_i == 6'd0,  "minuto == 0  tras reset");
        apply_and_check(second_i == 6'd0,  "segundo == 0 tras reset");

        // ============================================================
        // Módulo 2: button_sync — sincronizador de dos FF
        //   Aplicamos btn_inc_hour y verificamos que btn_hour_sync
        //   capture el valor luego de dos flancos.
        // ============================================================
        $display("");
        $display("--------------------------------------------------------");
        $display("  Modulo: button_sync  [sincronizacion de boton]");
        $display("--------------------------------------------------------");

        begin
            sw_adjust    = 1'b1;
            btn_inc_hour = 1'b1;
            @(posedge clk); @(posedge clk); @(posedge clk); #1;
            apply_and_check(btn_h_sync === 1'b1,
                "btn_hour_sync == 1 luego de 3 flancos con btn alto");
            btn_inc_hour = 1'b0;
            @(posedge clk); @(posedge clk); @(posedge clk); #1;
            apply_and_check(btn_h_sync === 1'b0,
                "btn_hour_sync == 0 luego de 3 flancos con btn bajo");
            sw_adjust = 1'b0;
        end

        // ============================================================
        // Módulo 3: debounce — señal estable MAX_COUNT ciclos
        //   Mantenemos el botón activo > 1_000_000 ciclos y
        //   verificamos que clean_out se propague.
        // ============================================================
        $display("");
        $display("--------------------------------------------------------");
        $display("  Modulo: debounce  [filtro anti-rebote]");
        $display("--------------------------------------------------------");

        begin
            sw_adjust    = 1'b1;
            btn_inc_hour = 1'b1;
            repeat(1_000_010) @(posedge clk); #1;
            apply_and_check(btn_h_cln === 1'b1,
                "btn_hour_clean == 1 tras 1_000_010 ciclos estables en alto");
            btn_inc_hour = 1'b0;
            repeat(1_000_010) @(posedge clk); #1;
            apply_and_check(btn_h_cln === 1'b0,
                "btn_hour_clean == 0 tras 1_000_010 ciclos estables en bajo");
            sw_adjust = 1'b0;
        end

        // ============================================================
        // Módulo 4: edge_detector — pulso de 1 ciclo en flanco subida
        //   Después del debounce, pulse_out debe haber generado 1 pulso.
        //   Lo verificamos comprobando que el minuto se haya incrementado,
        //   ya que el pulse es el último eslabón antes del contador.
        // ============================================================
        $display("");
        $display("--------------------------------------------------------");
        $display("  Modulo: edge_detector  [deteccion de flanco de subida]");
        $display("--------------------------------------------------------");

        begin
            bit [5:0] min_antes2;
            sw_adjust   = 1'b1;
            @(posedge clk); #1;
            min_antes2  = minute_i;
            btn_inc_min = 1'b1;
            repeat(1_000_010) @(posedge clk);
            btn_inc_min = 1'b0;
            repeat(5) @(posedge clk); #1;
            // Si el edge_detector generó el pulso, el minuto subió
            apply_and_check(minute_i == (min_antes2 + 6'd1),
                "edge_detector genero pulso: minuto incremento exactamente 1 vez");
            sw_adjust = 1'b0;
        end

        // ============================================================
        // Módulo 5 y 7: image_generator + background_gen
        //   we_a debe estar siempre en alto (image_generator escribe
        //   el frame completo continuamente a 100 MHz).
        // ============================================================
        $display("");
        $display("--------------------------------------------------------");
        $display("  Modulo: image_generator + background_gen  [escritura VRAM]");
        $display("--------------------------------------------------------");

        begin
            repeat(5) @(posedge clk); #1;
            apply_and_check(we_a_i === 1'b1,
                "we_a activo: image_generator escribe continuamente en VRAM");
            // Verificamos que la dirección cambia cada ciclo (barrido activo)
            begin
                bit [18:0] addr1, addr2;
                @(posedge clk); #1; addr1 = u_top.addr_a;
                @(posedge clk); #1; addr2 = u_top.addr_a;
                apply_and_check(addr1 != addr2,
                    "addr_a cambia cada ciclo: barrido de frame activo");
            end
        end

        // ============================================================
        // Módulo 6: font_rom
        //   Comprobamos indirectamente que font_rom responde: tras reset
        //   la hora es 12:00:00. El dígito '1' (char_code=1) en addr=16
        //   debe devolver 8'h18 (primera fila del bitmap del 1).
        //   Leemos directamente la memoria interna del font_rom.
        // ============================================================
        $display("");
        $display("--------------------------------------------------------");
        $display("  Modulo: font_rom  [bitmap de caracteres]");
        $display("--------------------------------------------------------");

        begin
            @(posedge clk); #1;
            apply_and_check(
                u_top.u_img_gen.u_font.mem[16] === 8'h18,
                "font_rom mem[16] == 8'h18  (fila 0 del digito '1')");
            apply_and_check(
                u_top.u_img_gen.u_font.mem[0]  === 8'h3C,
                "font_rom mem[0]  == 8'h3C  (fila 0 del digito '0')");
            apply_and_check(
                u_top.u_img_gen.u_font.mem[160] === 8'h00,
                "font_rom mem[160] == 8'h00 (fila 0 del caracter ':')");
        end

        // ============================================================
        // Módulo 8: vram — lectura puerto B refleja escritura puerto A
        //   Esperamos suficientes ciclos para que image_generator
        //   haya escrito al menos la primera posición, luego
        //   verificamos que data_out_b no sea X (dato válido).
        // ============================================================
        $display("");
        $display("--------------------------------------------------------");
        $display("  Modulo: vram  [memoria de video dual-port]");
        $display("--------------------------------------------------------");

        begin
            repeat(1000) @(posedge clk); #1;
            apply_and_check(
                u_top.u_vram.data_out_b !== 1'bx,
                "vram puerto B devuelve dato valido (no X) tras escritura");
            // La dirección 0 corresponde al píxel (0,0) que es borde
            // exterior → background_gen lo pone en 1 (blanco)
            apply_and_check(
                u_top.u_vram.mem[0] === 1'b1,
                "vram mem[0] == 1 (pixel (0,0) es borde blanco)");
        end

        // ============================================================
        // Módulo 9: h_sync_gen — pulso hsync detectado
        // ============================================================
        $display("");
        $display("--------------------------------------------------------");
        $display("  Modulo: h_sync_gen  [sincronizacion horizontal]");
        $display("--------------------------------------------------------");

        begin
            bit hsync_low;
            bit hsync_high;
            hsync_low  = 1'b0;
            hsync_high = 1'b0;
            fork
                begin repeat(2000) @(posedge clk); end
                begin
                    forever begin
                        @(posedge clk); #1;
                        if (!hsync) hsync_low  = 1'b1;
                        if ( hsync) hsync_high = 1'b1;
                    end
                end
            join_any
            disable fork;
            apply_and_check(hsync_low,  "hsync estuvo en bajo (pulso de sync activo)");
            apply_and_check(hsync_high, "hsync estuvo en alto (zona visible/porch)");
        end

        // ============================================================
        // Módulo 10: v_sync_gen — pulso vsync detectado
        //   800 ciclos × 525 líneas = 420,000 ciclos para un frame.
        // ============================================================
        $display("");
        $display("--------------------------------------------------------");
        $display("  Modulo: v_sync_gen  [sincronizacion vertical]");
        $display("--------------------------------------------------------");

        begin
            bit vsync_low;
            vsync_low = 1'b0;
            fork
                begin repeat(500_000) @(posedge clk); end
                begin
                    forever begin
                        @(posedge clk); #1;
                        if (!vsync) vsync_low = 1'b1;
                    end
                end
            join_any
            disable fork;
            apply_and_check(vsync_low, "vsync estuvo en bajo al menos una vez en 500k ciclos");
        end

        // ============================================================
        // Módulo 11: pixel_mux — salida RGB correcta
        //   En zona visible con píxel blanco → RGB = FFF
        //   En zona de blanking           → RGB = 000
        // ============================================================
        $display("");
        $display("--------------------------------------------------------");
        $display("  Modulo: pixel_mux  [conversion bit a RGB]");
        $display("--------------------------------------------------------");

        begin
            bit rgb_white_seen;
            bit rgb_black_seen;
            rgb_white_seen = 1'b0;
            rgb_black_seen = 1'b0;
            fork
                begin repeat(1000) @(posedge clk); end
                begin
                    forever begin
                        @(posedge clk); #1;
                        if (vga_r === 4'hF && vga_g === 4'hF && vga_b === 4'hF)
                            rgb_white_seen = 1'b1;
                        if (vga_r === 4'h0 && vga_g === 4'h0 && vga_b === 4'h0)
                            rgb_black_seen = 1'b1;
                    end
                end
            join_any
            disable fork;
            apply_and_check(rgb_white_seen, "pixel_mux produjo RGB=FFF (blanco)");
            apply_and_check(rgb_black_seen, "pixel_mux produjo RGB=000 (negro)");
        end

        // ============================================================
        // Módulo 12: vga_controller — integracion hsync + vsync + RGB
        // ============================================================
        $display("");
        $display("--------------------------------------------------------");
        $display("  Modulo: vga_controller  [integracion VGA completa]");
        $display("--------------------------------------------------------");

        begin
            // hcount y vcount deben estar dentro del rango esperado
            apply_and_check(
                u_top.u_vga.u_h_sync.hcount <= 10'd799,
                "hcount dentro de rango 0-799");
            apply_and_check(
                u_top.u_vga.u_v_sync.vcount <= 10'd524,
                "vcount dentro de rango 0-524");
            // La dirección de lectura de VRAM no debe superar 307199
            apply_and_check(
                u_top.vram_addr < 19'd307200,
                "vram_addr de lectura dentro del rango valido (< 307200)");
        end

        // ============================================================
        // Módulo 13: seg7_driver — displays activos y segmentos válidos
        // ============================================================
        $display("");
        $display("--------------------------------------------------------");
        $display("  Modulo: seg7_driver  [displays de 7 segmentos]");
        $display("--------------------------------------------------------");

        begin
            bit display_on;
            bit seg_valid;
            // refresh[16:14] cambia cada 2^14 = 16,384 ciclos
            repeat(200_000) @(posedge clk); #1;
            display_on = (an !== 8'hFF);
            // seg no debe ser el valor inactivo 7'b1111111
            seg_valid  = (seg !== 7'b1111111);
            apply_and_check(display_on, "al menos un display activo (an != 8'hFF)");
            apply_and_check(seg_valid,  "segmento valido activo (seg != 7'b1111111)");
        end

        // ============================================================
        // Módulo 14: clock_counter — modo ajuste incrementa minuto
        //   Reset previo para garantizar minute=0 independientemente
        //   de los incrementos acumulados en escenarios anteriores.
        // ============================================================
        $display("");
        $display("--------------------------------------------------------");
        $display("  Modulo: clock_counter  [modo ajuste: incremento de minuto]");
        $display("--------------------------------------------------------");

        rst = 1'b1;
        repeat(5) @(posedge clk);
        rst = 1'b0;
        @(posedge clk); #1;

        begin
            bit [5:0] min_antes;
            sw_adjust   = 1'b1;
            @(posedge clk); #1;
            min_antes   = minute_i;
            btn_inc_min = 1'b1;
            repeat(1_000_010) @(posedge clk);
            btn_inc_min = 1'b0;
            repeat(5) @(posedge clk); #1;
            apply_and_check(
                minute_i == (min_antes == 6'd59 ? 6'd0 : min_antes + 6'd1),
                "minuto incremento correctamente en modo ajuste (con wrap 59->0)");
            sw_adjust = 1'b0;
        end

        // ============================================================
        // Módulo 15: clock_counter — modo ajuste incrementa hora
        // ============================================================
        $display("");
        $display("--------------------------------------------------------");
        $display("  Modulo: clock_counter  [modo ajuste: incremento de hora]");
        $display("--------------------------------------------------------");

        begin
            bit [3:0] hora_antes;
            sw_adjust    = 1'b1;
            @(posedge clk); #1;
            hora_antes   = hour_i;
            btn_inc_hour = 1'b1;
            repeat(1_000_010) @(posedge clk);
            btn_inc_hour = 1'b0;
            repeat(5) @(posedge clk); #1;
            apply_and_check(
                hour_i == (hora_antes == 4'd12 ? 4'd1 : hora_antes + 4'd1),
                "hora incremento correctamente en modo ajuste (con wrap 12->1)");
            sw_adjust = 1'b0;
        end

        // ============================================================
        // Scoreboard final
        // ============================================================
        $display("");
        $display("================================================");
        $display("   SCOREBOARD FINAL  —  tb_top");
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

endmodule : tb_top