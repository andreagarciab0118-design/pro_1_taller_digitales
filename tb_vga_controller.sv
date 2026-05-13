/*
 * Autor:   Jesús Huertas
 * Fecha:   23/04/2026
 *
 * Módulo:  tb_vga_controller
 *
 * Descripción: Testbench de verificación para vga_controller. Instancia una
 *              VRAM real para verificar el pipeline completo desde la dirección
 *              de lectura hasta la salida RGB en el monitor, incluyendo la
 *              compensación de dos ciclos de latencia y el registro de video_on.
 *
 *              Se verifican tres escenarios: operación normal durante dos
 *              cuadros completos verificando ciclo a ciclo que hsync y vsync
 *              siguen el estándar VGA 640x480 @ 60Hz y que la salida RGB es
 *              negro en zonas de blanking usando un modelo de referencia con
 *              delay de dos ciclos para compensar la latencia del pipeline,
 *              verificación del pipeline de latencia escribiendo un patrón
 *              conocido en la VRAM y comprobando que aparece en la salida RGB,
 *              y verificación de que la salida RGB es negro durante el blanking
 *              horizontal después de que el pipeline se estabiliza.
 *
 * Compilar:
 *   iverilog -g2012 -o tb_vga_controller.vvp tb_vga_controller.sv vga_controller.v h_sync_gen.v v_sync_gen.v pixel_mux.v vram.v
 *
 * Ejecutar:
 *   vvp tb_vga_controller.vvp
 */

`timescale 1ns/1ps

module tb_vga_controller;

    localparam H_VISIBLE    = 640;
    localparam H_SYNC_START = 656;
    localparam H_SYNC_END   = 752;
    localparam H_TOTAL      = 800;
    localparam V_VISIBLE    = 480;
    localparam V_SYNC_START = 490;
    localparam V_SYNC_END   = 492;
    localparam V_TOTAL      = 525;
    localparam NUM_FRAMES   = 2;

    bit         clk;
    bit         rst;
    wire [3:0]  vga_r;
    wire [3:0]  vga_g;
    wire [3:0]  vga_b;
    wire        hsync;
    wire        vsync;
    wire [18:0] vram_addr;
    wire        vram_data_out;
    wire        debug_video_on_r;

    bit         check_enable;

    bit         clk_a;
    bit         we_a;
    bit  [18:0] addr_a;
    bit         data_in_a;

    vram u_vram (
        .clk_a     (clk_a),
        .we_a      (we_a),
        .addr_a    (addr_a),
        .data_in_a (data_in_a),
        .clk_b     (clk),
        .addr_b    (vram_addr),
        .data_out_b(vram_data_out)
    );

    vga_controller u_dut (
        .clk              (clk),
        .rst              (rst),
        .vram_data_in     (vram_data_out),
        .vram_addr        (vram_addr),
        .hsync            (hsync),
        .vsync            (vsync),
        .vga_r            (vga_r),
        .vga_g            (vga_g),
        .vga_b            (vga_b)
        
    );

    initial clk   = 1'b0;
    always #20 clk   = ~clk;

    initial clk_a = 1'b0;
    always #5  clk_a = ~clk_a;

    task write_vram(input [18:0] addr, input val);
        @(posedge clk_a);
        addr_a    = addr;
        data_in_a = val;
        we_a      = 1'b1;
        @(posedge clk_a);
        we_a      = 1'b0;
        repeat(4) @(posedge clk);
    endtask

    initial begin : tester
        $dumpfile("tb_vga_controller.vcd");
        $dumpvars(0, tb_vga_controller);

        rst          = 1'b1;
        we_a         = 1'b0;
        addr_a       = 19'd0;
        data_in_a    = 1'b0;
        check_enable = 0;

        @(posedge clk);
        @(posedge clk);
        rst = 1'b0;

        $display("Escenario 1: sincronizacion VGA durante %0d cuadros", NUM_FRAMES);
        check_enable = 1;
        repeat (H_TOTAL * V_TOTAL * NUM_FRAMES - 1) @(posedge clk);
        check_enable = 0;
        @(posedge clk);

        $display("Escenario 2: pipeline de latencia con patron conocido en VRAM");
        begin
            write_vram(19'd0,   1'b1);
            write_vram(19'd1,   1'b1);
            write_vram(19'd2,   1'b1);
            write_vram(19'd3,   1'b1);
            write_vram(19'd4,   1'b1);

            rst = 1'b1;
            @(posedge clk);
            rst = 1'b0;

            repeat(10) @(posedge clk);

            fork
                begin
                    @(negedge clk);
                    while (!(vga_r === 4'hF && vga_g === 4'hF && vga_b === 4'hF))
                        @(negedge clk);
                    $display("  PASS: primer pixel blanco detectado en salida RGB");
                end
                begin
                    repeat(H_TOTAL * V_TOTAL * 2 + 100) @(posedge clk);
                    $error("  TIMEOUT: nunca se detecto pixel blanco en salida RGB");
                end
            join_any
            disable fork;
        end

        $display("Escenario 3: salida negro en zonas de blanking");
        begin
            bit failed;
            failed = 0;

            rst = 1'b1;
            @(posedge clk);
            @(posedge clk);
            rst = 1'b0;

            repeat(H_VISIBLE + 2) @(posedge clk);

            repeat(10) begin
                @(negedge clk);
                if (vga_r !== 4'h0 || vga_g !== 4'h0 || vga_b !== 4'h0) begin
                    $error("  FAIL: RGB != 0 en zona de blanking R=%h G=%h B=%h",
                           vga_r, vga_g, vga_b);
                    failed = 1;
                end
                @(posedge clk);
            end

            if (!failed)
                $display("  PASS: salida negro correcta en blanking horizontal");
        end

        $display("================================================");
        $display("   Simulacion completada");
        $display("================================================");
        $finish;
    end : tester

    bit [9:0] score_hcount    = 10'd0;
    bit [9:0] score_vcount    = 10'd0;
    bit [9:0] score_hcount_d1 = 10'd0;
    bit [9:0] score_hcount_d2 = 10'd0;
    bit [9:0] score_vcount_d1 = 10'd0;
    bit [9:0] score_vcount_d2 = 10'd0;
    bit       score_h_end     = 1'b0;

    always @(negedge clk) begin : scoreboard
        if (rst) begin
            score_hcount    <= 10'd0;
            score_vcount    <= 10'd0;
            score_hcount_d1 <= 10'd0;
            score_hcount_d2 <= 10'd0;
            score_vcount_d1 <= 10'd0;
            score_vcount_d2 <= 10'd0;
            score_h_end     <= 1'b0;
        end else begin
            if (check_enable) begin

                if (hsync !== ~((score_hcount >= H_SYNC_START) &&
                                (score_hcount < H_SYNC_END)))
                    $error("FAIL hsync: got %0b expected %0b en hcount=%0d",
                           hsync,
                           ~((score_hcount >= H_SYNC_START) &&
                             (score_hcount < H_SYNC_END)),
                           score_hcount);

                if (vsync !== ~((score_vcount >= V_SYNC_START) &&
                                (score_vcount < V_SYNC_END)))
                    $error("FAIL vsync: got %0b expected %0b en vcount=%0d",
                           vsync,
                           ~((score_vcount >= V_SYNC_START) &&
                             (score_vcount < V_SYNC_END)),
                           score_vcount);

                if (score_hcount_d2 >= H_VISIBLE || score_vcount_d2 >= V_VISIBLE) begin
                    if (vga_r !== 4'h0 || vga_g !== 4'h0 || vga_b !== 4'h0)
                        $error("FAIL blanking: RGB != 0 en hcount=%0d vcount=%0d",
                               score_hcount_d2, score_vcount_d2);
                end

                if (score_hcount_d2 < H_VISIBLE && score_vcount_d2 < V_VISIBLE) begin
                    if (hsync === 1'b0)
                        $error("FAIL hsync activo en zona visible hcount=%0d",
                               score_hcount);
                    if (vsync === 1'b0)
                        $error("FAIL vsync activo en zona visible vcount=%0d",
                               score_vcount);
                end
            end

            score_hcount_d1 <= score_hcount;
            score_hcount_d2 <= score_hcount_d1;
            score_vcount_d1 <= score_vcount;
            score_vcount_d2 <= score_vcount_d1;

            score_h_end = (score_hcount == H_TOTAL - 1);

            if (score_hcount == H_TOTAL - 1)
                score_hcount <= 10'd0;
            else
                score_hcount <= score_hcount + 10'd1;

            if (score_h_end) begin
                if (score_vcount == V_TOTAL - 1)
                    score_vcount <= 10'd0;
                else
                    score_vcount <= score_vcount + 10'd1;
            end
        end
    end : scoreboard

endmodule : tb_vga_controller