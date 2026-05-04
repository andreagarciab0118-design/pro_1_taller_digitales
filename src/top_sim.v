/*
 * Autor:   Andrea García Borges
 * Fecha:   23/04/2026
 *
 * Módulo:  top_sim
 *
 * Descripción: Versión del top para simulación con iverilog.
 *              Idéntico al top de síntesis, pero incluye al final un stub
 *              de clk_wiz_0 que pasa el reloj directamente (sin dividir)
 *              y activa locked de inmediato, reemplazando el IP de Vivado
 *              que no existe en iverilog.
 *
 *              NO usar este archivo para síntesis en Vivado.
 *              Para síntesis usar top.v con el IP real clk_wiz_0.
 *
 * Compilar:
    iverilog -g2012 -o sim/tb_top.vvp \
    tb/tb_top.sv \
    src/top_sim.v \
    src/background.v \
    src/button_sync.v \
    src/clock_counter.v \
    src/debounce.v \
    src/edge_detector.v \
    src/font_rom.v \
    src/h_sync_gen.v \
    src/image_generator.v \
    src/pixel_mux.v \
    src/seg7_driver.v \
    src/v_sync_gen.v \
    src/vga_controller.v \
    src/vram.v
 *
 * Ejecutar:
 *   vvp sim/tb_top.vvp
 */
module top (
    input  wire       clk,
    input  wire       rst,
    input  wire       sw_adjust,
    input  wire       btn_inc_hour,
    input  wire       btn_inc_min,
    output wire [6:0] seg,
    output wire [7:0] an,
    output wire       dp,
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b,
    output wire       hsync,
    output wire       vsync
);
    wire [3:0]  hour;
    wire [5:0]  minute;
    wire [5:0]  second;
    wire        clk_25;
    wire        we_a;
    wire [18:0] addr_a;
    wire        data_a;
    wire [18:0] vram_addr;
    wire        vram_data;
 
    // Stub de simulación: pasa el reloj directo y locked = 1
    clk_wiz_0 u_clk_wiz (
        .clk_in1 (clk),
        .clk_out1(clk_25),
        .reset   (rst),
        .locked  ()
    );
 
    clock_counter #(
        .CLK_FREQ    (100_000_000),
        .DEBOUNCE_MAX(1_000_000)
    ) u_clock (
        .clk         (clk),
        .rst         (rst),
        .sw_adjust   (sw_adjust),
        .btn_inc_hour(btn_inc_hour),
        .btn_inc_min (btn_inc_min),
        .hour        (hour),
        .minute      (minute),
        .second      (second)
    );
 
    image_generator u_img_gen (
        .clk   (clk),
        .rst   (rst),
        .hour  (hour),
        .minute(minute),
        .second(second),
        .we_a  (we_a),
        .addr_a(addr_a),
        .data_a(data_a)
    );
 
    vram u_vram (
        .clk_a    (clk),
        .we_a     (we_a),
        .addr_a   (addr_a),
        .data_in_a(data_a),
        .clk_b    (clk_25),
        .addr_b   (vram_addr),
        .data_out_b(vram_data)
    );
 
    vga_controller u_vga (
        .clk         (clk_25),
        .rst         (rst),
        .vram_data_in(vram_data),
        .vram_addr   (vram_addr),
        .hsync       (hsync),
        .vsync       (vsync),
        .vga_r       (vga_r),
        .vga_g       (vga_g),
        .vga_b       (vga_b)
    );
 
    seg7_driver u_seg7 (
        .clk   (clk),
        .rst   (rst),
        .hour  (hour),
        .minute(minute),
        .second(second),
        .seg   (seg),
        .an    (an),
        .dp    (dp)
    );
 
endmodule
 
// =============================================================
//  Stub clk_wiz_0 — SOLO PARA SIMULACIÓN
//  Pasa clk_in1 directo a clk_out1 y activa locked = 1.
//  En síntesis este módulo es reemplazado por el IP de Vivado.
// =============================================================
module clk_wiz_0 (
    input  wire clk_in1,
    output wire clk_out1,
    input  wire reset,
    output wire locked
);
    assign clk_out1 = clk_in1;
    assign locked   = 1'b1;
endmodule
