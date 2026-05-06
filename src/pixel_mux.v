//! @title pixel_mux
//! @author Jesús Huertas
//! @date 23/04/2026
//!
//! Multiplexor de píxel para el controlador VGA. Convierte el
//! bit de un canal leído desde la VRAM en una salida RGB de 12
//! bits compatible con el conector VGA de la Nexys A7, donde
//! cada canal tiene 4 bits de resolución de color.
//!
//! La salida RGB se registra en flip-flops para mejorar el timing
//! y reducir glitching. Esto introduce una latencia adicional de
//! un ciclo que vga_controller compensa adelantando la dirección
//! de lectura de la VRAM en dos ciclos.

module pixel_mux (
    input  wire        clk,       //! Reloj de 25 MHz dominio VGA
    input  wire        pixel_bit, //! Bit leído de la VRAM: 1 = blanco, 0 = negro
    input  wire        video_on,  //! Activo cuando el píxel está en la zona visible
    output reg  [3:0]  vga_r,     //! Canal rojo, 4 bits, para conector VGA Nexys A7
    output reg  [3:0]  vga_g,     //! Canal verde, 4 bits, para conector VGA Nexys A7
    output reg  [3:0]  vga_b      //! Canal azul, 4 bits, para conector VGA Nexys A7
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