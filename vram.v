/*
 * Autor:  Jesús Huertas
 * Fecha:   20/04/2026
 *
 * Módulo:  vram
 *
 * Descripción: Memoria de video de doble puerto para el sistema VGA Clock.
 *              Almacena el contenido de la pantalla como un mapa de bits de
 *              307,200 posiciones, una por cada píxel de la resolución
 *              640x480, donde cada posición contiene un bit que indica si
 *              el píxel es blanco o negro.
 *
 *              El puerto A está dedicado a la escritura y es usado por el
 *              image_generator para actualizar el contenido de la pantalla.
 *              El puerto B está dedicado a la lectura y es usado por el
 *              vga_controller para obtener el valor de cada píxel durante
 *              el barrido de la pantalla.
 *
 *              Ambos puertos operan de forma completamente independiente y
 *              pueden correr en dominios de reloj distintos, lo que permite
 *              que image_generator opere a 100MHz mientras vga_controller
 *              opera a 25MHz sin ningún conflicto de acceso.
 *
 *  
 *              La memoria se inicializa en ceros para garantizar pantalla
 *              negra al encender la FPGA antes de que image_generator
 *              escriba el contenido.
 *
 * Nota: El código está escrito para que Vivado entienda automáticamente
 *       una True Dual Port BRAM s
 */

module vram (
    input  wire        clk_a,     // reloj puerto escritura (image_generator)
    input  wire        we_a,      // habilitación de escritura, activo alto
    input  wire [18:0] addr_a,    // dirección de escritura (0 a 307199)
    input  wire        data_in_a, // dato a escribir, 1 = blanco, 0 = negro

    input  wire        clk_b,     // reloj puerto lectura (vga_controller, 25MHz)
    input  wire [18:0] addr_b,    // dirección de lectura
    output reg         data_out_b // dato leído, disponible un ciclo después
);

    localparam DEPTH = 640 * 480;

    reg [0:0] mem [0:DEPTH-1];

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