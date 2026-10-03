# rsdw-gamecube-control

**ControllerRemap** — RuneScape: Dragonwilds

Mod de UE4SS (Lua) para remapear el control por acción (`IA_*`) dentro de los
Input Mapping Contexts del juego. Esquema actual: control de GameCube.

## Estructura

- `ue4ss/` — UE4SS v3.0.1-946 (build para Dragonwilds) + mods de ejemplo.
- `ue4ss/Mods/ControllerRemap/` — **nuestro mod**
  - `Scripts/main.lua` — lógica (v0.11)
  - `config.lua` — reglas de remapeo, combos tap/hold, `no_consume`, exclusiones
  - `mappings_dump.txt` / `perfil_dump.txt` — volcados generados por el mod (F7)
  - `botones_test.txt` — salida de la prueba de botones (F9)

## Instalación

Copiar `ue4ss/` a `RSDragonwilds\Binaries\Win64\` (junto a
`RSDragonwilds-Win64-Shipping.exe`). También hace falta `dwmapi.dll` del paquete
de UE4SS en esa misma carpeta (no está en este repo).

## Teclas en el juego

- **F7** — recargar `config.lua`, aplicar y regenerar los dumps
- **F8** — activar / desactivar los remapeos
- **F9** — prueba de botones (60 s), escribe en `botones_test.txt`
