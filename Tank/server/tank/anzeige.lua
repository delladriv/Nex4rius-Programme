-- pastebin run -f cyF0yhXZ
-- von Nex4rius
-- https://github.com/Nex4rius/Nex4rius-Programme/

local component = require("component")
local c = require("computer")
local gpu = component.getPrimary("gpu")
local event = require("event")
local term = require("term")
local m, version, tankneu
if component.isAvailable("modem") then
  m = component.modem
end
local farben = loadfile("/tank/farben.lua")()
local ersetzen = loadfile("/tank/ersetzen.lua")()
local port = 70
local tank = {}
local laeuft = true
local startevents = false
local Wartezeit = 60
local letzteNachricht = c.uptime()

if require("filesystem").exists("/tank/version.txt") then
    local f = io.open ("/tank/version.txt", "r")
    version = f:read()
    f:close()
  else
    version = "<FEHLER>"
end

function update()
  local hier, _, id, _, _, nachricht
  if startevents then
    if m then
      hier, _, id, _, _, nachricht = event.pull(Wartezeit, "modem_message")
      letzteNachricht = c.uptime()
    else
      os.sleep(Wartezeit)
    end
  end
  startevents = true
  local dazu = true
  local ende = 0
--[[ buggy
  local eigenerTank = check()
  if eigenerTank then
    local dazu = true
    for i in pairs(tank) do
      if type(tank[i]) == "table" then
        if tank[i].id == c.address() then
          tank[i].zeit = c.uptime()
          tank[i].inhalt = eigenerTank
          dazu = false
        end
      end
      ende = i
    end
    if dazu then
      ende = ende + 1
      tank[ende] = {}
      tank[ende].id = c.address()
      tank[ende].zeit = c.uptime()
      tank[ende].inhalt = eigenerTank
    end
    if not hier then
      anzeigen(verarbeiten(tank))
    end
  end
--]]
  if hier then
    for i in pairs(tank) do
      if type(tank[i]) == "table" then
        if tank[i].id == id then
          tank[i].zeit = c.uptime()
          tank[i].inhalt = require("serialization").unserialize(nachricht)
          dazu = false
        end
      end
      ende = i
    end
    if dazu then
      ende = ende + 1
      tank[ende] = {}
      tank[ende].id = id
      tank[ende].zeit = c.uptime()
      tank[ende].inhalt = require("serialization").unserialize(nachricht)
    end
    anzeigen(verarbeiten(tank))
  elseif not eigenerTank then
    if m then
      m.broadcast(port + 1, "update", version)
    end
    keineDaten()
  end
  for i in pairs(tank) do
    if c.uptime() - tank[i].zeit > Wartezeit * 2 then
      tank[i] = nil
    end
  end
end

function keineDaten()
  if c.uptime() - letzteNachricht > Wartezeit then
    gpu.setResolution(gpu.maxResolution())
    gpu.fill(1, 1, 160, 80, " ")
    gpu.set(1, 50, "Keine Daten vorhanden")
  end
end

function check()
  local tank = {}
  local i = 1
  local leer = true
  for adresse, name in pairs(component.list("tank_controller")) do
    for side = 0, 5 do
      for a, b in pairs(component.proxy(adresse).getFluidInTank(side)) do
        if type(a) == "number" then
          local dazu = true
          local c
          for j, k in pairs(tank) do
            if b.name == k.name then
              dazu = false
              c = j
              break
            end
          end
          if b.label ~= nil then
            if dazu then
              tank[i] = {}
              tank[i].name = b.name
              tank[i].label = b.label
              tank[i].menge = b.amount
              tank[i].maxmenge = b.capacity
              i = i + 1
            else
              tank[c].menge = tank[c].menge + b.amount
              tank[c].maxmenge = tank[c].maxmenge + b.capacity
            end
            leer = false
          end
        end
      end
    end
  end
  if leer then
    return false
  else
    return tank
  end
end

function hinzu(name, label, menge, maxmenge)
  local weiter = true
  if name ~= "nil" then
    for i in pairs(tankneu) do
      if tankneu[i].name == name then
        tankneu[i].menge = tankneu[i].menge + menge
        tankneu[i].maxmenge = tankneu[i].maxmenge + maxmenge
        weiter = false
      end
    end
    if weiter then
      tankneu[tanknr] = {}
      tankneu[tanknr].name = name
      tankneu[tanknr].label = label
      tankneu[tanknr].menge = menge
      tankneu[tanknr].maxmenge = maxmenge
    end
  end
end

function verarbeiten(tank)
  tankneu = {}
  tanknr = 0
  for i in pairs(tank) do
    if type(tank[i]) == "table" then
      for j in pairs(tank[i].inhalt) do
        tanknr = tanknr + 1
        hinzu(tank[i].inhalt[j].name, tank[i].inhalt[j].label, tank[i].inhalt[j].menge, tank[i].inhalt[j].maxmenge)
      end
    end
  end
  return tankneu
end

function spairs(t, order)
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function anzeigen(tankneu)
  local x = 1
  local y = 1
  local leer = true
  local anzahl = 0
  if #tankneu <= 16 and #tankneu ~= 0 then
    gpu.setResolution(80, #tankneu * 3)
  else
    gpu.setResolution(160, 48)
  end
  os.sleep(0.1)
  for i in spairs(tankneu, function(t,a,b) return tonumber(t[b].menge) < tonumber(t[a].menge) end) do
    anzahl = anzahl + 1
    if anzahl == 17 then
      x = 81
      y = 1
    end
    local name = tankneu[i].name
    local label = tankneu[i].label
    local menge = tankneu[i].menge
    local maxmenge = tankneu[i].maxmenge
    local prozent = menge / maxmenge * 100
    zeigeHier(x, y, zeichenErsetzen(string.gsub(label, "%p", "")), string.gsub(name, "%p", ""), menge, maxmenge, prozent)
    leer = false
    y = y + 3
  end
  if anzahl <= 16 and anzahl ~= 0 then
    gpu.setResolution(80, anzahl * 3)
  else
    gpu.setResolution(160, 48)
  end
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
  for i = anzahl, 33 do
    gpu.set(x, y    , string.rep(" ", 80))
    gpu.set(x, y + 1, string.rep(" ", 80))
    gpu.set(x, y + 2, string.rep(" ", 80))
    y = y + 3
  end
  if leer then
    if m then
      m.broadcast(port + 1, "update", version)
    end
    gpu.setResolution(gpu.maxResolution())
    keineDaten()
  end
end

function zeichenErsetzen(...)
  return string.gsub(..., "%a+", function (str) return ersetzen [str] end)
end

function zeigeHier(x, y, label, name, menge, maxmenge, prozent)
  local nachricht = string.format("%s     %smb/%smb     %.1f%%", label, menge, maxmenge, prozent)
  if farben[name] == nil then
    nachricht = string.format("%s - %s     %smb/%smb     %.1f%%", name, label, menge, maxmenge, prozent)
    name = "unbekannt"
  end
  local laenge = (80 - string.len(nachricht)) / 2
  nachricht = split(string.format("%s%s%s ", string.rep(" ", laenge), nachricht, string.rep(" ", laenge)))
  if type(farben[name][1]) == "number" then
    gpu.setForeground(farben[name][1])
  else
    gpu.setForeground(0xFFFFFF)
  end
  if type(farben[name][2]) == "number" then
    gpu.setBackground(farben[name][2])
  else
    gpu.setBackground(0x444444)
  end
  local ende = 0
  for i = 1, math.floor(80 * menge / maxmenge) do
    gpu.set(x, y, string.format(" %s ", nachricht[i]), true)
    x = x + 1
    ende = i
  end
  if type(farben[name][3]) == "number" then
    gpu.setForeground(farben[name][3])
  else
    gpu.setForeground(0xFFFFFF)
  end
  if type(farben[name][4]) == "number" then
    gpu.setBackground(farben[name][4])
  else
    gpu.setBackground(0x333333)
  end
  local a = math.floor(80 * menge / maxmenge)
  for i = 1, 80 - a do
    gpu.set(x, y, string.format(" %s ", nachricht[i + ende]), true)
    x = x + 1
  end
end

function split(a)
  local output = {}
  for i = 1, string.len(a) do
    output[i] = string.sub(a, i, i)
  end
  return output
end

function beenden()
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
  gpu.setResolution(gpu.maxResoltution())
end

function main()
  gpu.setBackground(0x000000)
  term.setCursor(1, 50)
  if m then
    m.open(port)
    m.broadcast(port + 1, "update", version)
  end
  gpu.setResolution(gpu.maxResolution())
  gpu.fill(1, 1, 160, 80, " ")
  gpu.set(1, 50, "Warte auf Daten")
  while laeuft do
    update()
  end
  beenden()
end

main()
