
//! @title vram
//! @author Jesús Huertas
//! @date 20/04/2026
//!
//! Memoria de video de doble puerto para el sistema VGA Clock.
//! Almacena el contenido de la pantalla como un mapa de bits de
//! 307,200 posiciones (640x480), donde cada posición contiene un
//! bit que indica si el píxel es blanco (1) o negro (0).
//!
//! Puerto A: escritura exclusiva por image_generator a 100 MHz.
//! Puerto B: lectura exclusiva por vga_controller a 25 MHz.
//!
//! Ambos puertos operan de forma independiente en dominios de reloj
//! distintos sin ningún conflicto de acceso. La memoria se inicializa
//! en ceros para garantizar pantalla negra al encender la FPGA.

module vram (
    input  wire        clk_a,      //! Reloj del puerto de escritura, 100 MHz
    input  wire        we_a,       //! Habilitación de escritura, activo alto
    input  wire [18:0] addr_a,     //! Dirección de escritura, rango 0-307199
    input  wire        data_in_a,  //! Dato a escribir: 1 = blanco, 0 = negro
    input  wire        clk_b,      //! Reloj del puerto de lectura, 25 MHz
    input  wire [18:0] addr_b,     //! Dirección de lectura, rango 0-307199
    output reg         data_out_b  //! Dato leído, disponible un ciclo después
);

    localparam DEPTH = 640 * 480; //! Número total de píxeles = 307,200

    reg [0:0] mem [0:DEPTH-1]; //! Mapa de bits de la pantalla en BRAM dual-port

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 1'b0;
    end

    always @(posedge clk_a) begin
        if (we_a)
            mem[addr_a] = data_in_a;
    end

    always @(posedge clk_b) begin
        data_out_b <= mem[addr_b];
    end
endmodule

