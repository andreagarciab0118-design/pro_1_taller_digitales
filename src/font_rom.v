//! @title font_rom
//! @author Andrea García Borges
//! @date 23/04/2026
//!
//! Memoria ROM basada en BRAM que almacena los bitmaps de 8x16
//! píxeles para los caracteres del reloj: dígitos del 0 al 9 y
//! el separador dos puntos (:). Cada fila del carácter se codifica
//! como un byte donde el bit 7 representa el píxel más a la
//! izquierda. La dirección se forma concatenando el código de
//! carácter en los bits altos [7:4] y el número de fila en los
//! bits bajos [3:0]. La salida tiene una latencia de un ciclo de reloj.

module font_rom (
    input  wire       clk,      //! Reloj del sistema
    input  wire [7:0] addr,     //! Dirección: {char_code[3:0], fila[3:0]}
    output reg  [7:0] data_out  //! Fila de 8 píxeles del carácter, latencia 1 ciclo
);

    (* ram_style = "block" *) reg [7:0] mem [0:255]; //! Memoria ROM de 256 bytes en BRAM

    integer fi;
    initial begin
        for (fi = 0; fi < 256; fi = fi + 1) mem[fi] = 8'h00;

        // Digit 0
        mem[0]  = 8'h3C; mem[1]  = 8'h66; mem[2]  = 8'hC3; mem[3]  = 8'hC3;
        mem[4]  = 8'hC3; mem[5]  = 8'hC3; mem[6]  = 8'hC3; mem[7]  = 8'hC3;
        mem[8]  = 8'hC3; mem[9]  = 8'hC3; mem[10] = 8'hC3; mem[11] = 8'hC3;
        mem[12] = 8'h66; mem[13] = 8'h3C; mem[14] = 8'h00; mem[15] = 8'h00;

        // Digit 1
        mem[16] = 8'h18; mem[17] = 8'h38; mem[18] = 8'h78; mem[19] = 8'h18;
        mem[20] = 8'h18; mem[21] = 8'h18; mem[22] = 8'h18; mem[23] = 8'h18;
        mem[24] = 8'h18; mem[25] = 8'h18; mem[26] = 8'h18; mem[27] = 8'h18;
        mem[28] = 8'h18; mem[29] = 8'h7E; mem[30] = 8'h00; mem[31] = 8'h00;

        // Digit 2
        mem[32] = 8'h3C; mem[33] = 8'h66; mem[34] = 8'hC3; mem[35] = 8'h03;
        mem[36] = 8'h06; mem[37] = 8'h0C; mem[38] = 8'h18; mem[39] = 8'h30;
        mem[40] = 8'h60; mem[41] = 8'hC0; mem[42] = 8'hC0; mem[43] = 8'hC0;
        mem[44] = 8'hFF; mem[45] = 8'hFF; mem[46] = 8'h00; mem[47] = 8'h00;

        // Digit 3
        mem[48] = 8'h3C; mem[49] = 8'h66; mem[50] = 8'hC3; mem[51] = 8'h03;
        mem[52] = 8'h03; mem[53] = 8'h1E; mem[54] = 8'h1E; mem[55] = 8'h03;
        mem[56] = 8'h03; mem[57] = 8'h03; mem[58] = 8'hC3; mem[59] = 8'hC3;
        mem[60] = 8'h66; mem[61] = 8'h3C; mem[62] = 8'h00; mem[63] = 8'h00;

        // Digit 4
        mem[64] = 8'h06; mem[65] = 8'h0E; mem[66] = 8'h1E; mem[67] = 8'h36;
        mem[68] = 8'h66; mem[69] = 8'hC6; mem[70] = 8'hC6; mem[71] = 8'hFF;
        mem[72] = 8'hFF; mem[73] = 8'h06; mem[74] = 8'h06; mem[75] = 8'h06;
        mem[76] = 8'h06; mem[77] = 8'h06; mem[78] = 8'h00; mem[79] = 8'h00;

        // Digit 5
        mem[80] = 8'hFF; mem[81] = 8'hC0; mem[82] = 8'hC0; mem[83] = 8'hC0;
        mem[84] = 8'hFC; mem[85] = 8'hFE; mem[86] = 8'h03; mem[87] = 8'h03;
        mem[88] = 8'h03; mem[89] = 8'h03; mem[90] = 8'h03; mem[91] = 8'h03;
        mem[92] = 8'hFE; mem[93] = 8'hFC; mem[94] = 8'h00; mem[95] = 8'h00;

        // Digit 6
        mem[96]  = 8'h3C; mem[97]  = 8'h66; mem[98]  = 8'hC0; mem[99]  = 8'hC0;
        mem[100] = 8'hC0; mem[101] = 8'hFC; mem[102] = 8'hFE; mem[103] = 8'hC3;
        mem[104] = 8'hC3; mem[105] = 8'hC3; mem[106] = 8'hC3; mem[107] = 8'hC3;
        mem[108] = 8'h66; mem[109] = 8'h3C; mem[110] = 8'h00; mem[111] = 8'h00;

        // Digit 7
        mem[112] = 8'hFF; mem[113] = 8'hFF; mem[114] = 8'h03; mem[115] = 8'h03;
        mem[116] = 8'h06; mem[117] = 8'h0C; mem[118] = 8'h18; mem[119] = 8'h18;
        mem[120] = 8'h30; mem[121] = 8'h30; mem[122] = 8'h60; mem[123] = 8'h60;
        mem[124] = 8'h60; mem[125] = 8'h60; mem[126] = 8'h00; mem[127] = 8'h00;

        // Digit 8
        mem[128] = 8'h3C; mem[129] = 8'h66; mem[130] = 8'hC3; mem[131] = 8'hC3;
        mem[132] = 8'hC3; mem[133] = 8'h66; mem[134] = 8'h3C; mem[135] = 8'h66;
        mem[136] = 8'hC3; mem[137] = 8'hC3; mem[138] = 8'hC3; mem[139] = 8'hC3;
        mem[140] = 8'h66; mem[141] = 8'h3C; mem[142] = 8'h00; mem[143] = 8'h00;

        // Digit 9
        mem[144] = 8'h3C; mem[145] = 8'h66; mem[146] = 8'hC3; mem[147] = 8'hC3;
        mem[148] = 8'hC3; mem[149] = 8'hC3; mem[150] = 8'h67; mem[151] = 8'h3F;
        mem[152] = 8'h03; mem[153] = 8'h03; mem[154] = 8'h03; mem[155] = 8'h03;
        mem[156] = 8'h66; mem[157] = 8'h3C; mem[158] = 8'h00; mem[159] = 8'h00;

        // Char 10: colon (:)
        mem[160] = 8'h00; mem[161] = 8'h00; mem[162] = 8'h00; mem[163] = 8'h18;
        mem[164] = 8'h3C; mem[165] = 8'h18; mem[166] = 8'h00; mem[167] = 8'h00;
        mem[168] = 8'h00; mem[169] = 8'h18; mem[170] = 8'h3C; mem[171] = 8'h18;
        mem[172] = 8'h00; mem[173] = 8'h00; mem[174] = 8'h00; mem[175] = 8'h00;
    end

    always @(posedge clk) begin
        data_out <= mem[addr];
    end

endmodule