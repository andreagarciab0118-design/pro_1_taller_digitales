//! @title top_sim
//! @author Andrea García Borges
//! @date 23/04/2026
//!
//! Versión del módulo top para simulación con iverilog.
//! Replica la estructura del top de síntesis, pero reemplaza
//! el IP clk_wiz_0 por un stub que pasa el reloj directamente
//! y activa la señal locked de inmediato.
//!
//! Este archivo es SOLO para simulación.
//! Para síntesis en Vivado usar top.v con el IP real.
//!
//! Flujo general:
//! - Genera tiempo (clock_counter)
//! - Genera imagen (image_generator)
//! - Almacena en VRAM
//! - Controla VGA (vga_controller)
//! - Muestra hora en 7 segmentos (seg7_driver)
//!
//! Compilar:
//! iverilog -g2012 -o sim/tb_top.vvp \
//! tb/tb_top.sv \
//! src/top_sim.v \
//! src/background.v \
//! src/button_sync.v \
//! src/clock_counter.v \
//! src/debounce.v \
//! src/edge_detector.v \
//! src/font_rom.v \
//! src/h_sync_gen.v \
//! src/image_generator.v \
//! src/pixel_mux.v \
//! src/seg7_driver.v \
//! src/v_sync_gen.v \
//! src/vga_controller.v \
//! src/vram.v
//!
//! Ejecutar:
//! vvp sim/tb_top.vvp

module top (
    input  wire       clk,           //! Reloj principal del sistema (100 MHz)
    input  wire       rst,           //! Reset síncrono activo alto
    input  wire       sw_adjust,     //! Habilita modo ajuste de hora
    input  wire       btn_inc_hour,  //! Incrementa hora manualmente
    input  wire       btn_inc_min,   //! Incrementa minutos manualmente
    output wire [6:0] seg,           //! Segmentos display 7 segmentos (activo bajo)
    output wire [7:0] an,            //! Selección de display (activo bajo)
    output wire       dp,            //! Punto decimal (activo bajo)
    output wire [3:0] vga_r,         //! Canal rojo VGA (4 bits)
    output wire [3:0] vga_g,         //! Canal verde VGA (4 bits)
    output wire [3:0] vga_b,         //! Canal azul VGA (4 bits)
    output wire       hsync,         //! Señal de sincronización horizontal VGA
    output wire       vsync          //! Señal de sincronización vertical VGA
);

    //! Señales internas de tiempo
    wire [3:0]  hour;
    wire [5:0]  minute;
    wire [5:0]  second;

    //! Señales de reloj
    wire        clk_25;

    //! Interfaz de escritura VRAM
    wire        we_a;
    wire [18:0] addr_a;
    wire        data_a;

    //! Interfaz de lectura VRAM
    wire [18:0] vram_addr;
    wire        vram_data;
 
    //! Stub de reloj: en simulación no se divide frecuencia
    clk_wiz_0 u_clk_wiz (
        .clk_in1 (clk),
        .clk_out1(clk_25),
        .reset   (rst),
        .locked  ()
    );
 
    //! Generador de hora, minuto y segundo
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
 
    //! Generador de imagen basado en la hora actual
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
 
    //! Memoria de video (doble puerto)
    vram u_vram (
        .clk_a    (clk),
        .we_a     (we_a),
        .addr_a   (addr_a),
        .data_in_a(data_a),
        .clk_b    (clk_25),
        .addr_b   (vram_addr),
        .data_out_b(vram_data)
    );
 
    //! Controlador VGA: genera sincronización y RGB
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
 
    //! Driver de displays de 7 segmentos
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
 
//! =============================================================
//! Stub clk_wiz_0 — SOLO PARA SIMULACIÓN
//! Pasa clk_in1 directamente a clk_out1 y fija locked en 1.
//! En síntesis este módulo es reemplazado por el IP real.
//! =============================================================
module clk_wiz_0 (
    input  wire clk_in1,   //! Reloj de entrada
    output wire clk_out1,  //! Reloj de salida (igual al de entrada)
    input  wire reset,     //! Reset (no utilizado en stub)
    output wire locked     //! Indica reloj estable (siempre 1 en simulación)
);
    assign clk_out1 = clk_in1;
    assign locked   = 1'b1;
endmodule