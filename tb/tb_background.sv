/*
 * Autor:   Andrea García Borges
 * Fecha:   23/04/2026
 *
 * Módulo:  tb_background
 * Compilar:
 *   iverilog -g2012 -o tb_background.vvp tb/tb_background.sv src/background.v
 *
 * Ejecutar:
 *   vvp tb_background.vvp
 */
`timescale 1ns/1ps
 
module tb_background_gen;
 
    bit        clk;
    bit  [9:0] px;
    bit  [9:0] py;
    wire       pixel_val;
 
    int pass_count = 0;
    int fail_count = 0;
 
    background_gen u_dut (
        .px       (px),
        .py       (py),
        .pixel_val(pixel_val)
    );
 
    initial clk = 1'b0;
    always #5 clk = ~clk;
 
    // Aplica las coordenadas y verifica pixel_val en el siguiente flanco.
    // El modulo es combinacional, el ciclo de reloj se usa solo para
    // garantizar tiempos de muestreo consistentes entre checks.
    task automatic apply_and_check(
        input bit [9:0] in_px,
        input bit [9:0] in_py,
        input bit       exp_val,
        input string    descripcion
    );
        px = in_px;
        py = in_py;
        @(posedge clk); #1;
 
        if (pixel_val === exp_val) begin
            $display("  PASS: %-45s | px=%03d py=%03d pixel=%b",
                     descripcion, in_px, in_py, pixel_val);
            pass_count++;
        end else begin
            $error("  FAIL: %-45s | px=%03d py=%03d got %b expected %b",
                   descripcion, in_px, in_py, pixel_val, exp_val);
            fail_count++;
        end
    endtask
 
    initial begin : tester
        $dumpfile("tb_background_gen.vcd");
        $dumpvars(0, tb_background_gen);
 
        px = 0; py = 0;
        @(posedge clk); @(posedge clk);
 
        // Escenario 1: marco exterior e interior producen pixeles blancos.
        // Los dos primeros y dos ultimos pixeles de cada borde horizontal y
        // vertical deben ser blancos, al igual que el marco interior en px 4-5
        // y py 4-5 con sus simetricos.
        $display("");
        $display("Escenario 1: marco exterior e interior producen pixeles blancos");
 
        apply_and_check(10'd0,   10'd0,   1'b1, "esquina tl (0,0), borde exterior");
        apply_and_check(10'd1,   10'd240, 1'b1, "borde izquierdo px=1");
        apply_and_check(10'd639, 10'd240, 1'b1, "borde derecho px=639");
        apply_and_check(10'd320, 10'd0,   1'b1, "borde superior py=0");
        apply_and_check(10'd320, 10'd479, 1'b1, "borde inferior py=479");
        apply_and_check(10'd4,   10'd240, 1'b1, "borde interior px=4");
        apply_and_check(10'd5,   10'd240, 1'b1, "borde interior px=5");
        apply_and_check(10'd320, 10'd4,   1'b1, "borde interior py=4");
        apply_and_check(10'd320, 10'd5,   1'b1, "borde interior py=5");
 
        // Escenario 2: area interior sin esquinas produce pixeles negros.
        // Pixeles fuera de los margenes de borde y fuera de las zonas de
        // esquina deben ser negros independientemente de su posicion.
        $display("");
        $display("Escenario 2: area interior fuera de esquinas produce negro");
 
        apply_and_check(10'd200, 10'd100, 1'b0, "zona central (200,100)");
        apply_and_check(10'd320, 10'd240, 1'b0, "centro de pantalla (320,240)");
        apply_and_check(10'd100, 10'd200, 1'b0, "zona media izquierda (100,200)");
        apply_and_check(10'd500, 10'd300, 1'b0, "zona media derecha (500,300)");
        apply_and_check(10'd300, 10'd150, 1'b0, "area superior central (300,150)");
 
        // Escenario 3: patron de damero en las esquinas.
        // El XOR de los bits 3 de px y py alterna bloques de 8x8 entre
        // blanco y negro dentro de las zonas de esquina.
        $display("");
        $display("Escenario 3: patron de damero en las esquinas");
 
        // En esquina superior izquierda (px<=80, py<=60)
        // px=16=10000 bit3=0, py=10=01010 bit3=1 -> XOR=1 -> blanco
        apply_and_check(10'd16, 10'd10, 1'b1, "esquina tl: px[3]=0 py[3]=1 -> blanco");
        // px=8=01000 bit3=1, py=10=01010 bit3=1 -> XOR=0 -> negro
        apply_and_check(10'd8,  10'd10, 1'b0, "esquina tl: px[3]=1 py[3]=1 -> negro");
        // px=24=11000 bit3=1, py=16=10000 bit3=0 -> XOR=1 -> blanco
        apply_and_check(10'd24, 10'd16, 1'b1, "esquina tl: px[3]=1 py[3]=0 -> blanco");
        // px=8=01000 bit3=1, py=8=01000 bit3=1 -> XOR=0 -> negro
        apply_and_check(10'd8,  10'd8,  1'b0, "esquina tl: px[3]=1 py[3]=1 -> negro");
 
        // En esquina inferior derecha (px>=559, py>=419)
        // px=560=1000110000 bit3=0, py=424=110101000 bit3=1 -> XOR=1 -> blanco
        apply_and_check(10'd560, 10'd424, 1'b1, "esquina br: px[3]=0 py[3]=1 -> blanco");
        // px=568=1000111000 bit3=1, py=424=110101000 bit3=1 -> XOR=0 -> negro
        apply_and_check(10'd568, 10'd424, 1'b0, "esquina br: px[3]=1 py[3]=1 -> negro");
 
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
 
endmodule : tb_background_gen
