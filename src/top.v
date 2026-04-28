/*
 * Autor:   Andrea García Borges
 * Fecha:   23/04/2026
 *
 * Módulo:  top
 *
 * Descripción: Módulo de nivel superior para el reloj digital en la Nexys A7.
 *              Integra clock_counter, image_generator, vram, vga_controller
 *              y seg7_driver para mostrar la hora en los displays de 7
 *              segmentos y en pantalla VGA en formato HH:MM:SS.
 *
 *              El clock_counter opera a 100 MHz y genera la hora actual.
 *              El image_generator escribe continuamente en la VRAM a 100 MHz.
 *              El vga_controller lee la VRAM a 25 MHz y genera la señal VGA.
 *              El seg7_driver multiplexa los displays a 100 MHz.
 *
 *              El reloj de 25 MHz para el dominio VGA debe generarse con el
 *              Clocking Wizard de Vivado instanciado como clk_wiz_0.
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
 
    // Clocking Wizard genera 25 MHz para el dominio VGA
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
        .clk        (clk_25),
        .rst        (rst),
        .vram_data_in(vram_data),
        .vram_addr  (vram_addr),
        .hsync      (hsync),
        .vsync      (vsync),
        .vga_r      (vga_r),
        .vga_g      (vga_g),
        .vga_b      (vga_b)
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
