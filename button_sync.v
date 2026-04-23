
/*
 * Autor:   Andrea García Borges
 * Fecha:   22/04/2026
 *
 * Módulo:  button_sync
 *
 * Descripción: Sincronizador de dos flip-flops para señales de botón
 *              provenientes de dominios asíncronos externos. Elimina el
 *              riesgo de metaestabilidad al capturar la señal en dos
 *              etapas consecutivas del dominio de reloj del sistema.
 *
 * Puertos:
 *   clk      Reloj del sistema
 *   btn_in   Señal de botón directa desde el pin físico
 *   btn_sync Señal sincronizada, libre de metaestabilidad
 */
module button_sync (
    input  wire clk,
    input  wire btn_in,
    output reg  btn_sync
);
    reg ff1;
 
    always @(posedge clk) begin
        ff1      <= btn_in;
        btn_sync <= ff1;
    end
 
endmodule
