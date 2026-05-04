//! @title top
//! @author Andrea García Borges / Jesús Huertas
//! @date 23/04/2026
//!
//! Módulo de nivel superior para el reloj digital en la Nexys A7.
//! Integra clock_counter, image_generator, vram, vga_controller
//! y seg7_driver para mostrar la hora en los displays de 7 segmentos
//! y en pantalla VGA en formato HH:MM:SS.
//!
//! - clock_counter opera a 100 MHz y genera la hora actual
//! - image_generator escribe continuamente en la VRAM a 100 MHz
//! - vga_controller lee la VRAM a 25 MHz y genera la señal VGA
//! - seg7_driver multiplexa los displays a 100 MHz
//!
//! El reloj de 25 MHz para el dominio VGA se genera con el
//! Clocking Wizard de Vivado instanciado como clk_wiz_0.
 
module top (
    input  wire       clk,          //! Reloj del sistema, 100 MHz desde oscilador Nexys A7
    input  wire       rst,          //! Reset síncrono activo alto, conectar a BTNC
    input  wire       sw_adjust,    //! Switch de modo ajuste: SW0, 1 = ajuste activo
    input  wire       btn_inc_hour, //! Botón incremento de hora: BTNL
    input  wire       btn_inc_min,  //! Botón incremento de minuto: BTNR
    output wire [6:0] seg,          //! Segmentos de los displays de 7 segmentos, activo bajo
    output wire [7:0] an,           //! Ánodos de los displays, activo bajo
    output wire       dp,           //! Punto decimal, activo bajo
    output wire [3:0] vga_r,        //! Canal rojo VGA, 4 bits, conector J2 Nexys A7
    output wire [3:0] vga_g,        //! Canal verde VGA, 4 bits, conector J2 Nexys A7
    output wire [3:0] vga_b,        //! Canal azul VGA, 4 bits, conector J2 Nexys A7
    output wire       hsync,        //! Sincronización horizontal VGA, conector J2 Nexys A7
    output wire       vsync         //! Sincronización vertical VGA, conector J2 Nexys A7
);
 
    wire [3:0]  hour;      //! Hora interna generada por clock_counter
    wire [5:0]  minute;    //! Minuto interno generado por clock_counter
    wire [5:0]  second;    //! Segundo interno generado por clock_counter
    wire        clk_25;    //! Reloj de 25 MHz generado por clk_wiz_0 para el dominio VGA
    wire        we_a;      //! Señal de escritura de image_generator hacia vram
    wire [18:0] addr_a;    //! Dirección de escritura de image_generator hacia vram
    wire        data_a;    //! Dato de escritura de image_generator hacia vram
    wire [18:0] vram_addr; //! Dirección de lectura de vga_controller hacia vram
    wire        vram_data; //! Dato de lectura de vram hacia vga_controller
 
    //! Clocking Wizard genera 25 MHz para el dominio VGA
    clk_wiz_0 u_clk_wiz (
        .clk_in1 (clk),
        .clk_out1(clk_25),
        .reset   (rst),
        .locked  ()
    );
 
    //! Contador de reloj con ajuste por botones
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
 
    //! Generador de imagen: escribe frame completo en VRAM a 100 MHz
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
 
    //! Memoria de video dual-port: puerto A escritura 100 MHz, puerto B lectura 25 MHz
    vram u_vram (
        .clk_a    (clk),
        .we_a     (we_a),
        .addr_a   (addr_a),
        .data_in_a(data_a),
        .clk_b    (clk_25),
        .addr_b   (vram_addr),
        .data_out_b(vram_data)
    );
 
    //! Controlador VGA: lee VRAM y genera señales al monitor a 25 MHz
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
 
    //! Driver de displays de 7 segmentos multiplexado
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
