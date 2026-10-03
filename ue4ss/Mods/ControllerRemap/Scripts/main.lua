-- ControllerRemap v0.11 — RuneScape: Dragonwilds (UE4SS Lua)
-- Remapea botones del control por ACCIÓN (IA_*) dentro de los Input Mapping
-- Contexts del juego. Como las reglas van por acción, los menús (IA_UI_*) no se tocan
-- a menos que tú lo pidas.
--
-- F7 = recargar config.lua, aplicar y regenerar mappings_dump.txt
-- F8 = activar / desactivar los remapeos (para comparar rápido)
--
-- v0.2: ya no hay ciclo cada 3 s (posible causa del crash al cerrar). Ahora solo se
-- aplica cuando el juego carga contextos nuevos, al reaparecer el jugador, o con F7/F8.

local TAG = "[ControllerRemap] "
local function log(s) print(TAG .. tostring(s) .. "\n") end

local src = debug.getinfo(1, "S").source:gsub("^@", "")
local scriptDir = src:match("^(.*)[/\\]") or "."
local modDir = scriptDir:match("^(.*)[/\\][Ss]cripts$") or scriptDir

local cfg = { rules = {}, exclude_contexts = {} }
local enabled = true
local originals = {}     -- "<ctx full name>#<idx>" -> tecla original
local pending = false    -- hay un pase programado
local dumpedOnce = false

local function loadConfig()
  local ok, res = pcall(dofile, modDir .. "\\config.lua")
  if ok and type(res) == "table" then
    cfg = res
    cfg.rules = cfg.rules or {}
    cfg.exclude_contexts = cfg.exclude_contexts or {}
    log("config.lua cargado: " .. #cfg.rules .. " regla(s)")
  else
    log("ERROR leyendo config.lua: " .. tostring(res))
  end
end

local function isExcluded(ctxName)
  for _, pat in ipairs(cfg.exclude_contexts) do
    if ctxName:lower():find(pat:lower(), 1, true) then return true end
  end
  return false
end

local function ruleFor(ctxName, actionName, origKey)
  for _, r in ipairs(cfg.rules) do
    local actionOk = (r.action == nil or r.action == "*" or r.action == actionName)
    local ctxOk = (r.context == nil or ctxName:lower():find(r.context:lower(), 1, true) ~= nil)
    if actionOk and ctxOk and r.from == origKey then return r.to, r end
  end
  return nil
end

local function getMappings(ctx)
  local candidates = {
    function() return ctx.DefaultKeyMappings.Mappings end,
    function() return ctx.Mappings end,
  }
  for _, get in ipairs(candidates) do
    local ok, arr = pcall(get)
    if ok and arr then
      local okN, n = pcall(function() return arr:GetArrayNum() end)
      if okN and n and n > 0 then return arr end
    end
  end
  return nil
end

local function firstValid(className)
  local all = FindAllOf(className)
  if not all then return nil end
  for _, o in ipairs(all) do
    if o:IsValid() and not o:GetFName():ToString():find("^Default__") then return o end
  end
end

local function rebuild()
  -- 1) Que la configuración del usuario se vuelva a aplicar (reconstruye los controles)
  local settings = firstValid("EnhancedInputUserSettings")
  if settings then
    local ok, err = pcall(function() settings:ApplySettings() end)
    if not ok then log("ApplySettings falló: " .. tostring(err)) end
  end
  -- 2) Pedir rebuild directo al subsistema
  local subs = FindAllOf("EnhancedInputLocalPlayerSubsystem")
  if not subs then return end
  for _, s in ipairs(subs) do
    if s:IsValid() then
      local ok, err = pcall(function()
        s:RequestRebuildControlMappings({ bIgnoreAllPressedKeysUntilRelease = true, bForceImmediately = true }, 0)
      end)
      if not ok then log("RequestRebuildControlMappings falló: " .. tostring(err)) end
    end
  end
end

local function keyName(k)
  local ok, v = pcall(function() return k.KeyName:ToString() end)
  return ok and v or "?"
end

-- ===== Nombre "personalizable" de cada mapeo (lo que usa el perfil del jugador) =====
local function getMappingName(m)
  local name
  pcall(function()
    local s = m.PlayerMappableKeySettings
    if s and s:IsValid() then name = s.Name:ToString() end
  end)
  if name and name ~= "None" and name ~= "" then return name end
  name = nil
  pcall(function()
    local s = m.Action.PlayerMappableKeySettings
    if s and s:IsValid() then name = s.Name:ToString() end
  end)
  if name and name ~= "None" and name ~= "" then return name end
  return nil
end

local function unwrap(e)
  local ok, v = pcall(function() return e:get() end)
  if ok and v ~= nil then return v end
  return e
end

-- ===== Tap / Hold (estilo Dark Souls) =====
local trigDone = {}   -- id de mapeo -> "tap"/"hold" ya aplicado

local function trigNames(arr)
  local t = {}
  pcall(function()
    arr:ForEach(function(i, e)
      local o = unwrap(e)
      if o and o:IsValid() then t[#t + 1] = o:GetClass():GetFName():ToString():gsub("^InputTrigger", "") end
    end)
  end)
  return table.concat(t, ",")
end

local function newTrigger(className, outer, props)
  local cls = StaticFindObject("/Script/EnhancedInput." .. className)
  if not cls or not cls:IsValid() then error("no encontré la clase " .. className) end
  local obj = StaticConstructObject(cls, outer)
  if not obj or not obj:IsValid() then error("no pude crear " .. className) end
  for k, v in pairs(props) do obj[k] = v end
  return obj
end

local function setOnlyTrigger(arr, obj)
  arr:Empty()
  arr[1] = obj
end

local function comboFor(actionName, key, ctxName)
  for _, c in ipairs(cfg.combos or {}) do
    local ctxOk = (c.context == nil) or (ctxName ~= nil and ctxName:lower():find(c.context:lower(), 1, true) ~= nil)
    if c.key == key and ctxOk then
      if c.tap == actionName then return "tap", c end
      if c.hold == actionName then return "hold", c end
      if c.press == actionName then return "press", c end
    end
  end
end

local function isComboAction(actionName)
  for _, c in ipairs(cfg.combos or {}) do
    if c.tap == actionName or c.hold == actionName or c.press == actionName then return true end
  end
  return false
end

-- Los triggers a nivel de ACCIÓN aplican a TODOS sus mapeos (en todos los menús).
-- Para que el tap/hold de un botón no rompa los demás, se "mudan": se quitan de la acción
-- y se copian a cada mapeo que NO es parte de un combo.
local migrated = {}       -- actionName -> lista de triggers originales de la acción
local migratedDone = {}   -- id de mapeo -> true

local function migrateActionTriggers(m, actionName)
  if migrated[actionName] then return end
  local list = {}
  local ok, err = pcall(function()
    m.Action.Triggers:ForEach(function(i, e)
      local o = unwrap(e)
      if o and o:IsValid() then list[#list + 1] = o end
    end)
    m.Action.Triggers:Empty()
  end)
  migrated[actionName] = list
  if ok then
    if #list > 0 then log("combo: triggers de " .. actionName .. " movidos a sus mapeos (" .. #list .. ")") end
  else
    log("combo: no pude mover triggers de " .. actionName .. ": " .. tostring(err))
  end
end

local function giveBackActionTriggers(m, id, actionName)
  local list = migrated[actionName]
  if not list or #list == 0 or migratedDone[id] then return false end
  local ok, err = pcall(function()
    local n = m.Triggers:GetArrayNum()
    for _, t in ipairs(list) do
      n = n + 1
      m.Triggers[n] = t
    end
  end)
  migratedDone[id] = true
  if not ok then log("combo: no pude copiar triggers a un mapeo de " .. actionName .. ": " .. tostring(err)) end
  return ok
end

local function applyCombo(ctx, m, id, actionName, key, ctxName)
  local kind, c = comboFor(actionName, key, ctxName)
  if not kind or trigDone[id] == kind then return false end
  local ok, err = pcall(function()
    local trig
    if kind == "tap" then
      trig = newTrigger("InputTriggerTap", ctx, { TapReleaseTimeThreshold = c.tap_time or 0.25 })
    elseif kind == "press" then
      trig = newTrigger("InputTriggerPressed", ctx, {})
    else
      trig = newTrigger("InputTriggerHold", ctx, { HoldTimeThreshold = c.hold_time or 0.25, bIsOneShot = c.one_shot and true or false })
    end
    setOnlyTrigger(m.Triggers, trig)
  end)
  trigDone[id] = kind
  migratedDone[id] = true
  if ok then
    log("combo: " .. actionName .. " = " .. kind .. " en " .. key .. " (" .. ctxName .. ")")
    return true
  else
    log("combo: falló " .. actionName .. " (" .. kind .. "): " .. tostring(err))
    return false
  end
end

-- ===== Perfil del jugador: forzar que el botón ACTUAL sea el que pide el config =====
local function processProfile(desiredByRow, doDump)
  local prof = firstValid("EnhancedPlayerMappableKeyProfile")
  if not prof then return 0 end

  local lines, changed = {}, 0
  local ok, err = pcall(function()
    prof.PlayerMappedKeys:ForEach(function(k, v)
      local rowName = unwrap(k):ToString()
      local row = unwrap(v)
      row.Mappings:ForEach(function(a, b)
        local pm = unwrap(b ~= nil and b or a)
        local def = keyName(pm.DefaultKey)
        local cur = keyName(pm.CurrentKey)
        if def:find("^Gamepad_") then
          local want = desiredByRow[rowName]
          if want and want ~= cur then
            pm.CurrentKey.KeyName = FName(want)
            changed = changed + 1
            if cfg.verbose then log("perfil " .. rowName .. ": " .. cur .. " -> " .. want) end
            cur = want
          end
        end
        if doDump then
          lines[#lines + 1] = string.format("%-40s %-30s -> %s", rowName, def, cur)
        end
      end)
    end)
  end)
  if not ok then log("perfil: error: " .. tostring(err)) end

  if doDump then
    table.sort(lines)
    local f = io.open(modDir .. "\\perfil_dump.txt", "w")
    if f then
      f:write("MAPPING                                  DEFAULT                        ->  ACTUAL\n")
      f:write(table.concat(lines, "\n") .. "\n")
      f:close()
    end
  end
  if changed > 0 then log("perfil: " .. changed .. " botón(es) cambiados") end
  return changed
end

-- ===== Tap "inyectado": el mod detecta el tap y dispara la acción él mismo =====
-- Para acciones que el juego activa en cuanto presionas (brincar, atacar): así mantener
-- el botón para la otra acción NUNCA activa el tap.
local DEAD_KEY = "Gamepad_LeftThumbstick"   -- L3: el GameCube no lo tiene
local injectTargets = {}   -- key -> { {action=, ctx=, c=, name=} ... }
local pressT = {}
local injLoopStarted = false

local function getPCq()
  local pcs = FindAllOf("PlayerController")
  if not pcs then return nil end
  for _, pc in ipairs(pcs) do
    if pc:IsValid() and not pc:GetFName():ToString():find("^Default__") then return pc end
  end
end

local function injectAction(t)
  local sub = firstValid("EnhancedInputLocalPlayerSubsystem")
  if not sub then return end
  -- Solo si el contexto de esa acción está activo (para no brincar dentro de menús)
  if t.ctx and t.ctx:IsValid() then
    local okH, active = pcall(function() return sub:HasMappingContext(t.ctx) end)
    if okH and active == false then return end
  end
  local ok, err = pcall(function()
    sub:InjectInputVectorForAction(t.action, { X = 1.0, Y = 0.0, Z = 0.0 }, {}, {})
  end)
  if not ok then log("inject falló (" .. t.name .. "): " .. tostring(err)) end
end

local function startInjectLoop()
  if injLoopStarted then return end
  injLoopStarted = true
  LoopAsync(15, function()
    ExecuteInGameThread(function()
      pcall(function()
        if not enabled or next(injectTargets) == nil then return end
        local pc = getPCq()
        if not pc then return end
        local now = os.clock()
        for key, list in pairs(injectTargets) do
          local down = pc:IsInputKeyDown({ KeyName = FName(key) })
          if down and not pressT[key] then
            pressT[key] = now
          elseif (not down) and pressT[key] then
            local dt = now - pressT[key]
            pressT[key] = nil
            for _, t in ipairs(list) do
              if dt <= (t.c.tap_time or 0.25) then injectAction(t) end
            end
          end
        end
      end)
    end)
    return false
  end)
  log("tap inyectado: activo")
end

local function process(doDump)
  local ctxs = FindAllOf("InputMappingContext") or {}
  injectTargets = {}
  local lines, changed = {}, 0
  local desiredByRow = {}
  local named = 0

  -- Pre-pase: mudar los triggers de las acciones que tienen combo
  if enabled then
    for _, ctx in ipairs(ctxs) do
      if ctx:IsValid() and not ctx:GetFName():ToString():find("^Default__") then
        local arr = getMappings(ctx)
        if arr then
          arr:ForEach(function(i, elem)
            local m = elem:get()
            pcall(function()
              if m.Action and m.Action:IsValid() then
                local an = m.Action:GetFName():ToString()
                if isComboAction(an) then migrateActionTriggers(m, an) end
              end
            end)
          end)
        end
      end
    end
  end

  for _, ctx in ipairs(ctxs) do
    if ctx:IsValid() then
      local ctxName = ctx:GetFName():ToString()
      if not ctxName:find("^Default__") then
        local ctxFull = ctx:GetFullName()
        local arr = getMappings(ctx)
        if arr then
          local excluded = isExcluded(ctxName)
          arr:ForEach(function(i, elem)
            local m = elem:get()
            local okK, cur = pcall(function() return m.Key.KeyName:ToString() end)
            if not okK then return end
            local id = ctxFull .. "#" .. i
            if originals[id] == nil then originals[id] = cur end
            local orig = originals[id]

            local actionName = "?"
            pcall(function()
              if m.Action and m.Action:IsValid() then actionName = m.Action:GetFName():ToString() end
            end)

            local want, rule = orig, nil
            if enabled and not excluded then
              local w, r = ruleFor(ctxName, actionName, orig)
              if w then want, rule = w, r end
            end
            local injected = false
            if enabled and not excluded and orig:find("^Gamepad_") then
              local kind, c = comboFor(actionName, want, ctxName)
              if kind == "tap" and c.inject then
                injectTargets[want] = injectTargets[want] or {}
                table.insert(injectTargets[want], { action = m.Action, ctx = ctx, c = c, name = actionName })
                want = DEAD_KEY
                injected = true
              end
            end
            if want ~= cur then
              m.Key.KeyName = FName(want)
              changed = changed + 1
              if cfg.verbose then log(ctxName .. " / " .. actionName .. ": " .. cur .. " -> " .. want) end
            end

            -- detach = true: este mapeo deja de seguir al perfil compartido (para poder tener
            -- un botón distinto que otros mapeos con el mismo nombre de perfil)
            local detached = false
            if rule and rule.detach or injected then
              local okD = pcall(function()
                if m.SettingBehavior ~= 2 then
                  m.SettingBehavior = 2   -- IgnoreSettings
                  changed = changed + 1
                end
              end)
              detached = okD
              if not okD then log("detach falló en " .. ctxName .. " / " .. actionName) end
            end

            -- no_consume: la acción deja pasar el botón a contextos de menor prioridad
            -- (p. ej. brincar en B no "se come" la B de levantarse de la cama)
            if enabled and cfg.no_consume then
              for _, an in ipairs(cfg.no_consume) do
                if an == actionName then
                  pcall(function()
                    if m.Action.bConsumeInput ~= false then
                      m.Action.bConsumeInput = false
                      changed = changed + 1
                      log("no_consume: " .. actionName)
                    end
                  end)
                end
              end
            end

            local mname = getMappingName(m)
            if mname and orig:find("^Gamepad_") and not detached then
              -- Si varios mapeos comparten fila del perfil, gana el que tiene regla
              if rule or desiredByRow[mname] == nil then
                desiredByRow[mname] = want
              end
              named = named + 1
            end

            if injected then
              -- nada: el mod dispara esta acción él mismo
            elseif enabled and not excluded and orig:find("^Gamepad_") and comboFor(actionName, want, ctxName) then
              if applyCombo(ctx, m, id, actionName, want, ctxName) then changed = changed + 1 end
            elseif migrated[actionName] then
              if giveBackActionTriggers(m, id, actionName) then changed = changed + 1 end
            end

            if doDump and (orig:find("^Gamepad_") or cfg.dump_all) then
              local now = (want ~= orig) and ("  ->  " .. want) or ""
              local trig = ""
              pcall(function() trig = trigNames(m.Triggers) end)
              local atrig = ""
              pcall(function() atrig = trigNames(m.Action.Triggers) end)
              lines[#lines + 1] = string.format("%-36s %-36s %-30s %s%s   [map:%s | act:%s]%s", ctxName, actionName,
                mname or "-", orig, now, trig, atrig, excluded and "   (excluido)" or "")
            end
          end)
        end
      end
    end
  end

  changed = changed + processProfile(desiredByRow, doDump)
  if next(injectTargets) ~= nil then startInjectLoop() end

  if changed > 0 then
    log(changed .. " cambio(s) aplicados (" .. named .. " mapeos con nombre de perfil)")
    rebuild()
  end

  if doDump then
    table.sort(lines)
    local f = io.open(modDir .. "\\mappings_dump.txt", "w")
    if f then
      f:write("CONTEXTO                             ACCION                               PERFIL                         ORIGINAL -> NUEVO   [triggers]\n")
      f:write(string.rep("-", 140) .. "\n")
      f:write(table.concat(lines, "\n"))
      f:write("\n")
      f:close()
      log("dumps actualizados (" .. #lines .. " filas, " .. #ctxs .. " contextos)")
    end
  end
end

local function safeProcess(doDump)
  local ok, err = pcall(process, doDump)
  if not ok then log("error: " .. tostring(err)) end
end

-- Programa UN pase (agrupa muchos eventos seguidos en uno solo)
local function schedule(delayMs)
  if pending then return end
  pending = true
  ExecuteWithDelay(delayMs, function()
    ExecuteInGameThread(function()
      pending = false
      local first = not dumpedOnce
      dumpedOnce = true
      safeProcess(first)
    end)
  end)
end

loadConfig()

-- Cuando el juego crea/carga un mapping context nuevo
NotifyOnNewObject("/Script/EnhancedInput.InputMappingContext", function()
  schedule(1500)
end)

-- Cuando el jugador (re)aparece
pcall(function()
  RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
    schedule(1000)
  end)
end)

-- Pase inicial por si los contextos ya estaban cargados
schedule(5000)

RegisterKeyBind(Key.F7, function()
  ExecuteInGameThread(function()
    loadConfig()
    safeProcess(true)
  end)
end)

RegisterKeyBind(Key.F8, function()
  enabled = not enabled
  log("remapeos " .. (enabled and "ACTIVADOS" or "DESACTIVADOS"))
  ExecuteInGameThread(function() safeProcess(false) end)
end)

-- ===== F9: modo prueba de botones =====
-- Escribe en botones_test.txt qué botón recibe el juego cada vez que presionas uno.
-- Se apaga solo a los 60 s (o con F9 otra vez).
local TEST_KEYS = {
  "Gamepad_FaceButton_Bottom", "Gamepad_FaceButton_Right", "Gamepad_FaceButton_Left", "Gamepad_FaceButton_Top",
  "Gamepad_LeftShoulder", "Gamepad_RightShoulder", "Gamepad_LeftTrigger", "Gamepad_RightTrigger",
  "Gamepad_LeftThumbstick", "Gamepad_RightThumbstick", "Gamepad_Special_Left", "Gamepad_Special_Right",
  "Gamepad_DPad_Up", "Gamepad_DPad_Down", "Gamepad_DPad_Left", "Gamepad_DPad_Right",
}
local testOn, testDeadline, testDown, testN = false, 0, {}, 0

local function getPC()
  local pcs = FindAllOf("PlayerController")
  if not pcs then return nil end
  for _, pc in ipairs(pcs) do
    if pc:IsValid() and not pc:GetFName():ToString():find("^Default__") then return pc end
  end
end

local function testWrite(s, mode)
  local f = io.open(modDir .. "\\botones_test.txt", mode or "a")
  if f then f:write(s .. "\n"); f:close() end
end

RegisterKeyBind(Key.F9, function()
  testOn = not testOn
  if not testOn then log("prueba de botones APAGADA"); return end
  testDeadline = os.time() + 60
  testDown, testN = {}, 0
  testWrite("Prueba de botones — presiona cada botón de uno en uno, en orden:", "w")
  log("prueba de botones ENCENDIDA (60 s)")
  LoopAsync(50, function()
    if not testOn or os.time() > testDeadline then
      testOn = false
      testWrite("-- fin de la prueba --")
      log("prueba de botones terminada")
      return true
    end
    ExecuteInGameThread(function()
      pcall(function()
        local pc = getPC()
        if not pc then return end
        for _, k in ipairs(TEST_KEYS) do
          local down = pc:IsInputKeyDown({ KeyName = FName(k) })
          if down and not testDown[k] then
            testN = testN + 1
            testWrite(string.format("%2d. %s", testN, k))
            log("botón: " .. k)
          end
          testDown[k] = down
        end
      end)
    end)
    return false
  end)
end)

log("v0.11 cargado desde " .. modDir)
