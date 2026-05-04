//! @title debounce
//! @author Andrea García Borges
//! @date 23/04/2026
//!
//! Filtro anti-rebote digital basado en contador. Solo propaga
//! el nuevo nivel cuando la señal permanece estable durante
//! MAX_COUNT ciclos consecutivos. Si cambia antes, el contador
//! se reinicia desde cero.

module debounce #(
    parameter MAX_COUNT = 1_000_000 //! Ciclos de estabilidad requeridos. Para 100 MHz con 10 ms usar 1_000_000
)(
    input  wire clk,       //! Reloj del sistema
    input  wire rst,       //! Reset síncrono activo alto
    input  wire noisy_in,  //! Señal ruidosa ya sincronizada por button_sync
    output reg  clean_out  //! Señal filtrada y estable
);

    reg [19:0] count;      //! Contador de ciclos estables
    reg        noisy_prev; //! Valor anterior de la señal para detectar cambios

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