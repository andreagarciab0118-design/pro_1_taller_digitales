//! @title image_generator
//! @author Andrea García Borges
//! @date 23/04/2026
//!
//! Módulo generador de imagen para el sistema VGA Clock. Escribe
//! continuamente en el puerto A de la VRAM el contenido de un
//! frame completo a 100 MHz. En cada ciclo produce el valor del
//! píxel correspondiente combinando el fondo de background_gen
//! con el texto del reloj renderizado usando la fuente de font_rom.
//!
//! El texto se muestra en formato HH:MM:SS centrado en pantalla
//! con una fuente de 8x16 píxeles escalada 4 veces, produciendo
//! caracteres de 32x64 píxeles en las coordenadas x=192-447 e y=208-271.
//!
//! Pipeline de dos etapas para compensar la latencia de 1 ciclo de la BRAM:
//! - Etapa 0: calcula dirección a font_rom y registra metadatos del píxel
//! - Etapa 1: con datos de fuente disponibles, calcula pixel final y escribe en VRAM

module image_generator (
    input  wire        clk,    //! Reloj del sistema a 100 MHz
    input  wire        rst,    //! Reset síncrono activo alto
    input  wire [3:0]  hour,   //! Hora actual, rango 1-12
    input  wire [5:0]  minute, //! Minuto actual, rango 0-59
    input  wire [5:0]  second, //! Segundo actual, rango 0-59
    output wire        we_a,   //! Habilitación de escritura al puerto A de VRAM, siempre activo
    output wire [18:0] addr_a, //! Dirección de escritura en VRAM, rango 0-307199
    output wire        data_a  //! Dato a escribir en VRAM: 1 = blanco, 0 = negro
);

    localparam H_RES   = 640; //! Resolución horizontal en píxeles
    localparam V_RES   = 480; //! Resolución vertical en píxeles
    localparam TEXT_X0 = 192; //! Coordenada X de inicio del área de texto
    localparam TEXT_X1 = 448; //! Coordenada X de fin del área de texto
    localparam TEXT_Y0 = 208; //! Coordenada Y de inicio del área de texto
    localparam TEXT_Y1 = 272; //! Coordenada Y de fin del área de texto

    reg [9:0]  px, py;   //! Contadores de posición de píxel horizontal y vertical
    reg [18:0] paddr;    //! Dirección lineal del píxel actual en VRAM

    always @(posedge clk) begin
        if (rst) begin
            px <= 0; py <= 0; paddr <= 0;
        end else if (px == H_RES - 1) begin
            px <= 0;
            if (py == V_RES - 1) begin
                py <= 0; paddr <= 0;
            end else begin
                py    <= py + 1;
                paddr <= paddr + 1;
            end
        end else begin
            px    <= px + 1;
            paddr <= paddr + 1;
        end
    end

    // Conversión BCD de hora
    wire [3:0] h_tens  = (hour >= 4'd10) ? 4'd1 : 4'd0;
    wire [3:0] h_units = (hour >= 4'd10) ? hour - 4'd10 : hour;

    // Conversión BCD de minuto
    wire [3:0] m_tens = (minute >= 6'd50) ? 4'd5 :
                        (minute >= 6'd40) ? 4'd4 :
                        (minute >= 6'd30) ? 4'd3 :
                        (minute >= 6'd20) ? 4'd2 :
                        (minute >= 6'd10) ? 4'd1 : 4'd0;
    wire [5:0] m_sub  = (minute >= 6'd50) ? minute - 6'd50 :
                        (minute >= 6'd40) ? minute - 6'd40 :
                        (minute >= 6'd30) ? minute - 6'd30 :
                        (minute >= 6'd20) ? minute - 6'd20 :
                        (minute >= 6'd10) ? minute - 6'd10 : minute;
    wire [3:0] m_units = m_sub[3:0];

    // Conversión BCD de segundo
    wire [3:0] s_tens = (second >= 6'd50) ? 4'd5 :
                        (second >= 6'd40) ? 4'd4 :
                        (second >= 6'd30) ? 4'd3 :
                        (second >= 6'd20) ? 4'd2 :
                        (second >= 6'd10) ? 4'd1 : 4'd0;
    wire [5:0] s_sub  = (second >= 6'd50) ? second - 6'd50 :
                        (second >= 6'd40) ? second - 6'd40 :
                        (second >= 6'd30) ? second - 6'd30 :
                        (second >= 6'd20) ? second - 6'd20 :
                        (second >= 6'd10) ? second - 6'd10 : second;
    wire [3:0] s_units = s_sub[3:0];

    wire in_text = (px >= TEXT_X0) && (px < TEXT_X1) &&
                   (py >= TEXT_Y0) && (py < TEXT_Y1); //! Activo cuando el píxel está en el área de texto

    wire [9:0] rel_x = px - 10'd192; //! Coordenada X relativa al área de texto
    wire [9:0] rel_y = py - 10'd208; //! Coordenada Y relativa al área de texto

    wire [2:0] char_pos        = rel_x[7:5]; //! Índice del carácter en la fila (0-7)
    wire [2:0] pixel_in_char_x = rel_x[4:2]; //! Columna del píxel dentro del carácter escalado
    wire [3:0] pixel_in_char_y = rel_y[5:2]; //! Fila del píxel dentro del carácter escalado

    reg [3:0] char_code; //! Código del carácter actual: 0-9 = dígito, 10 = ':'

    always @(*) begin
        case (char_pos)
            3'd0: char_code = h_tens;
            3'd1: char_code = h_units;
            3'd2: char_code = 4'd10;
            3'd3: char_code = m_tens;
            3'd4: char_code = m_units;
            3'd5: char_code = 4'd10;
            3'd6: char_code = s_tens;
            3'd7: char_code = s_units;
            default: char_code = 4'd0;
        endcase
    end

    //! Instancia del generador de fondo
    wire bg_pixel;
    background_gen u_bg (
        .px       (px),
        .py       (py),
        .pixel_val(bg_pixel)
    );

    //! Instancia de la ROM de fuente
    wire [7:0] font_row;
    font_rom u_font (
        .clk     (clk),
        .addr    ({char_code, pixel_in_char_y}),
        .data_out(font_row)
    );

    // Registros de pipeline etapa 0 → etapa 1
    reg [18:0] addr_s1;    //! Dirección VRAM retrasada un ciclo
    reg        in_text_s1; //! Indicador de zona de texto retrasado un ciclo
    reg [2:0]  col_s1;     //! Columna de píxel en carácter retrasada un ciclo
    reg        bg_s1;      //! Píxel de fondo retrasado un ciclo

    always @(posedge clk) begin
        if (rst) begin
            addr_s1    <= 0;
            in_text_s1 <= 0;
            col_s1     <= 0;
            bg_s1      <= 0;
        end else begin
            addr_s1    <= paddr;
            in_text_s1 <= in_text;
            col_s1     <= pixel_in_char_x;
            bg_s1      <= bg_pixel;
        end
    end

    wire text_pixel  = font_row[3'd7 - col_s1]; //! Bit del bitmap correspondiente a la columna actual
    wire final_pixel = in_text_s1 ? text_pixel : bg_s1; //! Píxel final: texto sobre fondo

    assign we_a   = 1'b1;
    assign addr_a = addr_s1;
    assign data_a = final_pixel;

endmodule