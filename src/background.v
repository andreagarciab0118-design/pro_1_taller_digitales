//! @title background_gen
//! @author Andrea García Borges
//! @date 23/04/2026
//!
//! Generador combinacional de píxeles de fondo para la pantalla
//! VGA 640x480. Produce un fondo negro con un doble marco blanco
//! en el perímetro y un patrón decorativo de damero en las cuatro
//! esquinas usando XOR de bits de coordenada. El patrón alterna
//! bloques de 8x8 píxeles blancos y negros en las esquinas,
//! enmarcando el área del reloj sin interferir con el texto central.

module background_gen (
    input  wire [9:0] px,        //! Coordenada horizontal, rango 0-639
    input  wire [9:0] py,        //! Coordenada vertical, rango 0-479
    output wire       pixel_val  //! Valor del píxel: 1 = blanco, 0 = negro
);

    wire border_outer = (px == 10'd0)   || (px == 10'd1)   ||
                        (px == 10'd638) || (px == 10'd639) ||
                        (py == 10'd0)   || (py == 10'd1)   ||
                        (py == 10'd478) || (py == 10'd479);

    wire border_inner = (px == 10'd4)   || (px == 10'd5)   ||
                        (px == 10'd634) || (px == 10'd635) ||
                        (py == 10'd4)   || (py == 10'd5)   ||
                        (py == 10'd474) || (py == 10'd475);

    wire in_corner = ((px <= 10'd80) || (px >= 10'd559)) &&
                     ((py <= 10'd60) || (py >= 10'd419));

    wire corner_pattern = px[3] ^ py[3]; //! XOR de bit 3: alterna bloques 8x8

    assign pixel_val = border_outer || border_inner || (in_corner && corner_pattern);

endmodule