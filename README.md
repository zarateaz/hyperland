# 🌌 ＣＥＬＥＳＴＩＡＬ  ＆  ＨＹＰＲＬＡＮＤ  (ＡＲＣＨ  ＬＩＮＵＸ)

> Entorno unificado de escritorio de alto rendimiento para **Arch Linux**, **Garuda Linux**, **EndeavourOS** y derivados.
> Fusiona la experiencia estética y fluida de **Celestial / Caelestia Shell (Quickshell)** con el ecosistema completo de **Hyprland**, sincronización de SDDM y paletas dinámicas con **Wallust**.

---

![main](assets/hyprland.jpeg)
![extra](assets/extra.jpeg)
![extra2](assets/extra2.jpeg)

---

## ✨ Características Principales

- 🚀 **Instalación con un solo comando**: 0 margen de error, detección automática de hardware, resolución de conflictos y paquetes AUR.
- 🛸 **Celestial / Caelestia Shell**: Widgets de última generación construidos con **Quickshell** y QML moderno.
- 📊 **Fallback Seguro con Waybar & SwayNC**: Si Quickshell o Caelestia no están activos, la barra Waybar y el centro de notificaciones SwayNC entran en acción automáticamente.
- 🎨 **Armonía de Color Dinámica (Wallust)**: Los temas de terminal (Kitty), barras, menús (Rofi) y pantalla de bloqueo se sincronizan al cambiar de fondo de pantalla.
- 🌘 **Sincronización SDDM**: El fondo de pantalla y los colores seleccionados se sincronizan automáticamente con la pantalla de inicio de sesión SDDM.
- ⚡ **Terminal Zsh + Powerlevel10k**: Configurada con autocompletado inteligente, resaltado de sintaxis y utilidades para pentesting/desarrollo.

---

## 🛠️ Instalación en un Solo Comando (Arch Linux)

Ejecuta el siguiente comando en tu terminal como usuario normal (no root):

```bash
git clone https://github.com/zarateaz/hyperland.git && cd hyperland && chmod +x install.sh && ./install.sh
```

> **Nota:** El instalador detecta si tienes `yay` o `paru`, resuelve conflictos entre paquetes automáticamente, compila las herramientas necesarias, activa servicios de audio PipeWire y genera la configuración óptima para tu monitor y touchpad.

---

## ⌨️ Atajos de Teclado Principales

| Atajo | Función |
| :--- | :--- |
| <kbd>SUPER</kbd> + <kbd>D</kbd> | Abrir menú de aplicaciones (Rofi) |
| <kbd>SUPER</kbd> + <kbd>Return</kbd> | Abrir terminal (Kitty) |
| <kbd>SUPER</kbd> + <kbd>E</kbd> | Abrir explorador de archivos (Thunar) |
| <kbd>SUPER</kbd> + <kbd>Q</kbd> | Cerrar ventana activa |
| <kbd>SUPER</kbd> + <kbd>Espacio</kbd> | Alternar ventana flotante / mosaico |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>F</kbd> | Pantalla completa total |
| <kbd>SUPER</kbd> + <kbd>1-9</kbd> | Cambiar de escritorio (Workspaces 1 al 10) |
| <kbd>SUPER</kbd> + <kbd>W</kbd> | Selector de fondos de pantalla |
| <kbd>SUPER</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Captura de pantalla con editor visual (Swappy) |
| <kbd>SUPER</kbd> + <kbd>L</kbd> | Bloquear pantalla (Caelestia Lock / Hyprlock) |
| <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>P</kbd> | Menú de energía (Apagar / Reiniciar / Suspender) |
| <kbd>SUPER</kbd> + <kbd>H</kbd> | Ver chuleta de atajos en pantalla |

---

*Diseñado por [zarateaz](https://github.com/zarateaz)*
