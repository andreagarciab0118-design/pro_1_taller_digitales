
//! @title vga_controller
//! @author Jesús Huertas
//! @date 23/04/2026
//!
//! Controlador VGA completo para resolución 640x480 @ 60Hz.
//! Integra internamente los generadores de sincronización
//! horizontal y vertical, el acceso a la VRAM y el multiplexor
//! de píxel para producir las señales VGA finales.
//!
//! El módulo calcula la dirección de lectura de la VRAM con dos
//! ciclos de adelanto para compensar la latencia de un ciclo de
//! la BRAM más el ciclo adicional del registro de salida de pixel_mux.
//!
//! La señal video_on se registra un ciclo para mantenerse sincronizada
//! con la salida RGB del pixel_mux y evitar artefactos visuales.

module vga_controller (
    input  wire        clk,           //! Reloj de 25 MHz dominio VGA
    input  wire        rst,           //! Reset síncrono activo alto
    input  wire        vram_data_in,  //! Dato leído del puerto B de la VRAM
    output wire [18:0] vram_addr,     //! Dirección de lectura hacia la VRAM, con 2 ciclos de adelanto
    output wire        hsync,         //! Sincronización horizontal al monitor, activo bajo
    output wire        vsync,         //! Sincronización vertical al monitor, activo bajo
    output wire [3:0]  vga_r,         //! Canal rojo al monitor, 4 bits
    output wire [3:0]  vga_g,         //! Canal verde al monitor, 4 bits
    output wire [3:0]  vga_b          //! Canal azul al monitor, 4 bits
);

    localparam H_VISIBLE = 640; //! Píxeles visibles por línea
    localparam H_TOTAL   = 800; //! Total de ciclos por línea
    localparam V_VISIBLE = 480; //! Líneas visibles por frame
    localparam V_TOTAL   = 525; //! Total de líneas por frame

    wire [9:0] hcount; //! Posición horizontal actual desde h_sync_gen
    wire [9:0] vcount; //! Posición vertical actual desde v_sync_gen
    wire       hblank; //! Blanking horizontal
    wire       vblank; //! Blanking vertical
    wire       h_end;  //! Pulso de fin de línea

    //! Instancia del generador de sincronización horizontal
    h_sync_gen u_h_sync (
        .clk    (clk),
        .rst    (rst),
        .hcount (hcount),
        .hsync  (hsync),
        .hblank (hblank),
        .h_end  (h_end)
    );

    //! Instancia del generador de sincronización vertical
    v_sync_gen u_v_sync (
        .clk    (clk),
        .rst    (rst),
        .h_end  (h_end),
        .vcount (vcount),
        .vsync  (vsync),
        .vblank (vblank)
    );

    wire video_on = ~hblank && ~vblank; //! Activo en la zona visible del frame

    reg video_on_r; //! video_on retrasado un ciclo para sincronizar con salida RGB

    always @(posedge clk) begin
        video_on_r <= video_on;
    end

    reg [9:0] next_hcount; //! Posición horizontal anticipada dos ciclos
    reg [9:0] next_vcount; //! Posición vertical anticipada dos ciclos

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

    //! Instancia del multiplexor de píxel
    pixel_mux u_pixel_mux (
        .clk       (clk),
        .pixel_bit (vram_data_in),
        .video_on  (video_on_r),
        .vga_r     (vga_r),
        .vga_g     (vga_g),
        .vga_b     (vga_b)
    );
endmodule

