/*
 * Autor:   Andrea García Borges
 * Fecha:   23/04/2026
 *
 * Módulo:  seg7_driver
 *
 * Descripción: Controlador multiplexado para los ocho displays de 7 segmentos
 *              de la Nexys A7. Recibe hora, minuto y segundo, los convierte a
 *              BCD y los muestra en formato HH:MM:SS usando los displays AN7 a
 *              AN2. Los puntos decimales de AN6 y AN4 actúan como separadores.
 *              Los displays AN1 y AN0 permanecen apagados.
 */
module seg7_driver (
    input  wire       clk,
    input  wire       rst,
    input  wire [3:0] hour,
    input  wire [5:0] minute,
    input  wire [5:0] second,
    output reg  [6:0] seg,
    output reg  [7:0] an,
    output reg        dp
);
    wire [3:0] h_tens  = (hour >= 4'd10) ? 4'd1 : 4'd0;
    wire [3:0] h_units = (hour >= 4'd10) ? hour - 4'd10 : hour;
    wire [3:0] m_tens  = minute / 10;
    wire [3:0] m_units = minute % 10;
    wire [3:0] s_tens  = second / 10;
    wire [3:0] s_units = second % 10;
 
    function [6:0] bcd_to_seg7;
        input [3:0] bcd;
        case (bcd)
            4'd0: bcd_to_seg7 = 7'b1000000;
            4'd1: bcd_to_seg7 = 7'b1111001;
            4'd2: bcd_to_seg7 = 7'b0100100;
            4'd3: bcd_to_seg7 = 7'b0110000;
            4'd4: bcd_to_seg7 = 7'b0011001;
            4'd5: bcd_to_seg7 = 7'b0010010;
            4'd6: bcd_to_seg7 = 7'b0000010;
            4'd7: bcd_to_seg7 = 7'b1111000;
            4'd8: bcd_to_seg7 = 7'b0000000;
            4'd9: bcd_to_seg7 = 7'b0010000;
            default: bcd_to_seg7 = 7'b1111111;
        endcase
    endfunction
 
    reg [16:0] refresh;
 
    always @(posedge clk) begin
        if (rst) refresh <= 17'd0;
        else     refresh <= refresh + 17'd1;
    end
 
    wire [2:0] sel = refresh[16:14];
 
    always @(*) begin
        case (sel)
            3'd7: begin an = 8'b01111111; seg = bcd_to_seg7(h_tens);  dp = 1'b1; end
            3'd6: begin an = 8'b10111111; seg = bcd_to_seg7(h_units); dp = 1'b0; end
            3'd5: begin an = 8'b11011111; seg = bcd_to_seg7(m_tens);  dp = 1'b1; end
            3'd4: begin an = 8'b11101111; seg = bcd_to_seg7(m_units); dp = 1'b0; end
            3'd3: begin an = 8'b11110111; seg = bcd_to_seg7(s_tens);  dp = 1'b1; end
            3'd2: begin an = 8'b11111011; seg = bcd_to_seg7(s_units); dp = 1'b1; end
            default: begin an = 8'b11111111; seg = 7'b1111111;        dp = 1'b1; end
        endcase
    end
 
endmodule
