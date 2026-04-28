/*
 * Autor:   Andrea García Borges
 * Fecha:   23/04/2026
 *
 * Módulo:  image_generator
 *
 * Descripción: Módulo generador de imagen para el sistema VGA Clock. Escribe
 *              continuamente en el puerto A de la VRAM el contenido de un
 *              frame completo a 100 MHz. En cada ciclo produce el valor del
 *              píxel correspondiente combinando el fondo de background_gen
 *              con el texto del reloj renderizado usando la fuente de font_rom.
 *
 *              El texto se muestra en formato HH:MM:SS centrado en pantalla
 *              con una fuente de 8x16 píxeles escalada 4 veces, produciendo
 *              caracteres de 32x64 píxeles en las coordenadas x=192-447 e
 *              y=208-271.
 *
 *              El módulo implementa un pipeline de dos etapas para compensar
 *              la latencia de un ciclo de la BRAM en font_rom. En la etapa 0
 *              se calcula la dirección a la fuente y se registran los metadatos
 *              del píxel. En la etapa 1, con los datos de la fuente disponibles,
 *              se calcula el valor final y se escribe en la VRAM.
 */
module image_generator (
    input  wire        clk,
    input  wire        rst,
    input  wire [3:0]  hour,
    input  wire [5:0]  minute,
    input  wire [5:0]  second,
    output wire        we_a,
    output wire [18:0] addr_a,
    output wire        data_a
);
    localparam H_RES   = 640;
    localparam V_RES   = 480;
    localparam TEXT_X0 = 192;
    localparam TEXT_X1 = 448;
    localparam TEXT_Y0 = 208;
    localparam TEXT_Y1 = 272;
 
    // Contadores de píxel
    reg [9:0]  px, py;
    reg [18:0] paddr;
 
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
 
    // Detección del área de texto y coordenadas relativas
    wire in_text = (px >= TEXT_X0) && (px < TEXT_X1) &&
                   (py >= TEXT_Y0) && (py < TEXT_Y1);
 
    wire [9:0] rel_x = px - 10'd192;
    wire [9:0] rel_y = py - 10'd208;
 
    wire [2:0] char_pos        = rel_x[7:5];
    wire [2:0] pixel_in_char_x = rel_x[4:2];
    wire [3:0] pixel_in_char_y = rel_y[5:2];
 
    // Selección del código de carácter según posición
    reg [3:0] char_code;
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
 
    // Instancia de background_gen
    wire bg_pixel;
    background_gen u_bg (
        .px       (px),
        .py       (py),
        .pixel_val(bg_pixel)
    );
 
    // Instancia de font_rom
    wire [7:0] font_row;
    font_rom u_font (
        .clk     (clk),
        .addr    ({char_code, pixel_in_char_y}),
        .data_out(font_row)
    );
 
    // Registros de pipeline etapa 0 a etapa 1
    reg [18:0] addr_s1;
    reg        in_text_s1;
    reg [2:0]  col_s1;
    reg        bg_s1;
 
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
 
    // Etapa 1: pixel final
    wire text_pixel  = font_row[3'd7 - col_s1];
    wire final_pixel = in_text_s1 ? text_pixel : bg_s1;
 
    assign we_a   = 1'b1;
    assign addr_a = addr_s1;
    assign data_a = final_pixel;
 
endmodule
