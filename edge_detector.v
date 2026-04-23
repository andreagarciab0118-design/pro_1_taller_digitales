/*
 * Autor:   Andrea García Borges
 * Fecha:   22/04/2026
 *
 * Módulo:  edge_detector
 *
 * Descripción: Detector de flanco de subida. Genera un pulso de exactamente
 *              un ciclo de reloj cuando detecta una transición de 0 a 1 en
 *              signal_in. Es el último eslabón de la cadena de
 *              acondicionamiento de botones.
 *
 * Puertos:
 *   clk        Reloj del sistema
 *   rst        Reset síncrono activo alto
 *   signal_in  Señal limpia procedente del debounce
 *   pulse_out  Pulso de 1 ciclo en cada flanco de subida
 */
module edge_detector (
    input  wire clk,
    input  wire rst,
    input  wire signal_in,
    output reg  pulse_out
);
    reg signal_d;
 
    always @(posedge clk) begin
        if (rst) begin
            signal_d  <= 1'b0;
            pulse_out <= 1'b0;
        end else begin
            pulse_out <= signal_in & ~signal_d;
            signal_d  <= signal_in;
        end
    end
 
endmodule
