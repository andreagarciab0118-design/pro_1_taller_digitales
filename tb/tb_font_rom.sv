/*
 * Autor:   Andrea García Borges
 * Fecha:   23/04/2026
 *
 * Módulo:  tb_font_rom
 *
 * Compilar:
 *   iverilog -g2012 -o tb_font_rom.vvp tb_font_rom.sv font_rom.v
 *
 * Ejecutar:
 *   vvp tb_font_rom.vvp
 */
`timescale 1ns/1ps
 
module tb_font_rom;
 
    bit        clk;
    bit  [7:0] addr;
    wire [7:0] data_out;
 
    int pass_count = 0;
    int fail_count = 0;
 
    font_rom u_dut (
        .clk     (clk),
        .addr    (addr),
        .data_out(data_out)
    );
 
    initial clk = 1'b0;
    always #5 clk = ~clk;
 
    // Aplica addr y verifica data_out un ciclo despues.
    // La BRAM tiene latencia de exactamente un ciclo de reloj.
    task automatic apply_and_check(
        input bit [7:0] in_addr,
        input bit [7:0] exp_data,
        input string    descripcion
    );
        addr = in_addr;
        @(posedge clk); #1;
 
        if (data_out === exp_data) begin
            $display("  PASS: %-45s | addr=%02h data=%02h",
                     descripcion, in_addr, data_out);
            pass_count++;
        end else begin
            $error("  FAIL: %-45s | addr=%02h got %02h expected %02h",
                   descripcion, in_addr, data_out, exp_data);
            fail_count++;
        end
    endtask
 
    initial begin : tester
        $dumpfile("tb_font_rom.vcd");
        $dumpvars(0, tb_font_rom);
 
        addr = 8'h00;
        @(posedge clk); @(posedge clk);
 
        // Escenario 1: contenido correcto en filas centrales de los digitos.
        // Verifica valores conocidos de la fuente para confirmar que la BRAM
        // se inicializo correctamente con los bitmaps definidos.
        $display("");
        $display("Escenario 1: contenido correcto en filas centrales de los digitos");
 
        apply_and_check(8'h00, 8'h3C, "digito 0, fila 0:  0x3C = 00111100");
        apply_and_check(8'h02, 8'hC3, "digito 0, fila 2:  0xC3 = 11000011");
        apply_and_check(8'h10, 8'h18, "digito 1, fila 0:  0x18 = 00011000");
        apply_and_check(8'h1D, 8'h7E, "digito 1, fila 13: 0x7E = barra base");
        apply_and_check(8'h50, 8'hFF, "digito 5, fila 0:  0xFF = barra superior");
        apply_and_check(8'h84, 8'hC3, "digito 8, fila 4:  0xC3 = anillo superior");
        apply_and_check(8'h86, 8'h3C, "digito 8, fila 6:  0x3C = cintura del 8");
 
        // Escenario 2: estructura del separador dos puntos.
        // El codigo 10 (0xA) debe tener pixeles activos en las filas 3-5
        // para el punto superior y 9-11 para el punto inferior. Las filas
        // de inicio y fin deben estar vacias.
        $display("");
        $display("Escenario 2: estructura del separador dos puntos");
 
        apply_and_check(8'hA0, 8'h00, "colon, fila 0:  vacia");
        apply_and_check(8'hA1, 8'h00, "colon, fila 1:  vacia");
        apply_and_check(8'hA2, 8'h00, "colon, fila 2:  vacia");
        apply_and_check(8'hA3, 8'h18, "colon, fila 3:  0x18 = punto superior");
        apply_and_check(8'hA4, 8'h3C, "colon, fila 4:  0x3C = punto superior");
        apply_and_check(8'hA5, 8'h18, "colon, fila 5:  0x18 = punto superior");
        apply_and_check(8'hA7, 8'h00, "colon, fila 7:  vacia entre puntos");
        apply_and_check(8'hA9, 8'h18, "colon, fila 9:  0x18 = punto inferior");
        apply_and_check(8'hAA, 8'h3C, "colon, fila 10: 0x3C = punto inferior");
 
        // Escenario 3: filas de relleno 14 y 15 son cero para todos los digitos.
        // Cada caracter de 8x16 usa las filas 0-13 para el glifo y deja
        // las filas 14-15 en cero como margen inferior entre lineas.
        $display("");
        $display("Escenario 3: filas de relleno 14 y 15 son cero");
 
        begin : blk_relleno
            int  d;
            bit  fallo;
            fallo = 0;
            for (d = 0; d <= 10; d++) begin
                addr = {4'(d), 4'd14};
                @(posedge clk); #1;
                if (data_out !== 8'h00) begin
                    $error("  FAIL: char %02d fila 14 no es cero, got %02h", d, data_out);
                    fallo = 1;
                    fail_count++;
                end
                addr = {4'(d), 4'd15};
                @(posedge clk); #1;
                if (data_out !== 8'h00) begin
                    $error("  FAIL: char %02d fila 15 no es cero, got %02h", d, data_out);
                    fallo = 1;
                    fail_count++;
                end
            end
            if (!fallo) begin
                $display("  PASS: %-45s | todos cero en filas 14 y 15",
                         "filas de relleno correctas para los 11 caracteres");
                pass_count++;
            end
        end : blk_relleno
 
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
 
endmodule : tb_font_rom
