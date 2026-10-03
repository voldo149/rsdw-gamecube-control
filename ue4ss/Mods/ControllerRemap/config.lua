-- ControllerRemap — configuración
-- Después de editar, guarda y presiona F7 dentro del juego (no hace falta reiniciar).
--
-- Botones (POSICIÓN FÍSICA, no la letra impresa):
--   Gamepad_FaceButton_Bottom   abajo     (A en Xbox, B en Switch)
--   Gamepad_FaceButton_Right    derecha   (B en Xbox, A en Switch)
--   Gamepad_FaceButton_Left     izquierda (X en Xbox, Y en Switch)
--   Gamepad_FaceButton_Top      arriba    (Y en Xbox, X en Switch)
--   Gamepad_LeftShoulder / Gamepad_RightShoulder             LB / RB  (L / R)
--   Gamepad_LeftTrigger  / Gamepad_RightTrigger              LT / RT  (ZL / ZR)
--   Gamepad_LeftTriggerAxis / Gamepad_RightTriggerAxis       (algunas acciones usan el eje del gatillo)
--   Gamepad_LeftThumbstick / Gamepad_RightThumbstick         L3 / R3
--   Gamepad_Special_Left / Gamepad_Special_Right             View/Menu  (− / +)
--   Gamepad_DPad_Up / _Down / _Left / _Right
--   None                                                     = quitarle el botón
--
-- Controles por defecto del gameplay (de mappings_dump.txt):
--   IA_Player_Jump            Bottom          (IMC_Movement, IMC_MountedMovement)
--   IA_Player_Evade           Right           (IMC_Combat, IMC_SpellcastingModeAdvancedMovement)
--   IA_Player_Stealth         Right           (IMC_Movement)
--   IA_Interact / IA_InteractHold / IA_SecondaryInteract   Left
--   IA_Mount / IA_SpellMenu   Top
--   IA_PrimaryAction          RightShoulder   (RB)
--   IA_SecondaryAction        LeftTrigger     (LT)
--   IA_SpecialAction          RightTrigger    (RT)
--   IA_QuickAccessRadial      LeftShoulder    (LB)
--   IA_Player_Sprint          LeftThumbstick  (L3)
--   IA_ToggleLockOnTargeting  RightThumbstick (R3)
--   IA_InventoryMenu          DPad_Up    |  IA_BuildMenu  DPad_Down
--   IA_AmmoSwapLeft/Right     DPad_Left / DPad_Right
--   IA_TopBarMenu             Special_Left    |  IA_Pause  Special_Right
--   Menús: IA_UI_GenericAccept (Bottom), IA_UI_GenericBack (Right) — mejor no tocarlos.
--
-- Cada regla: si esa acción tiene ORIGINALMENTE el botón `from`, pasa a `to`.
-- Las reglas siempre se evalúan sobre el botón original, así que un intercambio
-- se hace con dos reglas y no se pisan.
--   action  = nombre exacto (columna ACCION) o "*" para todas
--   context = (opcional) parte del nombre del contexto, p. ej. "Movement"

return {
  -- Esquema de zigis (control GameCube): A=Bottom, B=Right, X=Left, Y=Top, Z=RightShoulder, +=Special_Right
  rules = {
    -- Cama: levantarse -> B (si falla, cambia "to" a "Gamepad_DPad_Left", que sí funcionó)
    -- detach = no seguir el botón compartido de "interactuar"
    { action = "IA_Interact", context = "Resting", from = "Gamepad_FaceButton_Left", to = "Gamepad_FaceButton_Right", detach = true },

    -- Interactuar -> A
    { action = "IA_Interact",          from = "Gamepad_FaceButton_Left",   to = "Gamepad_FaceButton_Bottom" },
    { action = "IA_InteractHold",      from = "Gamepad_FaceButton_Left",   to = "Gamepad_FaceButton_Bottom" },
    { action = "IA_SecondaryInteract", from = "Gamepad_FaceButton_Left",   to = "Gamepad_FaceButton_Bottom" },

    -- Subirse/bajarse de vehículos: igual que interactuar (A)
    { action = "IA_ExitOccupied",      from = "Gamepad_FaceButton_Left",   to = "Gamepad_FaceButton_Bottom" },

    -- Construcción: colocar (QuickInteract) -> A
    { action = "IA_Building_QuickInteract", from = "Gamepad_FaceButton_Left", to = "Gamepad_FaceButton_Bottom" },

    -- Y: radial rápido INSTANTÁNEO (abre al presionar, se apunta con el stick derecho, se cierra al soltar)
    { action = "IA_QuickAccessRadial",      from = "Gamepad_LeftShoulder", to = "Gamepad_FaceButton_Top" },
    { action = "IA_QuickAccessRadialClose", from = "Gamepad_LeftShoulder", to = "Gamepad_FaceButton_Top" },

    -- B: esquivar (tap) / sigilo (hold) — los dos ya están en B de fábrica, no necesitan regla
    { action = "IA_Player_Sprint",     from = "Gamepad_LeftThumbstick",    to = "Gamepad_FaceButton_Right" },

    -- X: brincar
    { action = "IA_Player_Jump",       from = "Gamepad_FaceButton_Bottom", to = "Gamepad_FaceButton_Left" },

    -- Z: atacar (tap) / menú de hechizos (hold)
    { action = "IA_SpellMenu",         from = "Gamepad_FaceButton_Top",    to = "Gamepad_RightShoulder" },
    { action = "IA_SpellMenuDummy",    from = "Gamepad_FaceButton_Top",    to = "Gamepad_RightShoulder" },
    -- Aviso de "ataque especial" que el juego tenía en RB y se quedaba con la Z: a L3 (el GC no lo tiene)
    { action = "IA_SpecialActionDummy", from = "Gamepad_RightShoulder",    to = "Gamepad_LeftThumbstick" },

    -- D-pad: izquierda/derecha = munición (originales). Derecha mantener = montar
    { action = "IA_Mount",             from = "Gamepad_FaceButton_Top",    to = "Gamepad_DPad_Right" },
    { action = "IA_MountDummy",        from = "Gamepad_FaceButton_Top",    to = "Gamepad_DPad_Right" },

    -- Inventario: destruir objeto -> mantener X (tap X sigue siendo usar)
    { action = "IA_Inventory_DestroyObject_Held", from = "Gamepad_LeftTriggerAxis", to = "Gamepad_FaceButton_Left" },

    -- Inventario: pestañas con el C-stick izquierda/derecha, ordenar con Z (RB, quedó libre en el inventario)
    { action = "IA_UI_InventoryTabLeft",  from = "Gamepad_LeftShoulder",   to = "Gamepad_RightStick_Left" },
    { action = "IA_UI_InventoryTabRight", from = "Gamepad_RightShoulder",  to = "Gamepad_RightStick_Right" },
    { action = "IA_PlayerInventory_Sort", from = "Gamepad_LeftThumbstick", to = "Gamepad_RightShoulder" },

    -- Menú de construcción: pestaña izquierda (LB) también en Z (ver combo: tap = derecha, hold = izquierda)
    { action = "IA_UI_GenericTabLeft", context = "BuildingUI", from = "Gamepad_LeftShoulder", to = "Gamepad_RightShoulder" },

    -- Cofres/inventario: cambiar de panel -> L
    { action = "IA_Inventory_SwitchPanel",  from = "Gamepad_RightThumbstick", to = "Gamepad_LeftTrigger" },

    -- +: menú (mapa/diario/habilidades) (tap) / opciones-pausa (hold; la pausa ya está en +)
    { action = "IA_TopBarMenu",       from = "Gamepad_Special_Left", to = "Gamepad_Special_Right" },
    { action = "IA_TopBarMenuDummy",  from = "Gamepad_Special_Left", to = "Gamepad_Special_Right" },
    -- Atajos directos a diario/habilidades (solo montado): mandados a L3 (el GC no lo tiene), el menú ya los cubre
    { action = "IA_SkillsMenu",       from = "Gamepad_Special_Left", to = "Gamepad_LeftThumbstick" },
    { action = "IA_SkillsMenuDummy",  from = "Gamepad_Special_Left", to = "Gamepad_LeftThumbstick" },
    { action = "IA_OpenJournal",      from = "Gamepad_Special_Left", to = "Gamepad_LeftThumbstick" },
    { action = "IA_OpenJournalDummy", from = "Gamepad_Special_Left", to = "Gamepad_LeftThumbstick" },
    -- Chat en el control: a L3. Sigue en Enter del teclado
    { action = "IA_UI_OpenChat",      from = "Gamepad_Special_Left", to = "Gamepad_LeftThumbstick" },

    -- Inventario: se queda en D-pad arriba (su botón original)
  },

  -- Tap / Hold en el mismo botón (estilo Dark Souls).
  -- tap  = se activa al SOLTAR antes de tap_time segundos
  -- hold = se activa al MANTENER más de hold_time segundos
  -- context = (opcional) solo aplica en contextos cuyo nombre contenga ese texto
  -- inject = true -> EXPERIMENTAL, NO USAR: revisa el control constantemente; causó lag y crashes.
  -- press = acción que se activa al instante al presionar (sin tap/hold)
  -- one_shot = true -> el hold se activa UNA vez (menús, montar); false -> sigue activo (correr)
  combos = {
    -- Y: radial al instante
    { key = "Gamepad_FaceButton_Top",   press = "IA_QuickAccessRadial" },
    -- B: esquivar / sigilo
    { key = "Gamepad_FaceButton_Right", tap = "IA_Player_Evade",  hold = "IA_Player_Sprint", tap_time = 0.25, hold_time = 0.25, one_shot = true },
    -- Z: atacar / hechizos (atacar sí espera al tap, así que mantener NO ataca)
    { key = "Gamepad_RightShoulder",    tap = "IA_PrimaryAction", hold = "IA_SpellMenu",      tap_time = 0.25, hold_time = 0.30, one_shot = true },
    -- D-pad izquierda: munición / sigilo
    { key = "Gamepad_DPad_Left",       tap = "IA_AmmoSwapLeft", hold = "IA_Player_Stealth",          tap_time = 0.40, hold_time = 0.40, one_shot = true },
    -- D-pad derecha: munición / montar
    { key = "Gamepad_DPad_Right",       tap = "IA_AmmoSwapRight", hold = "IA_Mount",          tap_time = 0.40, hold_time = 0.40, one_shot = true },
    -- Menú de construcción: Z tap = pestaña derecha, Z hold = pestaña izquierda (solo en ese menú)
    { key = "Gamepad_RightShoulder", context = "BuildingUI", tap = "IA_UI_GenericTabRight", hold = "IA_UI_GenericTabLeft", tap_time = 0.30, hold_time = 0.30, one_shot = true },
    -- +: menú / pausa
    { key = "Gamepad_Special_Right",    tap = "IA_TopBarMenu",    hold = "IA_Pause",          tap_time = 0.40, hold_time = 0.40, one_shot = true },
  },

  -- Acciones que NO se "comen" su botón: lo dejan pasar a otros controles activos.
  -- Esquivar/sigilo están en B; así la B también llega a "levantarse de la cama".
  no_consume = { "IA_Player_Evade", "IA_Player_Stealth" },

  -- Contextos que NUNCA se tocan (coincidencia por texto, sin mayúsculas).
  exclude_contexts = { "FrontEnd", "Debug" },

  dump_all = false,  -- true = también lista teclado/mouse en mappings_dump.txt
  verbose  = false,  -- true = escribe cada cambio en ue4ss\UE4SS.log
}
