# VGA Clock — Reloj Digital en FPGA

**Autores:** Andrea García Borges / Jesús Huertas  
**Curso:** EL3313 — Taller de Diseño Digital, I Semestre 2026  
**Profesor:** Dr. Luis G. León-Vega  
**Tarjeta objetivo:** Nexys A7 (xc7a100tcsg324-1)

---

## Descripción general

Sistema digital implementado en FPGA que muestra un reloj en formato **HH:MM:SS** simultáneamente en:

- Una pantalla VGA a resolución 640×480 @ 60 Hz, con texto centrado, fondo decorativo y separadores.
- Los ocho displays de 7 segmentos de la Nexys A7, multiplexados en tiempo.

La hora puede ajustarse manualmente mediante un switch de modo y dos botones físicos, con debouncing y detección de flanco integrados.

---



## Arquitectura del sistema

El sistema se organiza en cuatro subsistemas principales que operan en dos dominios de reloj:

| Dominio | Frecuencia | Módulos |
|---------|-----------|---------|
| Sistema | 100 MHz   | `clock_counter`, `image_generator`, `seg7_driver` |
| VGA     | 25 MHz    | `vga_controller`, `h_sync_gen`, `v_sync_gen`, `pixel_mux` |

El reloj de 25 MHz se genera desde el oscilador de 100 MHz usando el **Clocking Wizard IP** de Vivado (`clk_wiz_0`).

### Subsistemas

**Control de hora (`clock_counter`)
Mantiene la hora en formato 12 h. En modo normal avanza a 1 Hz mediante un divisor de frecuencia interno. En modo ajuste (`sw_adjust = 1`) el contador se congela y los botones `BTNL`/`BTNR` incrementan hora y minuto respectivamente. Cada botón físico pasa por la cadena: `button_sync → debounce → edge_detector`.

**Generación de imagen (`image_generator` + `background_gen` + `font_rom`)**  
Recorre los 307 200 píxeles de la pantalla a 100 MHz, escribiendo en la VRAM el valor de cada píxel. Combina el fondo decorativo generado combinacionalmente por `background_gen` con el texto del reloj renderizado a partir de los bitmaps 8×16 de `font_rom`, escalados 4× para producir caracteres de 32×64 px centrados en pantalla. Usa un pipeline de dos etapas para compensar la latencia de un ciclo de la BRAM.

**Memoria de video (`vram`)**  
BRAM de doble puerto, 307 200 bits (1 bit por píxel). Puerto A: escritura desde `image_generator` a 100 MHz. Puerto B: lectura desde `vga_controller` a 25 MHz. Los dominios de reloj son completamente independientes.

**Controlador VGA (`vga_controller` + `h_sync_gen` + `v_sync_gen` + `pixel_mux`)**  
Genera las señales VGA estándar 640×480 @ 60 Hz. Calcula la dirección de lectura de la VRAM con **dos ciclos de adelanto** para compensar la latencia de un ciclo de la BRAM y el ciclo de registro de salida de `pixel_mux`. La señal `video_on` se registra un ciclo para sincronizarla con la salida RGB.

**Displays de 7 segmentos (`seg7_driver`)**  
Multiplexa los ocho ánodos de la Nexys A7 mostrando HH:MM:SS en los displays AN7–AN2. Los puntos decimales de AN6 y AN4 actúan como separadores de campo. Los displays AN1 y AN0 permanecen apagados.

---

## Entradas y salidas

| Puerto | Pin Nexys A7 | Descripción |
|--------|-------------|-------------|
| `clk` | W5 | Reloj del sistema 100 MHz |
| `rst` | T18 (BTNC) | Reset síncrono activo alto |
| `sw_adjust` | V17 (SW0) | Modo ajuste: 1 = ajuste activo |
| `btn_inc_hour` | W19 (BTNL) | Incrementa la hora |
| `btn_inc_min` | T17 (BTNR) | Incrementa el minuto |
| `seg[6:0]` | — | Segmentos del display, activo bajo |
| `an[7:0]` | — | Ánodos del display, activo bajo |
| `dp` | — | Punto decimal, activo bajo |
| `vga_r[3:0]` | — | Canal rojo VGA, conector J2 |
| `vga_g[3:0]` | — | Canal verde VGA, conector J2 |
| `vga_b[3:0]` | — | Canal azul VGA, conector J2 |
| `hsync` | — | Sincronización horizontal VGA |
| `vsync` | — | Sincronización vertical VGA |

---

## Parámetros VGA (640×480 @ 60 Hz)

| Campo | Horizontal | Vertical |
|-------|-----------|---------|
| Zona visible | 640 ciclos | 480 líneas |
| Front porch | 16 ciclos | 10 líneas |
| Pulso sync | 96 ciclos | 2 líneas |
| Back porch | 48 ciclos | 33 líneas |
| **Total** | **800 ciclos** | **525 líneas** |

---

## Compilación y simulación

### iVerilog (simulación funcional)

```bash
# Compilar el testbench de diagnóstico VGA
iverilog -g2012 -o tb_vga.vvp \
    tb/tb_vga_controller.sv \
    src/vga_controller.v \
    src/h_sync_gen.v \
    src/v_sync_gen.v \
    src/pixel_mux.v \
    src/vram.v

# Ejecutar simulación
vvp tb_vga.vvp

# Ver formas de onda
gtkwave tb_vga_debug.vcd
```

### Vivado (síntesis)

1. Crear proyecto apuntando a `xc7a100tcsg324-1`.
2. Agregar todos los archivos en `src/` como fuentes de diseño.
3. Agregar `constraints/nexys_a7.xdc`.
4. Generar el IP `clk_wiz_0` con Clocking Wizard: entrada 100 MHz, salida 25 MHz.
5. Ejecutar síntesis, implementación y generar bitstream.
6. Programar la FPGA con el archivo `.bit` generado.

> Para simulación en Vivado usar `top_sim.v` en lugar de `top.v`. El stub reemplaza el IP de reloj por un divisor directo compatible con iVerilog.

---

## Decisiones de diseño relevantes

- **1 bit por píxel (blanco/negro):** minimiza el uso de BRAM (307 200 bits ≈ 8.5 BRAM18) frente a la alternativa de color de 12 bits por píxel que requeriría 60× más memoria.
- **Pipeline de dos ciclos en la dirección VRAM:** compensa la latencia de lectura de la BRAM (1 ciclo) más el registro de salida del `pixel_mux` (1 ciclo), evitando artefactos visuales.
- **Clocking Wizard en lugar de divisor manual:** garantiza que el reloj de 25 MHz sea tratado como reloj global por las herramientas de síntesis, evitando problemas de timing.
- **`h_end` como pulso de 1 bit:** el generador vertical recibe únicamente este pulso de `h_sync_gen`, manteniendo los módulos desacoplados.
- **Cadena sync → debounce → edge para botones:** sigue las buenas prácticas de I/O descritas en el curso para señales asíncronas externas.

---

## Consumo de recursos

Datos obtenidos del reporte de utilización de Vivado tras síntesis e implementación sobre la Nexys A7 (`xc7a100tcsg324-1`).

### Resumen por módulo

| Módulo | Slice LUTs (63400) | Slice Regs (126800) | Slices (15850) | Block RAM Tile (135) | DSPs (240) | IOBs (210) |
|--------|-------------------|---------------------|----------------|----------------------|------------|------------|
| **top** (total) | 217 | 221 | 115 | 10.5 | 1 | 35 |
| `u_clk` (`clock_counter`) | 101 | 100 | 51 | 0 | 0 | 0 |
| `u_img_gen` (`image_generator`) | 46 | 63 | 29 | 0.5 | 0 | 0 |
| `u_seg7` (`seg7_driver`) | 7 | 17 | 9 | 0 | 0 | 0 |
| `u_vga` (`vga_controller`) | 55 | 33 | 28 | 0 | 1 | 0 |
| `u_vram` (`vram`) | 13 | 8 | 9 | 10 | 0 | 0 |
| `u_clk_wiz` (`clk_wiz_0`) | 0 | 0 | 0 | 0 | 0 | 2 |

### Porcentaje de utilización global

| Recurso | Usado | Disponible | Utilización |
|---------|-------|-----------|-------------|
| Slice LUTs | 217 | 63 400 | **0.34 %** |
| Slice Registers | 221 | 126 800 | **0.17 %** |
| Slices | 115 | 15 850 | **0.73 %** |
| Block RAM Tile | 10.5 | 135 | **7.78 %** |
| DSPs | 1 | 240 | **0.42 %** |
| Bonded IOBs | 35 | 210 | **16.67 %** |
| BUFGCTRL | 3 | 32 | **9.38 %** |
| MMCME2_ADV | 1 | 6 | **16.67 %** |

### Notas

- El recurso más utilizado en proporción es la **Block RAM** (7.78 %), dominada por `u_vram` (10 BRAM18) que almacena el framebuffer de 307 200 bits.
- El único **DSP48** consumido pertenece a `u_vga` (`vga_controller`), usado en el cálculo de la dirección de lectura de la VRAM.
- El uso de **LUTs y registros es muy bajo** (< 1 %), lo que deja amplio margen para futuras expansiones (color, múltiples zonas de texto, animaciones).
- El **MMCME2_ADV** corresponde al PLL instanciado por `clk_wiz_0` para generar el dominio de 25 MHz.
- No se dispone del reporte de timing de Vivado para este proyecto; el **retraso crítico y la frecuencia máxima** deben extraerse del archivo `timing_summary_routed.rpt` generado tras la implementación (`Open Implemented Design → Reports → Timing Summary`).

---

## Control de versiones

El repositorio sigue la convención **GitFlow** con ramas `main`, `develop` y ramas `feature/*` por módulo. Los mensajes de commit siguen el estándar **Conventional Commits**:

```
feat(vga): agrega generador de sincronización vertical
fix(pixel_mux): corrige latencia en video_on
docs(readme): agrega diagrama de bloques del sistema
```

---

## Autores y responsabilidades

| Módulo | Responsable |
|--------|------------|
| `h_sync_gen`, `v_sync_gen`, `vram`, `pixel_mux`, `vga_controller` | Jesús Huertas |
| `clock_counter`, `button_sync`, `debounce`, `edge_detector`, `image_generator`, `background_gen`, `font_rom`, `seg7_driver` | Andrea García Borges |
| `top`, `top_sim`, integración general | Andrea García Borges / Jesús Huertas |




## Enlace al repositorio 


https://github.com/andreagarciab0118-design/pro_1_taller_digitales.git


Se permitió el uso de herramientas de IA como apoyo para comprensión, generación de ideas y mejora de redacción. La implementación, validación y resultados son responsabilidad del estudiante.

En caso de uso, se adjuntan las conversaciones como evidencia. El funcionamiento del sistema puede demostrarse mediante pruebas, garantizando la comprensión de los conceptos y la correcta operación de la solución.


https://claude.ai/share/9736caba-678b-459d-ae7d-2d6facc734a1

https://claude.ai/chat/7aa21b04-1db5-4c56-a199-40e87b9d69c3
