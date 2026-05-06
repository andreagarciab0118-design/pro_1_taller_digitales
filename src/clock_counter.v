//! @title clock_counter
//! @author Andrea García Borges
//! @date 23/04/2026
//!
//! Módulo de control y conteo de hora para el sistema VGA Clock.
//! Mantiene la hora en formato 12 h (1-12), minutos (0-59) y
//! segundos (0-59). En modo normal avanza automáticamente a 1 Hz
//! mediante un divisor de frecuencia interno. En modo ajuste el
//! divisor se congela y los botones permiten modificar la hora
//! y los minutos de forma interactiva.

module clock_counter #(
    parameter CLK_FREQ     = 100_000_000, //! Frecuencia del sistema en Hz
    parameter DEBOUNCE_MAX = 1_000_000    //! Ciclos de estabilidad para el filtro anti-rebote
)(
    input  wire       clk,          //! Reloj del sistema
    input  wire       rst,          //! Reset síncrono activo alto
    input  wire       sw_adjust,    //! Switch de modo ajuste: 1 activa ajuste
    input  wire       btn_inc_hour, //! Botón físico para incrementar la hora
    input  wire       btn_inc_min,  //! Botón físico para incrementar el minuto
    output reg  [3:0] hour,         //! Hora actual en formato 12 h, rango 1-12
    output reg  [5:0] minute,       //! Minuto actual, rango 0-59
    output reg  [5:0] second        //! Segundo actual, rango 0-59
);

    wire btn_hour_sync,  btn_min_sync;
    wire btn_hour_clean, btn_min_clean;
    wire btn_hour_pulse, btn_min_pulse;

    reg [31:0] tick_counter; //! Divisor de frecuencia para generar tick de 1 Hz
    wire tick_1hz = (tick_counter == CLK_FREQ - 1); //! Pulso activo cada segundo

    always @(posedge clk) begin
        if (rst || sw_adjust) tick_counter <= 32'd0;
        else if (tick_1hz)    tick_counter <= 32'd0;
        else                  tick_counter <= tick_counter + 32'd1;
    end

    //! Cadena de acondicionamiento para botón de hora
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

    //! Cadena de acondicionamiento para botón de minuto
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

    wire sec_tick  = tick_1hz && !sw_adjust; //! Tick de segundo en modo normal
    wire min_tick  = sec_tick && (second == 6'd59); //! Tick de minuto
    wire hour_tick = min_tick && (minute == 6'd59); //! Tick de hora

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