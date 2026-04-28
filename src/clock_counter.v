/*
 * Módulo:  clock_counter
 *
 * Descripción: Módulo de control y conteo de hora para el sistema VGA Clock.
 *              Mantiene la hora en formato 12 h (1-12), minutos (0-59) y
 *              segundos (0-59). En modo normal avanza automáticamente a 1 Hz
 *              mediante un divisor de frecuencia interno. En modo ajuste el
 *              divisor se congela y los botones permiten modificar la hora
 *              y los minutos de forma interactiva.
 *
 * Parámetros:
 *   CLK_FREQ      Frecuencia del sistema en Hz
 *   DEBOUNCE_MAX  Ciclos de estabilidad para el filtro anti-rebote
 *
 * Puertos:
 *   clk          Reloj del sistema
 *   rst          Reset síncrono activo alto
 *   sw_adjust    Switch de modo ajuste, 1 activa ajuste
 *   btn_inc_hour Botón físico para incrementar la hora
 *   btn_inc_min  Botón físico para incrementar el minuto
 *   hour         Hora actual en formato 12 h, rango 1-12
 *   minute       Minuto actual, rango 0-59
 *   second       Segundo actual, rango 0-59
 */
module clock_counter #(
    parameter CLK_FREQ     = 100_000_000,
    parameter DEBOUNCE_MAX = 1_000_000
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       sw_adjust,
    input  wire       btn_inc_hour,
    input  wire       btn_inc_min,
    output reg  [3:0] hour,
    output reg  [5:0] minute,
    output reg  [5:0] second
);
    wire btn_hour_sync,  btn_min_sync;
    wire btn_hour_clean, btn_min_clean;
    wire btn_hour_pulse, btn_min_pulse;
 
    reg [31:0] tick_counter;
    wire       tick_1hz = (tick_counter == CLK_FREQ - 1);
 
    always @(posedge clk) begin
        if (rst || sw_adjust) tick_counter <= 32'd0;
        else if (tick_1hz)    tick_counter <= 32'd0;
        else                  tick_counter <= tick_counter + 32'd1;
    end
 
    button_sync sync_hour (
        .clk     (clk),
        .btn_in  (btn_inc_hour),
        .btn_sync(btn_hour_sync)
    );
 
    debounce #(.MAX_COUNT(DEBOUNCE_MAX)) db_hour (
        .clk      (clk),
        .rst      (rst),
        .noisy_in (btn_hour_sync),
        .clean_out(btn_hour_clean)
    );
 
    edge_detector ed_hour (
        .clk       (clk),
        .rst       (rst),
        .signal_in (btn_hour_clean),
        .pulse_out (btn_hour_pulse)
    );
 
    button_sync sync_min (
        .clk     (clk),
        .btn_in  (btn_inc_min),
        .btn_sync(btn_min_sync)
    );
 
    debounce #(.MAX_COUNT(DEBOUNCE_MAX)) db_min (
        .clk      (clk),
        .rst      (rst),
        .noisy_in (btn_min_sync),
        .clean_out(btn_min_clean)
    );
 
    edge_detector ed_min (
        .clk       (clk),
        .rst       (rst),
        .signal_in (btn_min_clean),
        .pulse_out (btn_min_pulse)
    );
 
    wire sec_tick  = tick_1hz && !sw_adjust;
    wire min_tick  = sec_tick && (second == 6'd59);
    wire hour_tick = min_tick && (minute == 6'd59);
 
    always @(posedge clk) begin
        if (rst)           second <= 6'd0;
        else if (sec_tick) second <= (second == 6'd59) ? 6'd0 : second + 6'd1;
    end
 
    always @(posedge clk) begin
        if (rst)                             minute <= 6'd0;
        else if (sw_adjust && btn_min_pulse) minute <= (minute == 6'd59) ? 6'd0 : minute + 6'd1;
        else if (min_tick)                   minute <= (minute == 6'd59) ? 6'd0 : minute + 6'd1;
    end
 
    always @(posedge clk) begin
        if (rst)                              hour <= 4'd12;
        else if (sw_adjust && btn_hour_pulse) hour <= (hour == 4'd12) ? 4'd1 : hour + 4'd1;
        else if (hour_tick)                   hour <= (hour == 4'd12) ? 4'd1 : hour + 4'd1;
    end
 
endmodule
