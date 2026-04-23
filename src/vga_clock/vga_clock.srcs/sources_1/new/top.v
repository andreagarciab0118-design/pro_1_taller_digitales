/*

 * Módulo:  top
 *
 * Descripción: Módulo de nivel superior para el reloj digital en la Nexys A7.
 *              Conecta clock_counter con seg7_driver para mostrar la hora en
 *              formato HH:MM:SS sobre los displays de 7 segmentos.
 *
 *              Controles físicos:
 *                BTNC  rst          Reset del sistema
 *                SW0   sw_adjust    Activa el modo de ajuste de hora
 *                BTNL  btn_inc_hour Incrementa la hora en modo ajuste
 *                BTNR  btn_inc_min  Incrementa el minuto en modo ajuste
 *
 * Puertos:
 *   clk          Reloj 100 MHz, pin E3
 *   rst          Boton central BTNC, pin N17
 *   sw_adjust    Switch SW0, pin J15
 *   btn_inc_hour Boton izquierdo BTNL, pin P17
 *   btn_inc_min  Boton derecho BTNR, pin M17
 *   seg          Segmentos del display, activos en bajo
 *   an           Anodos del display, activos en bajo
 *   dp           Punto decimal, activo en bajo
 */
module top (
    input  wire       clk,
    input  wire       rst,
    input  wire       sw_adjust,
    input  wire       btn_inc_hour,
    input  wire       btn_inc_min,
    output wire [6:0] seg,
    output wire [7:0] an,
    output wire       dp
);
    wire [3:0] hour;
    wire [5:0] minute;
    wire [5:0] second;
 
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
