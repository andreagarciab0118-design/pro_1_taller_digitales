/*
 * Autor:   Andrea García Borges
 * Fecha:   23/04/2026
 *
 * Módulo:  tb_image_generator
 * Compilar:
 *   iverilog -g2012 -o tb_image_generator.vvp tb/tb_image_generator.sv src/image_generator.v src/font_rom.v src/background.v
 *            vvp tb_image_generator.vvp
 * Ejecutar:
 *   vvp tb_image_generator.vvp
 */
`timescale 1ns/1ps
 
module tb_image_generator;
 
    bit        clk;
    bit        rst;
    bit  [3:0] hour;
    bit  [5:0] minute;
    bit  [5:0] second;
    wire       we_a;
    wire [18:0] addr_a;
    wire        data_a;
 
    int pass_count = 0;
    int fail_count = 0;
 
    image_generator u_dut (
        .clk   (clk),
        .rst   (rst),
        .hour  (hour),
        .minute(minute),
        .second(second),
        .we_a  (we_a),
        .addr_a(addr_a),
        .data_a(data_a)
    );
 
    initial clk = 1'b0;
    always #5 clk = ~clk;
 
    // Verifica we_a, addr_a y data_a en el ciclo actual.
    task automatic check_output(
        input        exp_we,
        input [18:0] exp_addr,
        input        exp_data,
        input string descripcion
    );
        if (we_a === exp_we && addr_a === exp_addr && data_a === exp_data) begin
            $display("  PASS: %-45s | addr=%06d data=%b we=%b",
                     descripcion, addr_a, data_a, we_a);
            pass_count++;
        end else begin
            $error("  FAIL: %-45s | got addr=%06d data=%b we=%b  esp addr=%06d data=%b we=%b",
                   descripcion, addr_a, data_a, we_a, exp_addr, exp_data, exp_we);
            fail_count++;
        end
    endtask
 
    initial begin : tester
        $dumpfile("tb_image_generator.vcd");
        $dumpvars(0, tb_image_generator);
 
        rst    = 1'b1;
        hour   = 4'd12;
        minute = 6'd0;
        second = 6'd0;
        @(posedge clk); @(posedge clk);
        rst = 1'b0;
        @(posedge clk); #1;
 
        // Escenario 1: we_a permanece activo de forma continua.
        // El generador de imagen escribe en la VRAM en cada ciclo de reloj.
        // we_a debe ser 1 en todo momento independientemente del contenido.
        $display("");
        $display("Escenario 1: we_a permanece activo de forma continua");
 
        begin : blk_we
            int  i;
            bit  fallo;
            fallo = 0;
            for (i = 0; i < 20; i++) begin
                if (we_a !== 1'b1) begin
                    $error("  FAIL: we_a=%b en ciclo %0d (esperado 1)", we_a, i);
                    fallo = 1;
                    fail_count++;
                end
                @(posedge clk); #1;
            end
            if (!fallo) begin
                $display("  PASS: %-45s | we_a=1 estable 20 ciclos consecutivos",
                         "we_a activo de forma continua");
                pass_count++;
            end
        end : blk_we
 
        // Escenario 2: addr_a avanza secuencialmente con latencia de un ciclo.
        // El pipeline registra la direccion un ciclo antes de escribir.
        // Tras el reset, addr_a debe arrancar en 0 e incrementar en 1 cada ciclo.
        $display("");
        $display("Escenario 2: addr_a avanza secuencialmente desde cero");
 
        rst = 1'b1;
        @(posedge clk); @(posedge clk);
        rst = 1'b0;
        @(posedge clk); #1;
 
        check_output(1'b1, 19'd0, 1'b1, "addr_a=0 tras pipeline: borde (0,0)");
        @(posedge clk); #1;
        check_output(1'b1, 19'd1, 1'b1, "addr_a=1: borde (1,0)");
        @(posedge clk); #1;
        check_output(1'b1, 19'd2, 1'b1, "addr_a=2: borde py=0");
        @(posedge clk); #1;
        check_output(1'b1, 19'd3, 1'b1, "addr_a=3: borde py=0");
 
        begin : blk_seq
            int  i;
            bit  fallo;
            fallo = 0;
            for (i = 4; i < 640; i++) begin
                @(posedge clk); #1;
                if (addr_a !== 19'(i)) begin
                    $error("  FAIL: addr_a=%06d en ciclo %0d (esperado %0d)",
                           addr_a, i, i);
                    fallo = 1;
                    fail_count++;
                    i = 640; // salir del loop
                end
            end
            if (!fallo) begin
                $display("  PASS: %-45s | addr_a llego hasta 639 sin salto",
                         "secuencia 0-639 correcta para la primera linea");
                pass_count++;
            end
        end : blk_seq
 
        // Escenario 3: datos correctos para pixeles conocidos con 12:00:00.
        // Los pixeles del borde exterior deben ser blancos. Los pixeles de la
        // zona interior sin esquinas deben ser negros. Se verifica avanzando
        // el contador hasta posiciones conocidas y comparando data_a.
        $display("");
        $display("Escenario 3: datos correctos para pixeles conocidos con 12:00:00");
 
        rst = 1'b1;
        @(posedge clk); @(posedge clk);
        rst = 1'b0;
 
        // Avanzar hasta addr 640: px=0,py=1 -> borde (px==0) -> data=1
        repeat (641) @(posedge clk); #1;
        check_output(1'b1, 19'd640, 1'b1, "addr 640: px=0 py=1, borde izquierdo");
 
        // Avanzar hasta addr 641: px=1,py=1 -> borde (px==1) -> data=1
        @(posedge clk); #1;
        check_output(1'b1, 19'd641, 1'b1, "addr 641: px=1 py=1, borde izquierdo");
 
        // Avanzar hasta addr 1286: px=6,py=2 -> esquina, px[3]=0 py[3]=0 -> data=0
        repeat (1286 - 641) @(posedge clk); #1;
        check_output(1'b1, 19'd1286, 1'b0, "addr 1286: px=6 py=2, damero negro");
 
        // Avanzar hasta addr 1296: px=16,py=2 -> esquina, px[3]=0 py[3]=0 -> data=0
        // px=16=10000 bit3=0, py=2=010 bit3=0 -> XOR=0 -> negro (en esquina)
        repeat (1296 - 1286) @(posedge clk); #1;
        check_output(1'b1, 19'd1296, 1'b0, "addr 1296: px=16 py=2, damero negro (XOR=0)");
 
        // Avanzar hasta addr 1306: px=26,py=2 -> esquina
        // px=26=11010 bit3=1, py=2=010 bit3=0 -> XOR=1 -> blanco
        repeat (1306 - 1296) @(posedge clk); #1;
        check_output(1'b1, 19'd1306, 1'b1, "addr 1306: px=26 py=2, damero blanco (XOR=1)");
 
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
 
endmodule : tb_image_generator
