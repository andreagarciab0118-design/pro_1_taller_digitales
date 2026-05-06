//! @title edge_detector
//! @author Andrea García Borges
//! @date 23/04/2026
//!
//! Detector de flanco de subida. Genera un pulso de exactamente
//! un ciclo de reloj cuando detecta una transición de 0 a 1 en
//! signal_in. Es el último eslabón de la cadena de
//! acondicionamiento de botones: button_sync → debounce → edge_detector.

module edge_detector (
    input  wire clk,        //! Reloj del sistema
    input  wire rst,        //! Reset síncrono activo alto
    input  wire signal_in,  //! Señal limpia procedente del debounce
    output reg  pulse_out   //! Pulso de 1 ciclo en cada flanco de subida
);

    reg signal_d; //! Versión retrasada un ciclo de signal_in

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