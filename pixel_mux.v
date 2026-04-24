/*
 * Autor:   Jesús Huertas
 * Fecha:   23/04/2026
 *
 * Módulo:  pixel_mux
 *
 * Descripción: Multiplexor de píxel para el controlador VGA. Convierte el
 *              bit de un canal leído desde la VRAM en una salida RGB de 12
 *              bits compatible con el conector VGA de la Nexys A7, donde
 *              cada canal tiene 4 bits de resolución de color.
 *
 *              Cuando el bit de píxel vale 1 la salida es blanco puro y
 *              cuando vale 0 la salida es negro. Adicionalmente, cuando
 *              video_on está inactivo la salida se fuerza a negro
 *              independientemente del valor de la VRAM, lo que es obligatorio
 *              para que el monitor mantenga la sincronización durante los
 *              períodos de blanking horizontal y vertical.
 *
 *              La salida RGB se registra en flip-flops para mejorar el timing
 *              y reducir glitching en la señal de video. Esto introduce una
 *              latencia adicional de un ciclo que el vga_controller compensa
 *              adelantando la dirección de lectura de la VRAM en dos ciclos
 *              respecto al píxel que está siendo procesado.
 *
 * Nota: Los 4 bits por canal corresponden al estándar del conector VGA
 *       de la Nexys A7 xc7a100tcsg324-1, donde R, G y B tienen cada uno
 *       4 bits de resolución para un total de 4096 colores posibles.
 */

module pixel_mux (
    input  wire        clk,       // 25 MHz dominio VGA
    input  wire        pixel_bit, // bit leído de la VRAM, 1=blanco 0=negro
    input  wire        video_on,  // activo cuando estamos en zona visible
    output reg  [3:0]  vga_r,     // canal rojo, 4 bits
    output reg  [3:0]  vga_g,     // canal verde, 4 bits
    output reg  [3:0]  vga_b      // canal azul, 4 bits
);

    always @(posedge clk) begin
        if (video_on && pixel_bit) begin
            vga_r <= 4'hF;
            vga_g <= 4'hF;
            vga_b <= 4'hF;
        end else begin
            vga_r <= 4'h0;
            vga_g <= 4'h0;
            vga_b <= 4'h0;
        end
    end

endmodule