/*
 * Autor:   Jesús Huertas
 * Fecha:   23/04/2026
 *
 * Módulo:  vga_controller
 *
 * Descripción: Controlador VGA completo para resolución 640x480 @ 60Hz.
 *              Integra internamente los generadores de sincronización
 *              horizontal y vertical, el acceso a la VRAM y el multiplexor
 *              de píxel para producir las señales VGA finales que alimentan
 *              el monitor conectado a la Nexys.
 *
 *              El módulo calcula en cada ciclo la dirección de lectura de
 *              la VRAM con dos ciclos de adelanto para compensar la latencia
 *              de un ciclo de la BRAM y el ciclo adicional del registro de
 *              salida del pixel_mux.
 *
 *              La señal video_on se registra un ciclo para mantenerse
 *              sincronizada con la salida RGB del pixel_mux, que también
 *              tiene latencia de un ciclo de registro. Sin este registro,
 *              el último píxel visible de cada línea aparecería en la zona
 *              de blanking causando artefactos visuales.
 *
 * Nota: Este módulo asume que clk es de 25MHz generado por el Clocking
 *       Wizard de Vivado en la Nexys A7 
 */

module vga_controller (
    input  wire        clk,          // 25 MHz dominio VGA
    input  wire        rst,          // reset síncrono activo alto
    input  wire        vram_data_in, // dato leído del puerto B de la VRAM
    output wire [18:0] vram_addr,    // dirección de lectura hacia la VRAM
    output wire        hsync,        // sincronización horizontal al monitor
    output wire        vsync,        // sincronización vertical al monitor
    output wire [3:0]  vga_r,        // canal rojo al monitor
    output wire [3:0]  vga_g,        // canal verde al monitor
    output wire [3:0]  vga_b         // canal azul al monitor
);

    localparam H_VISIBLE = 640;
    localparam H_TOTAL   = 800;
    localparam V_VISIBLE = 480;
    localparam V_TOTAL   = 525;

    wire [9:0] hcount;
    wire [9:0] vcount;
    wire       hblank;
    wire       vblank;
    wire       h_end;
    wire       video_on;

    h_sync_gen u_h_sync (
        .clk    (clk),
        .rst    (rst),
        .hcount (hcount),
        .hsync  (hsync),
        .hblank (hblank),
        .h_end  (h_end)
    );

    v_sync_gen u_v_sync (
        .clk    (clk),
        .rst    (rst),
        .h_end  (h_end),
        .vcount (vcount),
        .vsync  (vsync),
        .vblank (vblank)
    );

    assign video_on = ~hblank && ~vblank;

    reg video_on_r;

    always @(posedge clk) begin
        video_on_r <= video_on;
    end

    reg [9:0] next_hcount;
    reg [9:0] next_vcount;

    always @(*) begin
        if (hcount >= H_TOTAL - 2) begin
            next_hcount = hcount - (H_TOTAL - 2);
            if (vcount == V_TOTAL - 1)
                next_vcount = 10'd0;
            else
                next_vcount = vcount + 10'd1;
        end else begin
            next_hcount = hcount + 10'd2;
            next_vcount = vcount;
        end
    end

    assign vram_addr = (next_hcount < H_VISIBLE && next_vcount < V_VISIBLE) ?
                       next_vcount * H_VISIBLE + next_hcount :
                       19'd0;

    pixel_mux u_pixel_mux (
        .clk       (clk),
        .pixel_bit (vram_data_in),
        .video_on  (video_on_r),
        .vga_r     (vga_r),
        .vga_g     (vga_g),
        .vga_b     (vga_b)
    );

endmodule