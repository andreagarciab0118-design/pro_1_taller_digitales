//! @title button_sync
//! @author Andrea García Borges
//! @date 23/04/2026
//!
//! Sincronizador de dos flip-flops para señales de botón
//! provenientes de dominios asíncronos externos. Elimina el
//! riesgo de metaestabilidad al capturar la señal en dos
//! etapas consecutivas del dominio de reloj del sistema.

module button_sync (
    input  wire clk,      //! Reloj del sistema
    input  wire btn_in,   //! Señal de botón directa desde el pin físico
    output reg  btn_sync  //! Señal sincronizada, libre de metaestabilidad
);

    reg ff1; //! Primer flip-flop de sincronización

    always @(posedge clk) begin
        ff1      <= btn_in;
        btn_sync <= ff1;
    end

endmodule