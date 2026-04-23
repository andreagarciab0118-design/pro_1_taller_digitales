
/*
 * Autor:   Andrea García Borges
 * Fecha:   22/04/2026
 *
 * Módulo:  debounce
 *
 * Descripción: Filtro anti-rebote digital basado en contador. Solo propaga
 *              el nuevo nivel cuando la señal permanece estable durante
 *              MAX_COUNT ciclos consecutivos. Si cambia antes, el contador
 *              se reinicia desde cero.
 *
 * Parámetros:
 *   MAX_COUNT  Ciclos de estabilidad requeridos antes de aceptar el nivel.
 *              Para 100 MHz con 10 ms de filtrado usar 1_000_000.
 *
 * Puertos:
 *   clk       Reloj del sistema
 *   rst       Reset síncrono activo alto
 *   noisy_in  Señal ruidosa ya sincronizada por button_sync
 *   clean_out Señal filtrada y estable
 */
module debounce #(
    parameter MAX_COUNT = 1_000_000
)(
    input  wire clk,
    input  wire rst,
    input  wire noisy_in,
    output reg  clean_out
);
    reg [19:0] count;
    reg        noisy_prev;
 
    always @(posedge clk) begin
        if (rst) begin
            count      <= 20'd0;
            noisy_prev <= 1'b0;
            clean_out  <= 1'b0;
        end else begin
            if (noisy_in != noisy_prev) begin
                count      <= 20'd0;
                noisy_prev <= noisy_in;
            end else if (count < MAX_COUNT) begin
                count <= count + 20'd1;
            end else begin
                clean_out <= noisy_prev;
            end
        end
    end
 
endmodule
