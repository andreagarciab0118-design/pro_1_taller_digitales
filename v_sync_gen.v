/*
 * Autor:   Jesús Huertas
 * Fecha:   20/04/2026
 *
 * Módulo:  v_sync_gen
 *
 * Descripción: Generador de sincronización vertical para el estándar VGA
 *              640x480  60Hz. Implementa un contador de 10 bits que avanza
 *              únicamente cuando recibe el pulso h_end proveniente de
 *              h_sync_gen, lo que lo acopla  al barrido horizontal
 *              sin necesidad de conocer el valor interno de hcount.
 *
 *              El contador completo se expone como vcount para que módulos
 *              superiores como pixel_mux puedan conocer la fila actual del
 *              barrido.
 *
 * Parámetros del estándar VGA 640x480 @ 60Hz:
 *              Zona visible:    480 líneas (0   a 479)
 *              Front porch:      10 líneas (480 a 489)
 *              Pulso vsync:       2 líneas (490 a 491)
 *              Back porch:       33 líneas (492 a 524)
 *              Total:           525 líneas
 *
 * nota: Este módulo asume que h_end proviene de h_sync_gen y está activo
 *       exactamente un ciclo de 25MHz cuando hcount vale 799.
 */

module v_sync_gen (
    input  wire        clk,    // 25 MHz dominio VGA
    input  wire        rst,    // reset síncrono activo alto
    input  wire        h_end,  // pulso de fin de línea desde h_sync_gen
    output reg  [9:0]  vcount, // posición vertical actual (0 a 524)
    output wire        vsync,  // sincronización vertical, activo bajo
    output wire        vblank  // activo cuando vcount >= 480
);

    localparam V_VISIBLE    = 480;
    localparam V_FP         = 10;
    localparam V_SYNC_START = V_VISIBLE + V_FP;   // 490
    localparam V_SYNC_END   = V_SYNC_START + 2;   // 492
    localparam V_TOTAL      = 525;

    always @(posedge clk) begin
        if (rst) begin
            vcount <= 10'd0;
        end else if (h_end) begin
            if (vcount == V_TOTAL - 1)
                vcount <= 10'd0;
            else
                vcount <= vcount + 10'd1;
        end
    end

    assign vsync  = ~((vcount >= V_SYNC_START) && (vcount < V_SYNC_END));
    assign vblank =   (vcount >= V_VISIBLE);

endmodule