-- pastebin run -f YVqKFnsP
-- nexDHD von Nex4rius
-- https://github.com/Nex4rius/Nex4rius-Programme/tree/master/nexDHD

if require then
  OC = true
  CC = nil
  require("shell").setWorkingDirectory("/")
else
  OC = nil
  CC = true
end

local io                        = io
local os                        = os
local table                     = table
local string                    = string
local print                     = print
local pcall                     = pcall
local type                      = type
local require                   = require
local loadfile                  = loadfile

local component                 = {}
local event                     = {}
local Farben                    = {}
local term                      = term or require("term")
local fs                        = fs or require("filesystem")
local shell                     = shell or require("shell")
_G.shell = shell

local gpu, serialization, sprachen, unicode, ID, Updatetimer, log, computer

if OC then
  serialization = require("serialization")
  component = require("component")
  computer = require("computer")
  event = require("event")
  unicode = require("unicode")
  gpu = component.getPrimary("gpu")
  local a = gpu.setForeground
  local b = gpu.setBackground
  gpu.setForeground = function(code) if type(code) == "number" then a(code) end end
  gpu.setBackground = function(code) if type(code) == "number" then b(code) end end
elseif CC then
  component.getPrimary = peripheral.find
  component.isAvailable = function(name)
    cc_immer = {}
    cc_immer.internet = function() return http end
    cc_immer.redstone = function() return true end
    if cc_immer[name] then
      return cc_immer[name]()
    end
    return peripheral.find(name)
  end
  gpu = component.getPrimary("monitor")
  term.redirect(gpu)
  gpu.setResolution = function() gpu.setTextScale(0.5) end
  gpu.setForeground = function(code) if code then gpu.setTextColor(code) end end
  gpu.setBackground = function(code) if code then gpu.setBackgroundColor(code) end end
  gpu.maxResolution = gpu.getSize
  gpu.getResolution = gpu.getSize
  gpu.fill = function() term.clear() end
  fs.remove = fs.remove or fs.delete
  term.setCursor = term.setCursorPos
end

local entfernen                 = fs.remove or fs.delete
local kopieren                  = fs.copy
local edit                      = loadfile("/bin/edit.lua") or function(datei) shell.run("edit " .. datei) end
local schreibSicherungsdatei    = loadfile("/stargate/schreibSicherungsdatei.lua")

if not pcall(loadfile("/einstellungen/Sicherungsdatei.lua")) then
  print("Fehler Sicherungsdatei.lua")
end

local Sicherung                 = loadfile("/einstellungen/Sicherungsdatei.lua")()

if not pcall(loadfile("/stargate/sprache/" .. Sicherung.Sprache .. ".lua")) then
  print(string.format("Fehler %s.lua", Sicherung.Sprache))
end

do
  local neu = loadfile("/stargate/sprache/" .. Sicherung.Sprache .. ".lua")()
  sprachen = loadfile("/stargate/sprache/deutsch.lua")()
  for i in pairs(sprachen) do
    if neu[i] then
      sprachen[i] = neu[i]
    end
  end
  sprachen = sprachen or neu
  if fs.exists("/stargate/log") then
    log = true
  end
  if Statustimer then
    local function statusabbrechen()
      event.cancel(Statustimer)
    end
    pcall(statusabbrechen)
  end
end

local ersetzen                  = loadfile("/stargate/sprache/ersetzen.lua")(sprachen)

local sg                        = component.getPrimary("stargate")
local screen                    = component.getPrimary("screen") or {}

local Bildschirmbreite, Bildschirmhoehe = gpu.getResolution()
local max_Bildschirmbreite, max_Bildschirmhoehe = gpu.maxResolution()

local enteridc                  = ""
local showidc                   = ""
local remoteName                = ""
local zielAdresse               = ""
local sende_modem_jetzt         = ""
local time                      = "-"
local incode                    = "-"
local codeaccepted              = "-"
local wurmloch                  = "in"
local iriscontrol               = "on"
local energytype                = "EU"
local f                         = {} -- Funktionen
local o                         = {} -- Funktionen für event.listen()
local v                         = {} -- Variabeln
local Taste                     = {}
local Logbuch                   = {}
local timer                     = {}
local activationtime            = 0
local energy                    = 0
local seite                     = 0
local maxseiten                 = 0
local checkEnergy               = 0
local zeile                     = 1
local Trennlinienhoehe          = 14
local energymultiplicator       = 20
local xVerschiebung             = 33
local AddNewAddress             = true
local messageshow               = true
local running                   = true
local send                      = true
local einmalAdressenSenden      = true
local Nachrichtleer             = true
local einmalBeenden             = true
local IDCyes                    = false
local entercode                 = false
local redstoneConnected         = false
local redstoneIncoming          = false
local redstoneState             = false
local redstoneIDC               = false
local LampenGruen               = false
local LampenRot                 = false
local VersionUpdate             = false
local reset                     = false

Taste.Koordinaten               = {}
Taste.Steuerunglinks            = {}
Taste.Steuerungrechts           = {}

v.IDC_Anzahl                    = 0
v.reset_uptime                  = computer.uptime()
v.reset_time                    = os.time()

local adressen, alte_eingabe, anwahlEnergie, ausgabe, chevron, direction, eingabe, energieMenge, ergebnis, gespeicherteAdressen, sensor, sectime, letzteNachrichtZeit, alte_modem_message
local iris, letzteNachricht, locAddr, mess, mess_old, ok, remAddr, result, RichtungName, sendeAdressen, sideNum, state, StatusName, version, letzterAdressCheck, c, e, d, k, r, Farben

local chevronAnzeige = {}
chevronAnzeige.zeig = function() end
chevronAnzeige.iris = function() end
chevronAnzeige.beenden = function() end

do
  local function check_modem_senden()
    if component.isAvailable("modem") and state ~= "Idle" and state ~= "Closing" then
      return component.modem.broadcast(Sicherung.Port, sende_modem_jetzt)
    end
  end
  sg.sendMessage_alt = sg.sendMessage
  sg.sendMessage = function(...)
    sg.sendMessage_alt(...)
    local daten = {...}
    sende_modem_jetzt = daten[1]
    if not check_modem_senden() then
      event.timer(5, check_modem_senden, 1)
    end
  end
  
  if fs.exists("/einstellungen/logbuch.lua") then
    local neu = loadfile("/einstellungen/logbuch.lua")()
    if type(neu) == "table" then
      Logbuch = neu
    end
  end
  if fs.exists("/einstellungen/ID.lua") then
    local d = io.open("/einstellungen/ID.lua", "r")
    ID = d:read()
    d:close()
  end
  sectime                       = os.time()
  os.sleep(1)
  sectime                       = sectime - os.time()
  letzteNachrichtZeit           = os.time()
  letzterAdressCheck            = os.time() / sectime
  local args                    = {...}
  f.update                      = args[1]
  f.checkServerVersion          = args[2]
  version                       = tostring(args[3])
  Farben                        = args[4] or {}
end

if Sicherung.RF then
  energytype                    = "RF"
  energymultiplicator           = 80
end

if sg.irisState() == "Offline" then
  Trennlinienhoehe              = 13
end

pcall(screen.setTouchModeInverted, true)

if OC then
  if component.isAvailable("redstone") then
    r = component.getPrimary("redstone")
  end
elseif CC then
  --r = peripheral.find("redstone")
end

function f.Logbuch_schreiben(name, adresse, richtung)
  local rest = {}
  if fs.exists("/einstellungen/logbuch.lua") then
    rest = loadfile("/einstellungen/logbuch.lua")()
    if type(rest) ~= "table" then
      rest = {}
    end
  end
  for i = 20, 1, -1 do
    rest[i + 1] = rest[i]
  end
  rest[1] = {name, adresse, richtung}
  local d = io.open("/einstellungen/logbuch.lua", "w")
  d:write('-- pastebin run -f YVqKFnsP\n')
  d:write('-- nexDHD von Nex4rius\n')
  d:write('-- https://github.com/Nex4rius/Nex4rius-Programme/tree/master/nexDHD\n--\n')
  d:write('return {\n')
  for i = 1, #rest do
    d:write(string.format('  {"%s", "%s", "%s"},\n', rest[i][1], rest[i][2], rest[i][3]))
    if i > 20 then
      break
    end
  end
  d:write('}')
  d:close()
  Logbuch = loadfile("/einstellungen/logbuch.lua")()
end

function f.schreibeAdressen()
  local d = io.open("/einstellungen/adressen.lua", "r")
  if d then
    local davor = d:read("*all")
    d:close()
  end

  local d = io.open("/einstellungen/adressen.lua", "w")
  d:write('-- pastebin run -f YVqKFnsP\n')
  d:write('-- nexDHD von Nex4rius\n')
  d:write('-- https://github.com/Nex4rius/Nex4rius-Programme/tree/master/nexDHD\n--\n')
  d:write('-- ' .. sprachen.speichern .. '\n')
  d:write('-- ' .. sprachen.schliessen .. '\n--\n')
  d:write('-- ' .. sprachen.iris .. '\n')
  d:write('-- "" ' .. sprachen.keinIDC .. '\n--\n\n')
  d:write('return {\n')
  d:write('--{"<Name>", "<Adresse>", "<IDC>"},\n')
  for k, v in pairs(adressen) do
    d:write(string.format('  {"%s", "%s", "%s"},\n', v[1], v[2], v[3]))
  end
  d:write('}')
  d:close()
  -- Checken
  local a = loadfile("/einstellungen/adressen.lua")()
  if not a or #a <= 0 then
    f.zeigeFehler("<FEHLER> Schreiben der Adressdatei ist nicht möglich")
    local d = io.open("/einstellungen/adressen.lua", "w")
    d:write(davor)
    d:close()
  end
end

function f.Farbe(hintergrund, vordergrund)
  if type(hintergrund) == "number" then
    gpu.setBackground(hintergrund)
  end
  if type(vordergrund) == "number" then
    gpu.setForeground(vordergrund)
  end
end

function f.reset()
  local uptime = computer.uptime() - v.reset_uptime
  local time =  (os.time() - v.reset_time) / 100
  
  v.reset_uptime = computer.uptime()
  v.reset_time = os.time()
  
  if uptime - time > 6000 or time - uptime > 6000 then
    reset = "nochmal"
    running = false
    require("computer").shutdown(true)
  end
end

function f.pull_event()
  local Wartezeit = 1
  if state == "Idle" then
    alte_modem_message = nil
    v.IDC_Anzahl = 0
    if checkEnergy == energy and not VersionUpdate then
      if Nachrichtleer == true then
        Wartezeit = 600
      else
        Wartezeit = 50
      end
    end
    if VersionUpdate then
      local serverVersion = f.checkServerVersion("master")
      if serverVersion ~= sprachen.fehlerName then
        f.Logbuch_schreiben(serverVersion, "Update:    " , "update")
        running = false
        v.update = "ja"
      else
        VersionUpdate = false
        f.zeigeNachricht(sprachen.fehlerName)
      end
    end
  end
  checkEnergy = energy
  return {event.pull(Wartezeit)}
end

function f.zeichenErsetzen(...)
  return string.gsub(..., "%a+", function (str) return ersetzen [str] end)
end

function f.zeigeHier(x, y, s, h)
  s = tostring(s)
  if type(x) == "number" and type(y) == "number" then
    if not h then
      h = Bildschirmbreite
    end
    if OC then
      gpu.set(x, y, s .. string.rep(" ", h - unicode.len(s)))
    elseif CC then
      term.setCursorPos(x, y)
      local wiederholanzahl = h - string.len(s)
      if wiederholanzahl < 0 then
        wiederholanzahl = 0
      end
      term.write(s .. string.rep(" ", wiederholanzahl))
    end
  end
end

function f.ErsetzePunktMitKomma(...)
  if sprachen.dezimalkomma == true then
    local Punkt = string.find(..., "%.")
    if type(Punkt) == "number" then
      return string.sub(..., 0, Punkt - 1) .. "," .. string.sub(..., Punkt + 1)
    end
  end
  return ...
end

function f.getAddress(...)
  if ... == "" or ... == nil then
    return ""
  elseif string.len(...) == 7 then
    return string.sub(..., 1, 4) .. "-" .. string.sub(..., 5, 7)
  else
    return string.sub(..., 1, 4) .. "-" .. string.sub(..., 5, 7) .. "-" .. string.sub(..., 8, 9)
  end
end

function f.AdressenLesen()
  local y = 0
  y = f.schreiben(y, sprachen.Adressseite .. seite + 1)
  if (not gespeicherteAdressen) or (os.time() / sectime - letzterAdressCheck > 21600) then
    letzterAdressCheck = os.time() / sectime
    f.AdressenSpeichern()
  end
  for i = 1, #gespeicherteAdressen do
    local na = gespeicherteAdressen[i]
    if i >= 1 + seite * 10 and i <= 10 + seite * 10 then
      local AdressAnzeige = i - seite * 10
      if AdressAnzeige == 10 then
        AdressAnzeige = 0
      end
      if na[2] == remAddr and string.len(tostring(remAddr)) > 5 then
        f.Farbe(Farben.AdressfarbeAktiv, Farben.AdresstextfarbeAktiv)
        gpu.fill(1, y + 1, 30, 2, " ")
      end
      y = f.schreiben(y, AdressAnzeige .. " " .. string.sub(na[1], 1, xVerschiebung - 7))
      if string.sub(na[4], 1, 1) == "<" then
        y = f.schreiben(y, "   " .. na[4], background, Farben.FehlerFarbe)
        f.Farbe(background, Farben.Adresstextfarbe)
      else
        y = f.schreiben(y, "   " .. na[4])
      end
      f.Farbe(Farben.Adressfarbe, Farben.Adresstextfarbe)
    end
  end
  f.leeren(y)
end

function f.Logbuchseite()
  f.zeigeHier(1, 1, string.sub(sprachen.logbuchTitel, 1, 29), 30)
  local function ausgabe(max, Logbuch, bedingung)
    for i = 1, max do
      if Logbuch[i][3] == bedingung then
        f.zeigeHier(1, 1 + i, string.sub(string.format("%s  %s", Logbuch[i][2], Logbuch[i][1]), 1, 30), 30)
      end
    end
  end
  local max = #Logbuch
  f.Farbe(Farben.Logbuch_in, Farben.Logbuch_intext)
  ausgabe(max, Logbuch, "in")
  f.Farbe(Farben.Logbuch_out, Farben.Logbuch_outtext)
  ausgabe(max, Logbuch, "out")
  f.Farbe(Farben.Logbuch_neu, Farben.Logbuch_neutext)
  ausgabe(max, Logbuch, "neu")
  f.Farbe(Farben.Logbuch_update, Farben.Logbuch_updatetext)
  ausgabe(max, Logbuch, "update")
  f.leeren(max)
  f.Legende()
end

function f.leeren(y)
  f.Farbe(Farben.Adressfarbe, Farben.Adresstextfarbe)
  if y < 21 then
    gpu.fill(1, y + 1, 30, 22 - y, " ")
  end
end

function f.schreiben(y, text, farbeVorne, farbeHinten)
  f.Farbe(farbeVorne, farbeHinten)
  f.zeigeHier(1, y + 1, string.sub(text, 1, 29), 30)
  return y + 1
end

function f.Infoseite()
  local y = 0
  Taste.links = {}
  y = f.schreiben(y, sprachen.Steuerung)
  if iris ~= "Offline" then
    y = f.schreiben(y, "I " .. sprachen.IrisSteuerung:match("^%s*(.-)%s*$")  .. " " .. sprachen.an_aus)
    Taste.links[y] = Taste.i
    Taste.Koordinaten.Taste_i = y
  end
  y = f.schreiben(y, "Z " .. sprachen.AdressenBearbeiten)
  Taste.links[y] = Taste.z
  Taste.Koordinaten.Taste_z = y
  y = f.schreiben(y, "Q " .. sprachen.beenden)
  Taste.links[y] = Taste.q
  Taste.Koordinaten.Taste_q = y
  y = f.schreiben(y, "S " .. sprachen.EinstellungenAendern)
  Taste.links[y] = Taste.s
  Taste.Koordinaten.Taste_s = y
  y = f.schreiben(y, "A " .. sprachen.Adresseingabe)
  Taste.links[y] = Taste.a
  Taste.Koordinaten.Taste_a = y
  if log then
    y = f.schreiben(y, "L " .. sprachen.zeigeLog)
    Taste.links[y] = Taste.l
    Taste.Koordinaten.Taste_l = y
  end
  y = f.schreiben(y, "U " .. sprachen.Update)
  Taste.links[y] = Taste.u
  Taste.Koordinaten.Taste_u = y
  local version_Zeichenlaenge = string.len(version)
  if string.sub(version, version_Zeichenlaenge - 3, version_Zeichenlaenge) == "BETA" or Sicherung.debug then
    y = f.schreiben(y, "B " .. sprachen.UpdateBeta)
    Taste.links[y] = Taste.b
    Taste.Koordinaten.Taste_b = y
  end
  y = f.schreiben(y, " ")
  y = f.schreiben(y, sprachen.RedstoneSignale)
  y = f.schreiben(y, sprachen.RedstoneWeiss, Farben.weisseFarbe, Farben.schwarzeFarbe)
  y = f.schreiben(y, sprachen.RedstoneRot, Farben.roteFarbe)
  y = f.schreiben(y, sprachen.RedstoneGelb, Farben.gelbeFarbe)
  y = f.schreiben(y, sprachen.RedstoneSchwarz, Farben.schwarzeFarbe, Farben.weisseFarbe)
  y = f.schreiben(y, sprachen.RedstoneGruen, Farben.grueneFarbe)
  y = f.schreiben(y, " ", Farben.Adressfarbe, Farben.Adresstextfarbe)
  y = f.schreiben(y, sprachen.versionName .. version)
  y = f.schreiben(y, " ")
  y = f.schreiben(y, string.format("nexDHD: %s Nex4rius", sprachen.entwicklerName))
  f.leeren(y)
end

function f.AdressenSpeichern()
  local a = loadfile("/einstellungen/adressen.lua") or loadfile("/stargate/adressen.lua")
  adressen = a()
  if not adressen then
    f.zeigeFehler(string.format("Hier ist der Adressenfehler --- %s", adressen))
    f.zeigeFehler("<FEHLER> Adressdatei ist beschädigt | Kopiere beschädigte Datei nach /adressen.lua")
    kopieren("/einstellungen/adressen.lua", "/adressen.lua")
    adressen = loadfile("/stargate/adressen.lua")()
  end
  gespeicherteAdressen = {}
  sendeAdressen = {}
  local k = 0
  local LokaleAdresse = f.getAddress(sg.localAddress())
  for i, na in pairs(adressen) do
    if na[2] == LokaleAdresse then
      k = -1
      sendeAdressen[i] = {}
      sendeAdressen[i][1] = na[1]
      sendeAdressen[i][2] = na[2]
      v.lokaleAdresse = true
      Sicherung.StargateName = na[1]
    else
      local anwahlEnergie = sg.energyToDial(na[2])
      if not anwahlEnergie then
        anwahlEnergie = sprachen.fehlerName
      else
        anwahlEnergie = anwahlEnergie * energymultiplicator
        sendeAdressen[i] = {}
        sendeAdressen[i][1] = na[1]
        sendeAdressen[i][2] = na[2]
        if     anwahlEnergie < 10000 then
          anwahlEnergie = string.format("%.f" , (sg.energyToDial(na[2]) * energymultiplicator))
        elseif anwahlEnergie < 10000000 then
          anwahlEnergie = string.format("%.1f", (sg.energyToDial(na[2]) * energymultiplicator) / 1000) .. " k"
        elseif anwahlEnergie < 10000000000 then
          anwahlEnergie = string.format("%.2f", (sg.energyToDial(na[2]) * energymultiplicator) / 1000000) .. " M"
        elseif anwahlEnergie < 10000000000000 then
          anwahlEnergie = string.format("%.3f", (sg.energyToDial(na[2]) * energymultiplicator) / 1000000000) .. " G"
        elseif anwahlEnergie < 10000000000000000 then
          anwahlEnergie = string.format("%.3f", (sg.energyToDial(na[2]) * energymultiplicator) / 1000000000000) .. " T"
        elseif anwahlEnergie < 10000000000000000000 then
          anwahlEnergie = string.format("%.3f", (sg.energyToDial(na[2]) * energymultiplicator) / 1000000000000000) .. " P"
        elseif anwahlEnergie < 10000000000000000000000 then
          anwahlEnergie = string.format("%.3f", (sg.energyToDial(na[2]) * energymultiplicator) / 1000000000000000000) .. " E"
        elseif anwahlEnergie < 10000000000000000000000000 then
          anwahlEnergie = string.format("%.3f", (sg.energyToDial(na[2]) * energymultiplicator) / 1000000000000000000000) .. " Z"
        else
          anwahlEnergie = sprachen.zuvielEnergie
        end
      end
      gespeicherteAdressen[i + k] = {}
      gespeicherteAdressen[i + k][1] = na[1]
      gespeicherteAdressen[i + k][2] = na[2]
      gespeicherteAdressen[i + k][3] = na[3]
      gespeicherteAdressen[i + k][4] = f.ErsetzePunktMitKomma(anwahlEnergie)
    end
    f.zeigeNachricht(sprachen.verarbeiteAdressen .. "<" .. na[2] .. "> <" .. na[1] .. ">")
    maxseiten = (i + k) / 10
  end
  if not v.lokaleAdresse then
    f.checkStargateName()
  end
  f.Farbe(Farben.Adressfarbe, Farben.Adresstextfarbe)
  for P = 1, Bildschirmhoehe - 3 do
    f.zeigeHier(1, P, "", xVerschiebung - 3)
  end
  f.zeigeMenu()
  f.zeigeNachricht("")
end

function f.zeigeMenu()
  f.Farbe(Farben.Adressfarbe, Farben.Adresstextfarbe)
  --for i = 1, Bildschirmhoehe - 3 do
  --  f.zeigeHier(1, i, "", xVerschiebung - 3)
  --end
  term.setCursor(1, 1)
  if seite == -1 then
    f.Infoseite()
  elseif seite == -2 then
    f.Logbuchseite()
  else
    f.AdressenLesen()
    iris = f.getIrisState()
  end
end

function f.neueZeile(...)
  zeile = zeile + ...
end

function f.zeigeFarben()
  f.Farbe(Farben.Trennlinienfarbe)
  for P = 1, Bildschirmhoehe - 2 do
    f.zeigeHier(xVerschiebung - 2, P, "  ", 1)
  end
  f.zeigeHier(1, Bildschirmhoehe - 2, "", 80)
  f.zeigeHier(xVerschiebung - 2, Trennlinienhoehe, "")
  f.neueZeile(1)
end

function f.getIrisState()
  ok, result = pcall(sg.irisState)
  return result
end

function f.irisClose()
  sg.closeIris()
  f.RedstoneAenderung(Farben.yellow, 255)
  f.Colorful_Lamp_Steuerung()
  chevronAnzeige.iris(true)
end

function f.irisOpen()
  sg.openIris()
  f.RedstoneAenderung(Farben.yellow, 0)
  f.Colorful_Lamp_Steuerung()
  chevronAnzeige.iris(false)
end

function f.sides()
  if Sicherung.side == "oben" or Sicherung.side == sprachen.oben then
    sideNum = 1
  elseif Sicherung.side == "hinten" or Sicherung.side == sprachen.hinten then
    sideNum = 2
  elseif Sicherung.side == "vorne" or Sicherung.side == sprachen.vorne then
    sideNum = 3
  elseif Sicherung.side == "rechts" or Sicherung.side == sprachen.rechts then
    sideNum = 4
  elseif Sicherung.side == "links" or Sicherung.side == sprachen.links then
    sideNum = 5
  else
    sideNum = 0
  end
end

function f.Iriskontrolle()
  if state == "Dialing" then
    messageshow = true
    AddNewAddress = true
  end
  if direction == "Incoming" and incode == Sicherung.IDC and Sicherung.control == "Off" then
    IDCyes = true
    f.RedstoneAenderung(Farben.black, 255)
    if iris == "Closed" or iris == "Closing" or LampenRot == true then else
      f.Colorful_Lamp_Farben(992)
    end
  end
  if direction == "Incoming" and incode == Sicherung.IDC and iriscontrol == "on" and Sicherung.control == "On" then
    if iris == "Offline" then
      if f.atmosphere(true) then
        sg.sendMessage("IDC Accepted Iris: Offline" .. f.atmosphere(true))
      else
        sg.sendMessage("IDC Accepted Iris: Offline")
      end 
    else
      f.irisOpen()
      os.sleep(2)
      if f.atmosphere(true) then
        sg.sendMessage("IDC Accepted Iris: Open" .. f.atmosphere(true))
      else
        sg.sendMessage("IDC Accepted Iris: Open")
      end
    end
    iriscontrol = "off"
    IDCyes = true
  elseif direction == "Incoming" and send == true then
    if f.atmosphere(true) then
      sg.sendMessage("Iris Control: " .. Sicherung.control .. " Iris: " .. iris .. f.atmosphere(true), f.sendeAdressliste())
    else
      sg.sendMessage("Iris Control: " .. Sicherung.control .. " Iris: " .. iris, f.sendeAdressliste())
    end
    send = false
    f.zeigeMenu()
  end
  if wurmloch == "in" and state == "Dialling" and iriscontrol == "on" and Sicherung.control == "On" then
    if iris == "Offline" then else
      f.irisClose()
      f.RedstoneAenderung(Farben.red, 255)
      redstoneIncoming = false
    end
    k = "close"
  end
  if iris == "Closing" and Sicherung.control == "On" then
    k = "open"
  end
  if state == "Idle" and k == "close" and Sicherung.control == "On" then
    outcode = nil
    if iris == "Offline" then else
      f.irisOpen()
    end
    iriscontrol = "on"
    wurmloch = "in"
    codeaccepted = "-"
    activationtime = 0
    entercode = false
    showidc = ""
    zielAdresse = ""
  end
  if state == "Idle" and Sicherung.control == "On" then
    iriscontrol = "on"
  end
  if state == "Closing" then
    send = true
    incode = "-"
    IDCyes = false
    AddNewAddress = true
    LampenGruen = false
    LampenRot = false
    zielAdresse = ""
    f.zeigeNachricht("")
    f.zeigeMenu()
    if v.Anzeigetimer then
      event.cancel(v.Anzeigetimer)
    end
    chevronAnzeige.zeig(false, "ende")
  end
  if state == "Idle" then
    incode = "-"
    wurmloch = "in"
    AddNewAddress = true
    LampenGruen = false
    LampenRot = false
    zielAdresse = ""
    einmalBeenden = true
  end
  if state == "Closing" and Sicherung.control == "On" then
    k = "close"
  end
  if state == "Connected" and direction == "Outgoing" and send == true then
    if outcode == "-" or outcode == nil then
      sg.sendMessage_alt("Adressliste", f.sendeAdressliste())
    else
      sg.sendMessage_alt(outcode, f.sendeAdressliste())
    end
    send = false
  end
  if codeaccepted == "-" or codeaccepted == nil then
  elseif messageshow == true then
    f.zeigeNachricht(sprachen.nachrichtAngekommen .. f.zeichenErsetzen(codeaccepted) .. "                   ")
    if codeaccepted == "Request: Disconnect Stargate" then
      sg.disconnect()
    elseif string.match(codeaccepted, "Iris: Open") or string.match(codeaccepted, "Iris: Offline") then
      LampenGruen = true
      LampenRot = false
    elseif string.match(codeaccepted, "Iris: Closed") then
      LampenGruen = false
      LampenRot = true
    end
    messageshow = false
    incode = "-"
    codeaccepted = "-"
  end
  if state == "Idle" then
    activationtime = 0
    entercode = false
    remoteName = ""
    einmalAdressenSenden = true
  end
end

function f.sendeAdressliste()
  if einmalAdressenSenden and Sicherung.kein_senden ~= true then
    einmalAdressenSenden = false
    if OC then
      return "Adressliste", serialization.serialize(sendeAdressen), version
    elseif CC then --CC fehlt
      return "Adressliste", "", version
    end
  else
    return ""
  end
end

function f.newAddress(idc, neueAdresse, neuerName, weiter)
  if AddNewAddress == true and string.len(neueAdresse) >= 7 and string.len(neueAdresse) <= 11 and sg.energyToDial(neueAdresse) then
    local i = 1
    for k in pairs(adressen) do
      i = k + 1
    end
    adressen[i] = {}
    local nichtmehr
    if neuerName == nil then
      adressen[i][1] = ">>>" .. neueAdresse .. "<<<"
    else
      adressen[i][1] = neuerName
      nichtmehr = true
      f.Logbuch_schreiben(neuerName , neueAdresse, "neu")
    end
    adressen[i][2] = neueAdresse
    adressen[i][3] = idc or ""
    if weiter == nil then
      f.schreibeAdressen()
      if nichtmehr then
        AddNewAddress = false
      end
      f.AdressenSpeichern()
      f.zeigeMenu()
    end
    return true
  end
end

function f.Zielname()
  if state == "Dialling" or state == "Connected" then
    if remoteName == "" and wurmloch == "in" and type(adressen) == "table" then
      for j, na in pairs(adressen) do
        if remAddr == na[2] then
          if na[1] == na[2] then
            remoteName = sprachen.Unbekannt
          else
            remoteName = na[1]
            break
          end
        end
      end
      if remoteName == "" then
        f.newAddress(nil, remAddr)
      end
    end
  end
end

function f.wurmlochRichtung()
  if direction == "Outgoing" then
    wurmloch = "out"
  end
  if wurmloch == "out" and state == "Closing" then
    direction = "Outgoing"
  end
end

function f.aktualisiereStatus()
  f.reset()
  gpu.setResolution(70, 25)
  sg = component.getPrimary("stargate")
  locAddr = f.getAddress(sg.localAddress())
  remAddr = f.getAddress(sg.remoteAddress())
  iris = f.getIrisState()
  state, chevrons, direction = sg.stargateState()
  f.Zielname()
  f.wurmlochRichtung()
  f.Iriskontrolle()
  if state == "Idle" then
    alte_modem_message = nil
    v.IDC_Anzahl = 0
    RichtungName = ""
  else
    if wurmloch == "out" then
      RichtungName = sprachen.RichtungNameAus
    else
      RichtungName = sprachen.RichtungNameEin
    end
  end
  if state == "Idle" then
    StatusName = sprachen.StatusNameUntaetig
  elseif state == "Dialling" then
    StatusName = sprachen.StatusNameWaehlend
  elseif state == "Connected" then
    StatusName = sprachen.StatusNameVerbunden
  elseif state == "Closing" then
    StatusName = sprachen.StatusNameSchliessend
  else
    StatusName = sprachen.StatusNameVerbunden
  end
  energy = sg.energyAvailable() * energymultiplicator
  zeile = 1
  if (letzteNachrichtZeit - os.time()) / sectime > 45 then
    if letzteNachricht ~= "" then
      f.zeigeNachricht("")
    end
  end
end

function f.autoclose()
  if Sicherung.autoclosetime == false then
    f.zeigeHier(xVerschiebung, zeile, "  " .. sprachen.autoSchliessungAus)
  else
    if type(Sicherung.autoclosetime) ~= "number" then
      Sicherung.autoclosetime = 60
    end
    f.zeigeHier(xVerschiebung, zeile, "  " .. sprachen.autoSchliessungAn .. Sicherung.autoclosetime .. "s")
    if (activationtime - os.time()) / sectime > Sicherung.autoclosetime and state == "Connected" and einmalBeenden then
      einmalBeenden = false
      state, chevrons, direction = sg.stargateState()
      if direction == "Outgoing" then
        sg.disconnect()
      end
    end
  end
end

function f.zeigeEnergie(eingabe)
  local zeile = eingabe or v.Energiezeile or zeile
  v.Energiezeile = zeile
  f.Farbe(Farben.Statusfarbe, Farben.Statustextfarbe)
  if energy < 1000 then
    f.zeigeHier(xVerschiebung, zeile, "  " .. sprachen.energie1 .. energytype .. sprachen.energie2, 0)
    f.SchreibInAndererFarben(xVerschiebung + unicode.len("  " .. sprachen.energie1 .. energytype .. sprachen.energie2), zeile, sprachen.keineEnergie, Farben.FehlerFarbe)
  else
    if     energy < 10000 then
      energieMenge = string.format("%.f",  energy)
    elseif energy < 10000000 then
      energieMenge = string.format("%.1f", energy / 1000) .. " k"
    elseif energy < 10000000000 then
      energieMenge = string.format("%.2f", energy / 1000000) .. " M"
    elseif energy < 10000000000000 then
      energieMenge = string.format("%.3f", energy / 1000000000) .. " G"
    elseif energy < 10000000000000000 then
      energieMenge = string.format("%.3f", energy / 1000000000000) .. " T"
    elseif energy < 10000000000000000000 then
      energieMenge = string.format("%.3f", energy / 1000000000000000) .. " P"
    elseif energy < 10000000000000000000000 then
      energieMenge = string.format("%.3f", energy / 1000000000000000000) .. " E"
    elseif energy < 10000000000000000000000000 then
      energieMenge = string.format("%.3f", energy / 1000000000000000000000) .. " Z"
    else
      energieMenge = sprachen.zuvielEnergie
    end
    f.zeigeHier(xVerschiebung, zeile, "  " .. sprachen.energie1 .. energytype .. sprachen.energie2 .. f.ErsetzePunktMitKomma(energieMenge))
  end
  if state ~= "Connected" and v.Anzeigetimer then
    event.cancel(v.Anzeigetimer)
  end
end

function f.activetime()
  if state == "Connected" then
    if activationtime == 0 then
      activationtime = os.time()
    end
    time = (activationtime - os.time()) / sectime
    if time > 0 then
      f.zeigeHier(xVerschiebung, zeile, "  " .. sprachen.zeit1 .. f.ErsetzePunktMitKomma(string.format("%.1f", time)) .. "s")
    end
  else
    f.zeigeHier(xVerschiebung, zeile, "  " .. sprachen.zeit2)
    time = 0
  end
end

function f.zeigeSteuerung()
  f.zeigeFarben()
  f.Farbe(Farben.Steuerungsfarbe, Farben.Steuerungstextfarbe)
  f.neueZeile(3)
  f.zeigeHier(xVerschiebung, zeile - 1, "")
  f.zeigeHier(xVerschiebung, zeile, "  " .. sprachen.Steuerung) f.neueZeile(1)
  f.zeigeHier(xVerschiebung, zeile, "") f.neueZeile(1)
  Taste.Koordinaten.Steuerungsanfang_Y = zeile
  Taste.Steuerunglinks[zeile] = Taste.d
  Taste.Koordinaten.d_Y = zeile
  Taste.Koordinaten.d_X = xVerschiebung
  f.zeigeHier(Taste.Koordinaten.d_X, Taste.Koordinaten.d_Y, "  D " .. sprachen.abschalten)
  Taste.Steuerungrechts[zeile] = Taste.e
  Taste.Koordinaten.e_Y = zeile
  Taste.Koordinaten.e_X = xVerschiebung + 20
  f.zeigeHier(Taste.Koordinaten.e_X, Taste.Koordinaten.e_Y, "E " .. sprachen.IDCeingabe) f.neueZeile(1)
  if iris == "Offline" then
    Sicherung.control = "Off"
  else
    Taste.Steuerunglinks[zeile] = Taste.o
    Taste.Koordinaten.o_Y = zeile
    Taste.Koordinaten.o_X = xVerschiebung
    f.zeigeHier(Taste.Koordinaten.o_X, Taste.Koordinaten.o_Y, "  O " .. sprachen.oeffneIris)
    Taste.Steuerungrechts[zeile] = Taste.c
    Taste.Koordinaten.c_Y = zeile
    Taste.Koordinaten.c_X = xVerschiebung + 20
    f.zeigeHier(Taste.Koordinaten.c_X, Taste.Koordinaten.c_Y, "C " .. sprachen.schliesseIris) f.neueZeile(1)
  end
  if seite >= -1 then
    Taste.Steuerunglinks[zeile] = Taste.Pfeil_links
    Taste.Koordinaten.Pfeil_links_Y = zeile
    Taste.Koordinaten.Pfeil_links_X = xVerschiebung
    if seite >= 1 then
      f.zeigeHier(Taste.Koordinaten.Pfeil_links_X, Taste.Koordinaten.Pfeil_links_Y, "  ← " .. sprachen.vorherigeSeite)
    elseif seite == 0 then
      f.zeigeHier(Taste.Koordinaten.Pfeil_links_X, Taste.Koordinaten.Pfeil_links_Y, "  ← " .. sprachen.SteuerungName)
    else
      f.zeigeHier(Taste.Koordinaten.Pfeil_links_X, Taste.Koordinaten.Pfeil_links_Y, "  ← " .. sprachen.logbuch)
    end
  else
    f.zeigeHier(xVerschiebung, zeile, "")
  end
  Taste.Steuerungrechts[zeile] = Taste.Pfeil_rechts
  Taste.Koordinaten.Pfeil_rechts_Y = zeile
  Taste.Koordinaten.Pfeil_rechts_X = xVerschiebung + 20
  if seite == -2 then
    f.zeigeHier(Taste.Koordinaten.Pfeil_rechts_X, Taste.Koordinaten.Pfeil_rechts_Y, "→ " .. sprachen.SteuerungName)
  elseif seite == -1 then
    f.zeigeHier(Taste.Koordinaten.Pfeil_rechts_X, Taste.Koordinaten.Pfeil_rechts_Y, "→ " .. sprachen.zeigeAdressen)
  elseif maxseiten > seite + 1 then
    f.zeigeHier(Taste.Koordinaten.Pfeil_rechts_X, Taste.Koordinaten.Pfeil_rechts_Y, "→ " .. sprachen.naechsteSeite)
  end
  Taste.Koordinaten.Steuerungsende_Y = zeile
  f.neueZeile(1)
  for i = zeile, Bildschirmhoehe - 3 do
    f.zeigeHier(xVerschiebung, i, "")
  end
end

function f.RedstoneAenderung(a, b)
  if sideNum == nil then
    f.sides()
  end
  if OC and r then
    r.setBundledOutput(sideNum, a, b)
  end
end

function f.RedstoneKontrolle()
  if RichtungName == sprachen.RichtungNameEin then
    if redstoneIncoming == true then
      f.RedstoneAenderung(Farben.red, 255)
      redstoneIncoming = false
    end
  elseif redstoneIncoming == false and state == "Idle" then
    f.RedstoneAenderung(Farben.red, 0)
    redstoneIncoming = true
  end
  if state == "Idle" then
    if redstoneState == true then
      f.RedstoneAenderung(Farben.white, 0)
      redstoneState = false
    end
  elseif redstoneState == false then
    f.RedstoneAenderung(Farben.white, 255)
    redstoneState = true
  end
  if IDCyes == true or (Sicherung.IDC == "" and state == "Connected" and direction == "Incoming" and iris == "Offline") then
    if redstoneIDC == true then
      f.RedstoneAenderung(Farben.black, 255)
      redstoneIDC = false
    end
  elseif redstoneIDC == false then
    f.RedstoneAenderung(Farben.black, 0)
    redstoneIDC = true
  end
  if state == "Connected" then
    if redstoneConnected == true then
      f.RedstoneAenderung(Farben.green, 255)
      redstoneConnected = false
    end
  elseif redstoneConnected == false then
    f.RedstoneAenderung(Farben.green, 0)
    redstoneConnected = true
  end
end

function f.Colorful_Lamp_Farben(eingabe, ausgabe)
  if alte_eingabe == eingabe then else
    if OC then
      for k in component.list("colorful_lamp") do
        component.proxy(k).setLampColor(eingabe)
        if ausgabe then
          print(sprachen.colorfulLampAusschalten .. k)
        end
      end
    elseif CC then
      for k, v in pairs(peripheral.getNames()) do
        if peripheral.getType(v) == "colorful_lamp" then
          peripheral.call(v, "setLampColor", eingabe)
        end
      end
    end
    alte_eingabe = eingabe
  end
end

function f.Colorful_Lamp_Steuerung()
  if iris == "Closed" or iris == "Closing" or LampenRot == true then
    f.Colorful_Lamp_Farben(31744) -- rot
  elseif redstoneIDC == false then
    f.Colorful_Lamp_Farben(992)   -- grün
  elseif redstoneIncoming == false then
    f.Colorful_Lamp_Farben(32256) -- orange
  elseif LampenGruen == true then
    f.Colorful_Lamp_Farben(992)   -- grün
  elseif redstoneState == true then
    f.Colorful_Lamp_Farben(32736) -- gelb
  else
    f.Colorful_Lamp_Farben(32767) -- weiß
  end
  --32767  weiß
  --32736  gelb
  --32256  orange
  --31744  rot
  --992    grün
  --0      schwarz
end

function f.zeigeStatus()
  f.aktualisiereStatus()
  f.Farbe(Farben.Statusfarbe, Farben.Statustextfarbe)
  local function ausgabe(a, b)
    f.zeigeHier(xVerschiebung, zeile, "  " .. a .. b)
    f.neueZeile(1)
  end
  ausgabe(sprachen.lokaleAdresse, locAddr)
  ausgabe(sprachen.zielAdresseName, zielAdresse)
  ausgabe(sprachen.zielName, remoteName)
  ausgabe(sprachen.statusName, StatusName)
  f.zeigeEnergie(zeile)
  f.neueZeile(1)
  ausgabe(sprachen.IrisName, f.zeichenErsetzen(iris))
  if iris == "Offline" then else
    ausgabe(sprachen.IrisSteuerung, f.zeichenErsetzen(Sicherung.control))
  end
  if IDCyes == true then
    ausgabe(sprachen.IDCakzeptiert, "")
  else
    ausgabe(sprachen.IDCname, incode)
  end
  ausgabe(sprachen.chevronName, chevrons)
  ausgabe(sprachen.richtung, RichtungName)
  f.activetime() f.neueZeile(1)
  f.autoclose()
  f.atmosphere()
  f.zeigeHier(xVerschiebung, zeile + 1, "")
  Trennlinienhoehe = zeile + 2
  f.zeigeSteuerung()
  f.RedstoneKontrolle()
  f.Colorful_Lamp_Steuerung()
end

function f.SchreibInAndererFarben(x, y, text, textfarbe, hintergrundfarbe, h)
  if text then
    local ALT_hintergrundfarbe = gpu.getBackground()
    local ALT_textfarbe = gpu.getForeground()
    f.Farbe(hintergrundfarbe, textfarbe)
    if not h then
      h = Bildschirmbreite
    end
    gpu.set(x, y, text .. string.rep(" ", h - unicode.len(text)))
    f.Farbe(ALT_hintergrundfarbe, ALT_textfarbe)
  end
  return " "
end

function f.atmosphere(...)
  if not sensor then
    if component.isAvailable("world_sensor") then
      sensor = component.getPrimary("world_sensor")
    else
      return
    end
  end
  if ... then
    if sensor then
      if sensor.hasBreathableAtmosphere() then
        return " Atmogood"
      else
        return " Atmodangerous"
      end
    end
    return
  else
    f.neueZeile(1)
    if sensor.hasBreathableAtmosphere() then
      f.zeigeHier(xVerschiebung, zeile, "  " .. sprachen.atmosphere .. sprachen.atmosphereJA)
    else
      f.zeigeHier(xVerschiebung, zeile, "  " .. sprachen.atmosphere .. sprachen.atmosphereNEIN)
    end
  end
end

function f.zeigeNachricht(inhalt, oben)
  if inhalt == nil then
    Nachrichtleer = true
  else
    Nachrichtleer = false
  end
  letzteNachricht = inhalt
  letzteNachrichtZeit = os.time()
  f.Farbe(Farben.Nachrichtfarbe, Farben.Nachrichttextfarbe)
  if VersionUpdate == true then
    f.zeigeHier(1, Bildschirmhoehe - 1, sprachen.aktualisierenGleich, Bildschirmbreite)
  elseif log and Sicherung.debug then
    f.zeigeHier(1, Bildschirmhoehe - 1, sprachen.fehlerName .. " /stargate/log", Bildschirmbreite)
  elseif seite == -2 then
    f.Legende()
    f.Farbe(Farben.Nachrichtfarbe, Farben.Nachrichttextfarbe)
  else
    f.zeigeHier(1, Bildschirmhoehe - 1, "", Bildschirmbreite)
  end
  if not Nachrichtleer then
    f.zeigeHier(1, Bildschirmhoehe, f.zeichenErsetzen(f.zeichenErsetzen(inhalt)), Bildschirmbreite + 1)
  elseif not oben then
    f.zeigeHier(1, Bildschirmhoehe, "", Bildschirmbreite)
  end
  f.Farbe(Farben.Statusfarbe)
end

function f.Legende()
  f.Farbe(Farben.Nachrichtfarbe, Farben.Nachrichttextfarbe)
  local x = 1
  f.zeigeHier(x, Bildschirmhoehe - 1, string.format("%s:  ", sprachen.Legende))
  f.Farbe(Farben.Logbuch_in, Farben.Logbuch_intext)
  x = x + unicode.len(sprachen.Legende) + 3
  f.zeigeHier(x, Bildschirmhoehe - 1, sprachen.RichtungNameEin, 0)
  f.Farbe(Farben.Logbuch_out, Farben.Logbuch_outtext)
  x = x + unicode.len(sprachen.RichtungNameEin) + 2
  f.zeigeHier(x, Bildschirmhoehe - 1, sprachen.RichtungNameAus, 0)
  f.Farbe(Farben.Logbuch_neu, Farben.Logbuch_neutext)
  x = x + unicode.len(sprachen.RichtungNameAus) + 2
  f.zeigeHier(x, Bildschirmhoehe - 1, sprachen.neueAdresse, 0)
  f.Farbe(Farben.Logbuch_update, Farben.Logbuch_updatetext)
  x = x + unicode.len(sprachen.neueAdresse) + 2
  f.zeigeHier(x, Bildschirmhoehe - 1, sprachen.LegendeUpdate, 0)
end

function f.schreibFehlerLog(...)
  if letzteEingabe == ... then else
    local d
    if fs.exists("/stargate/log") then
      d = io.open("/stargate/log", "a")
    else
      d = io.open("/stargate/log", "w")
      d:write('-- ' .. tostring(sprachen.schliessen) .. '\n')
      d:write(require("computer").getBootAddress() .. " - " .. f.getAddress(sg.localAddress()) .. '\n\n')
    end
    if type(...) == "string" then
      d:write(...)
    elseif type(...) == "table" then
      d:write(serialization.serialize(...))
    end
    d:write("\n" .. os.time() .. string.rep("-", 69 - string.len(os.time())) .. "\n")
    d:close()
    log = true
  end
  letzteEingabe = ...
end

function f.zeigeFehler(text, ...)
  if text ~= "" then
    f.schreibFehlerLog(text, ...)
    f.zeigeNachricht(string.format("%s %s", sprachen.fehlerName, tostring(text)))
  end
end

function f.dial(name, adresse)
  if state == "Idle" then
    remoteName = name
    f.zeigeNachricht(sprachen.waehlen .. "<" .. string.sub(remoteName, 1, xVerschiebung + 12) .. "> <" .. adresse .. ">")
  end
  state = "Dialling"
  wurmloch = "out"
  local ok, ergebnis = sg.dial(adresse)
  if ok == nil then
    if string.sub(ergebnis, 0, 20) == "Stargate at address " then
      local AdressEnde = string.find(string.sub(ergebnis, 21), " ") + 20
      ergebnis = string.sub(ergebnis, 0, 20) .. "<" .. f.getAddress(string.sub(ergebnis, 21, AdressEnde - 1)) .. ">" .. string.sub(ergebnis, AdressEnde)
    end
    f.zeigeNachricht(ergebnis or sprachen.anwahl_fehler)
  else
    f.Logbuch_schreiben(name , adresse, wurmloch)
  end
  os.sleep(1)
end

function o.key_down(...)
  local e = {...}
  c = string.char(e[3])
  if e[3] == 0 and e[4] == 203 then
    Taste.Pfeil_links()
  elseif e[3] == 0 and e[4] == 205 then
    Taste.Pfeil_rechts()
  elseif c >= "0" and c <= "9" and seite >= 0 then
    Taste.Zahl(c)
  else
    local d = Taste[c]
    if d then
      f.checken(d)
    end
  end
end

function f.Seite(zahl)
  seite = seite + zahl
  f.zeigeAnzeige()
end

function Taste.Pfeil_links()
  f.Farbe(Farben.Steuerungstextfarbe, Farben.Steuerungsfarbe)
  if seite >= 1 then
    f.zeigeHier(Taste.Koordinaten.Pfeil_links_X + 2, Taste.Koordinaten.Pfeil_links_Y, "← " .. sprachen.vorherigeSeite, 0)
    f.Seite(-1)
  elseif seite == 0 then
    f.zeigeHier(Taste.Koordinaten.Pfeil_links_X + 2, Taste.Koordinaten.Pfeil_links_Y, "← " .. sprachen.SteuerungName, 0)
    f.Seite(-1)
  elseif seite == -1 then
    f.zeigeHier(Taste.Koordinaten.Pfeil_links_X + 2, Taste.Koordinaten.Pfeil_links_Y, "← " .. sprachen.logbuch, 0)
    f.Seite(-1)
  end
end

function Taste.Pfeil_rechts()
  f.Farbe(Farben.Steuerungstextfarbe, Farben.Steuerungsfarbe)
  if seite == -1 then
    f.zeigeHier(Taste.Koordinaten.Pfeil_rechts_X, Taste.Koordinaten.Pfeil_rechts_Y, "→ " .. sprachen.zeigeAdressen, 0)
    f.Seite(1)
  elseif seite == -2 then
    f.zeigeHier(Taste.Koordinaten.Pfeil_rechts_X, Taste.Koordinaten.Pfeil_rechts_Y, "→ " .. sprachen.SteuerungName, 0)
    f.Seite(1)
    f.zeigeNachricht(nil, true)
  elseif seite + 1 < maxseiten then
    f.zeigeHier(Taste.Koordinaten.Pfeil_rechts_X, Taste.Koordinaten.Pfeil_rechts_Y, "→ " .. sprachen.naechsteSeite, 0)
    f.Seite(1)
  end
end

function Taste.q()
  if seite == -1 then
    f.Farbe(Farben.AdressfarbeAktiv, Farben.AdresstextfarbeAktiv)
    f.zeigeHier(1, Taste.Koordinaten.Taste_q, "Q " .. sprachen.beenden, 0)
    running = false
  end
end

function Taste.d()
  f.Farbe(Farben.Steuerungstextfarbe, Farben.Steuerungsfarbe)
  f.zeigeHier(Taste.Koordinaten.d_X + 2, Taste.Koordinaten.d_Y, "D " .. sprachen.abschalten, 0)
  sg.disconnect()
  if state == "Connected" and direction == "Incoming" then
    sg.sendMessage("Request: Disconnect Stargate")
    f.zeigeNachricht(sprachen.senden .. sprachen.aufforderung .. ": " .. sprachen.stargateAbschalten .. " " .. sprachen.stargateName)
  else
    if state == "Idle" then else
      f.zeigeNachricht(sprachen.stargateAbschalten .. " " .. sprachen.stargateName)
    end
  end
  chevronAnzeige.zeig(false, "ende")
  event.timer(2, f.zeigeMenu, 1)
end

function Taste.e()
  f.Farbe(Farben.Steuerungstextfarbe, Farben.Steuerungsfarbe)
  f.zeigeHier(Taste.Koordinaten.e_X, Taste.Koordinaten.e_Y, "E " .. sprachen.IDCeingabe, 0)
  if f.Tastatur() then
    if state == "Connected" and direction == "Outgoing" then
      term.setCursor(1, Bildschirmhoehe)
      f.Farbe(Farben.Nachrichtfarbe, Farben.Nachrichttextfarbe)
      local timerID = event.timer(1, function() f.zeigeStatus() f.Farbe(Farben.Nachrichtfarbe, Farben.Nachrichttextfarbe) end, math.huge)
      term.clearLine()
      f.eventlisten("ignore")
      term.write(sprachen.IDCeingabe .. ": ")
      pcall(screen.setTouchModeInverted, false)
      local eingabe = term.read(nil, false, nil, "*")
      pcall(screen.setTouchModeInverted, true)
      f.eventlisten("listen")
      sg.sendMessage_alt(string.sub(eingabe, 1, string.len(eingabe) - 1))
      event.cancel(timerID)
      f.zeigeNachricht(sprachen.IDCgesendet)
    else
      f.zeigeNachricht(sprachen.keineVerbindung)
    end
  end
end

function Taste.a()
  if seite == -1 then
    f.Farbe(Farben.AdressfarbeAktiv, Farben.AdresstextfarbeAktiv)
    f.zeigeHier(1, Taste.Koordinaten.Taste_a, "A " .. sprachen.Adresseingabe, 0)
    if f.Tastatur() then
      f.eventlisten("ignore")
      term.setCursor(1, Bildschirmhoehe)
      f.Farbe(Farben.Nachrichtfarbe, Farben.Nachrichttextfarbe)
      local timerID = event.timer(1, function() f.zeigeStatus() f.Farbe(Farben.Nachrichtfarbe, Farben.Nachrichttextfarbe) end, math.huge)
      pcall(screen.setTouchModeInverted, false)
      local function eingeben(text)
        term.clearLine()
        term.write(text .. ": ")
        local eingabe = term.read(nil, false)
        return string.sub(eingabe, 1, string.len(eingabe) - 1)
      end
      local adresse = string.upper(eingeben(sprachen.Eingeben_Adresse))
      if sg.energyToDial(adresse) then
        local name = eingeben(sprachen.Eingeben_Name .. adresse)
        if name == "" then
          name = ">>>" .. adresse .. "<<<"
        end
        local idc = eingeben(sprachen.Eingeben_idc .. name)
        if f.newAddress(idc, adresse, name) then
          f.zeigeNachricht(sprachen.richtige_Adresse)
        else
          f.zeigeNachricht(sprachen.falsche_Adresse)
        end
      else
        f.zeigeNachricht(sprachen.falsche_Adresse)
      end
      pcall(screen.setTouchModeInverted, true)
      f.eventlisten("listen")
      event.cancel(timerID)
    end
  end
end

function Taste.o()
  f.Farbe(Farben.Steuerungstextfarbe, Farben.Steuerungsfarbe)
  f.zeigeHier(Taste.Koordinaten.o_X + 2, Taste.Koordinaten.o_Y, "O " .. sprachen.oeffneIris, 0)
  if iris == "Offline" then else
    f.irisOpen()
    if wurmloch == "in" then
      if iris == "Offline" then else
        os.sleep(2)
        if f.atmosphere(true) then
          sg.sendMessage("Manual Override: Iris: Open" .. f.atmosphere(true))
        else
          sg.sendMessage("Manual Override: Iris: Open")
        end 
      end
    end
    if state == "Idle" then
      iriscontrol = "on"
    else
      iriscontrol = "off"
    end
  end
end

function Taste.c()
  f.Farbe(Farben.Steuerungstextfarbe, Farben.Steuerungsfarbe)
  f.zeigeHier(Taste.Koordinaten.c_X, Taste.Koordinaten.c_Y, "C " .. sprachen.schliesseIris, 0)
  if iris ~= "Offline" then
    f.irisClose()
    iriscontrol = "off"
    if wurmloch == "in" then
      if f.atmosphere(true) then
        sg.sendMessage("Manual Override: Iris: Closed" .. f.atmosphere(true))
      else
        sg.sendMessage("Manual Override: Iris: Closed")
      end 
    end
  end
end

function Taste.i()
  if seite == -1 then
    f.Farbe(Farben.AdressfarbeAktiv, Farben.AdresstextfarbeAktiv)
    f.zeigeHier(1, Taste.Koordinaten.Taste_i, "I " .. string.sub(sprachen.IrisSteuerung:match("^%s*(.-)%s*$") .. " " .. sprachen.an_aus, 1, 28), 0)
    event.timer(2, f.zeigeMenu, 1)
    if iris ~= "Offline" then
      send = true
      if Sicherung.control == "On" then
        Sicherung.control = "Off"
      else
        Sicherung.control = "On"
      end
      schreibSicherungsdatei(Sicherung)
    end
  end
end

function Taste.z()
  if seite == -1 then
    f.Farbe(Farben.AdressfarbeAktiv, Farben.AdresstextfarbeAktiv)
    f.zeigeHier(1, Taste.Koordinaten.Taste_z, "Z " .. sprachen.AdressenBearbeiten, 0)
    if f.Tastatur() then
      f.textanzeige(true)
      kopieren("/einstellungen/adressen.lua", "/einstellungen/adressen-bearbeiten")
      edit("/einstellungen/adressen-bearbeiten")
      if pcall(loadfile("/einstellungen/adressen-bearbeiten")) then
        entfernen("/einstellungen/adressen.lua")
        kopieren("/einstellungen/adressen-bearbeiten", "/einstellungen/adressen.lua")
      else
        f.zeigeNachricht("Syntax Fehler")
        os.sleep(2)
      end
      entfernen("/einstellungen/adressen-bearbeiten")
      f.textanzeige(false)
      seite = -1
      f.zeigeAnzeige()
      seite = 0
      f.AdressenSpeichern()
    else
      event.timer(2, f.zeigeMenu, 1)
    end
  end
end

function Taste.s()
  if seite == -1 then
    f.Farbe(Farben.AdressfarbeAktiv, Farben.AdresstextfarbeAktiv)
    f.zeigeHier(1, Taste.Koordinaten.Taste_s, "S " .. sprachen.EinstellungenAendern, 0)
    if f.Tastatur() then
      schreibSicherungsdatei(Sicherung)
      f.textanzeige(true)
      kopieren("/einstellungen/Sicherungsdatei.lua", "/einstellungen/Sicherungsdatei-bearbeiten")
      edit("/einstellungen/Sicherungsdatei-bearbeiten")
      if pcall(loadfile("/einstellungen/Sicherungsdatei-bearbeiten")) then
        entfernen("/einstellungen/Sicherungsdatei.lua")
        kopieren("/einstellungen/Sicherungsdatei-bearbeiten", "/einstellungen/Sicherungsdatei.lua")
      else
        f.zeigeNachricht("Syntax Fehler")
        os.sleep(2)
      end
      entfernen("/einstellungen/Sicherungsdatei-bearbeiten")
      f.textanzeige(false)
      local a = Sicherung.RF
      Sicherung = loadfile("/einstellungen/Sicherungsdatei.lua")()
      if fs.exists("/stargate/sprache/" .. Sicherung.Sprache .. ".lua") then
        local neu = loadfile("/stargate/sprache/" .. Sicherung.Sprache .. ".lua")()
        sprachen = loadfile("/stargate/sprache/deutsch.lua")()
        for i in pairs(sprachen) do
          if neu[i] then
            sprachen[i] = neu[i]
          end
        end
        sprachen = sprachen or neu
        ersetzen = loadfile("/stargate/sprache/ersetzen.lua")(sprachen)
      else
        print("\nUnbekannte Sprache\nStandardeinstellung = deutsch")
        sprachen = loadfile("/stargate/sprache/deutsch.lua")()
        ersetzen = loadfile("/stargate/sprache/ersetzen.lua")(sprachen)
        Sicherung.Sprache = ""
        os.sleep(1)
      end
      if Sicherung.RF then
        energytype          = "RF"
        energymultiplicator = 80
      else
        energytype          = "EU"
        energymultiplicator = 20
      end
      if a ~= Sicherung.RF then
        f.AdressenSpeichern()
      end
      schreibSicherungsdatei(Sicherung)
      Farben = loadfile("/stargate/farben.lua")(Sicherung.Theme, OC, CC)
      f.sides()
      gpu.setBackground(Farben.Nachrichtfarbe)
      seite = -1
      f.zeigeAnzeige()
    else
      event.timer(2, f.zeigeMenu, 1)
    end
  end
end

function Taste.l()
  if seite == -1 then
    f.Farbe(Farben.AdressfarbeAktiv, Farben.AdresstextfarbeAktiv)
    f.zeigeHier(1, Taste.Koordinaten.Taste_l, "L " .. sprachen.zeigeLog, 0)
    if f.Tastatur() then
      f.textanzeige(true)
      edit("-r", "/stargate/log")
      f.textanzeige(false)
      seite = 0
    else
      event.timer(2, f.zeigeMenu, 1)
    end
  end
end

function Taste.u()
  if seite == -1 then
    f.zeigeNachricht(sprachen.Update)
    f.Farbe(Farben.AdressfarbeAktiv, Farben.AdresstextfarbeAktiv)
    f.zeigeHier(1, Taste.Koordinaten.Taste_u, "U " .. sprachen.Update, 0)
    if component.isAvailable("internet") then
      local serverVersion = f.checkServerVersion("master")
      if version ~= serverVersion then
        if serverVersion ~= sprachen.fehlerName then
          f.Logbuch_schreiben(serverVersion, "Update:    " , "update")
          running = false
          v.update = "ja"
        else
          f.zeigeNachricht(sprachen.fehlerName)
          event.timer(2, f.zeigeMenu, 1)
        end
      else
        f.zeigeNachricht(sprachen.bereitsNeusteVersion)
        event.timer(2, f.zeigeMenu, 1)
      end
    else
      f.zeigeNachricht(sprachen.keinInternet)
      event.timer(2, f.zeigeMenu, 1)
    end
  end
end

function Taste.b()
  if seite == -1 then
    f.zeigeNachricht(sprachen.UpdateBeta)
    f.Farbe(Farben.AdressfarbeAktiv, Farben.AdresstextfarbeAktiv)
    f.zeigeHier(1, Taste.Koordinaten.Taste_b, "B " .. sprachen.UpdateBeta, 0)
    if component.isAvailable("internet") then
      f.Logbuch_schreiben(tostring(serverVersion) .. " BETA", "Update:    " , "update")
      running = false
      v.update = "beta"
    end
  end
end

function Taste.Zahl(c)
  event.timer(2, f.zeigeMenu, 1)
  f.Farbe(Farben.AdressfarbeAktiv2, Farben.AdresstextfarbeAktiv)
  if c == "0" then
    c = 10
  end
  local y = c
  c = c + seite * 10
  na = gespeicherteAdressen[tonumber(c)]
  if na then
    f.zeigeHier(1, y * 2, "", 30)
    local Nummer = y
    if y == 10 then
      Nummer = 0
    end
    f.zeigeHier(1, y * 2, Nummer .. " " .. string.sub(na[1], 1, xVerschiebung - 7), 0)
    if string.sub(na[4], 1, 1) == "<" then
      gpu.setForeground(Farben.FehlerFarbe)
      f.zeigeHier(1, y * 2 + 1, "", 30)
      f.zeigeHier(1, y * 2 + 1, "   " .. na[4], 0)
    else
      f.zeigeHier(1, y * 2 + 1, "", 30)
      f.zeigeHier(1, y * 2 + 1, "   " .. na[4], 0)
    end
    iriscontrol = "off"
    wurmloch = "out"
    if na then
      f.dial(na[1], na[2])
      if string.sub(na[4], 1, 1) == "<" and sg.energyToDial(na[2]) then
        f.AdressenSpeichern()
      end
      if na[3] == "-" then
      else
        outcode = na[3]
      end
    end
  end
end

function f.Tastatur()
  return component.isAvailable("keyboard") or f.zeigeNachricht(sprachen.TastaturFehlt)
end

function f.textanzeige(an)
  os.sleep(0.1)
  if an then
    f.eventlisten("ignore")
    screen.setTouchModeInverted(false)
    f.Farbe(Farben.Nachrichtfarbe, Farben.Textfarbe)
    gpu.setResolution(max_Bildschirmbreite, max_Bildschirmhoehe)
  else
    f.eventlisten("listen")
    screen.setTouchModeInverted(true)
    gpu.setResolution(70, 25)
  end
end

function o.sgChevronEngaged(...)
  local e = {...}
  chevron = e[3]
  local remAdr = sg.remoteAddress()
  
  if remAdr then
    if chevron <= 4 then
      zielAdresse = string.sub(remAdr, 1, chevron)
    elseif chevron <= 7 then
      zielAdresse = string.sub(remAdr, 1, 4) .. "-" .. string.sub(remAdr, 5, chevron)
    else
      zielAdresse = string.sub(remAdr, 1, 4) .. "-" .. string.sub(remAdr, 5, 7) .. "-" .. string.sub(remAdr, 8, chevron)
    end
  else
    zielAdresse = sprachen.fehlerName
  end
  
  f.zeigeNachricht(string.format("Chevron %s %s! <%s>", chevron, sprachen.aktiviert, zielAdresse))
  
  if chevron == 7 or chevron == 9 then
    for i = 0, 5 do
      if state == "Opening" or state == "Connected" then
        break
      end
      os.sleep(0.1)
      state, chevrons, direction = sg.stargateState()
    end
  end
  
  chevronAnzeige.zeig(state == "Opening" or state == "Connected", zielAdresse)
end

function o.modem_message(...)
  local e = {...}
  if e[6] and type(e[6]) == "string" and e[6] ~= "" and e[6] ~= "Adressliste" and e[6] ~= "nexDHD" and e[6] ~= alte_modem_message then
    f.check_IDC(e[6])
  end
  alte_modem_message = e[6]
end

function f.check_IDC(code)
  if v.IDC_Anzahl < 10 then
    v.IDC_Anzahl = v.IDC_Anzahl + 1
    if direction == "Incoming" and code ~= "Adressliste" then
      incode = code
      f.Iriskontrolle()
    end
  else
    sg.sendMessage(sprachen.IDC_blockiert)
  end
end

function f.openModem()
  if component.isAvailable("modem") then
    component.modem.setStrength(Sicherung.Reichweite)
    component.modem.setWakeMessage("nexDHD")
    component.modem.open(Sicherung.Port + 1)
  end
end

function o.sgMessageReceived(...)
  local e = {...}
  if direction == "Outgoing" then
    codeaccepted = e[3]
  elseif direction == "Incoming" and wurmloch == "in" then
    if e[3] == "Adressliste" then
    else
      f.check_IDC(tostring(e[3]))
    end
  end
  if e[4] == "Adressliste" then
    local inAdressen = serialization.unserialize(e[5])
    if type(inAdressen) == "table" then
      f.angekommeneAdressen(inAdressen)
    end
    if type(e[6]) == "string" then
      f.checkUpdate(e[6])
    end
  end
  messageshow = true
end

function o.touch(...)
  local e = {...}
  local x = e[3]
  local y = e[4]
  if x <= 30 then
    if seite >= 0 then
      if y > 1 and y <= 21 then
        Taste.Zahl(math.floor(((y - 1) / 2) + 0.5))
      end
    elseif seite == -1 then
      if Taste.links[y] then
        Taste.links[y](y)
      end
    end
  elseif x >= 35 and y >= Taste.Koordinaten.Steuerungsanfang_Y and y <= Taste.Koordinaten.Steuerungsende_Y then
    if x <= 52 then
      if Taste.Steuerunglinks[y] then
        Taste.Steuerunglinks[y]()
      end
    else
      if Taste.Steuerungrechts[y] then
        Taste.Steuerungrechts[y]()
      end
    end
  end
end

function o.sgDialIn()
  wurmloch = "in"
  f.Logbuch_schreiben(remoteName , f.getAddress(sg.remoteAddress()), wurmloch)
  event.timer(19, f.GDO_aufwecken, 1)
  event.timer(25, f.GDO_aufwecken, 1)
end

function f.GDO_aufwecken()
  f.openModem()
  if component.isAvailable("modem") then
    component.modem.broadcast(Sicherung.Port, "nexDHD")
  end
end

function o.sgDialOut()
  state = "Dialling"
  wurmloch = "out"
  direction = "Outgoing"
  f.GDO_aufwecken()
  event.timer(19, f.GDO_aufwecken, 1)
  event.timer(25, f.GDO_aufwecken, 1)
  event.timer(60, f.GDO_aufwecken, 1)
end

function f.eventLoop()
  local zeit = computer.uptime()

  while running do
    e = f.pull_event()

    if not e or not e[1] then
      f.zeigeAnzeige()
      zeit = computer.uptime()
    else
      local d = f[e[1]]
      if d then
        f.checken(d, e)
      end

      if computer.uptime() - zeit > 1 then
        f.zeigeAnzeige()
        zeit = computer.uptime()
      end
    end
  end
end

function f.angekommeneAdressen(eingabe)
  local AddNewAddress = false
  for a, b in pairs(eingabe) do
    local neuHinzufuegen = false
    for c, d in pairs(adressen) do
      if d[2] == "XXXX-XXX-XX" then
        adressen[c] = nil
      elseif b[2] ~= d[2] then
        neuHinzufuegen = true
      elseif b[2] == d[2] and d[1] == ">>>" .. d[2] .. "<<<" and d[1] ~= b[1] then
        if f.newAddress(nil, b[2], b[1], true) then
          adressen[c] = nil
        end
        AddNewAddress = true
        neuHinzufuegen = false
        break
      else
        neuHinzufuegen = false
        break
      end
    end
    if neuHinzufuegen == true then
      AddNewAddress = true
      f.newAddress(nil, b[2], b[1], true)
    end
  end
  if AddNewAddress == true then
    f.schreibeAdressen()
    f.AdressenSpeichern()
    f.zeigeMenu()
  end
end

function f.checkStargateName()
  Sicherung = loadfile("/einstellungen/Sicherungsdatei.lua")()
  if type(Sicherung.StargateName) ~= "string" or Sicherung.StargateName == "" then
    f.Farbe(Farben.Nachrichtfarbe, Farben.Nachrichttextfarbe)
    gpu.set(1, Bildschirmhoehe - 1, sprachen.FrageStargateName)
    term.setCursor(1, Bildschirmhoehe)
    term.clearLine()
    term.write(sprachen.neuerName .. ": ")
    pcall(screen.setTouchModeInverted, false)
    local eingabe = term.read(nil, false)
    pcall(screen.setTouchModeInverted, true)
    Sicherung.StargateName = string.sub(eingabe, 1, string.len(eingabe) - 1)
    schreibSicherungsdatei(Sicherung)
  end
  f.newAddress(nil, f.getAddress(sg.localAddress()), Sicherung.StargateName)
end

function f.checkUpdate(...)
  local AndereVersion = ... or "<FEHLER>"
  local Endpunkt = string.len(AndereVersion)
  local EndpunktVersion = string.len(version)
  if string.sub(AndereVersion, Endpunkt - 3, Endpunkt) ~= "BETA" and string.sub(version, EndpunktVersion - 3, EndpunktVersion) ~= "BETA" and version ~= AndereVersion and Sicherung.autoUpdate == true then
    if component.isAvailable("internet") then
      if version ~= f.checkServerVersion("master") then
        VersionUpdate = true
        f.zeigeNachricht(nil, true)
        event.timer(10, function() event.push("test") end, math.huge)
      end
    end
  end
end

function f.checken(...)
  ok, result = pcall(...)
  if not ok then
    local a, b, c = ...
    f.zeigeFehler(string.format("%s --- %s %s %s", result, a, b, c))
    reset = "nochmal"
    running = false
  end
end

function f.zeigeAnzeige()
  f.zeigeFarben()
  f.zeigeStatus()
  f.zeigeMenu()
end

function f.redstoneAbschalten(sideNum, Farbe, printAusgabe, text)
  r.setBundledOutput(sideNum, Farbe, 0)
  if not text then
    print(sprachen.redstoneAusschalten .. printAusgabe)
  end
end

function f.beendeAlles()
  event.cancel(Updatetimer)
  f.eventlisten("ignore")
  chevronAnzeige.beenden()
  schreibSicherungsdatei(Sicherung)
  gpu.setResolution(max_Bildschirmbreite, max_Bildschirmhoehe)
  f.Farbe(Farben.schwarzeFarbe, Farben.weisseFarbe)
  gpu.fill(1, 1, 160, 80, " ")
  term.setCursor(1, 1)
  print(sprachen.ausschaltenName .. "\n")
  f.Colorful_Lamp_Farben(0, true)
  f.RedstoneAus()
  pcall(screen.setTouchModeInverted, false)
  os.sleep(0.2)
end

function f.RedstoneAus(text)
  if component.isAvailable("redstone") and type(sideNum) == "number" and type(Farben.white) == "number" then
    r = component.getPrimary("redstone")
    local alleFarben = {"white", "yellow", "green", "red", "black"}
    for i = 1, #alleFarben do
      f.redstoneAbschalten(sideNum, Farben[alleFarben[i]], alleFarben[i], text)
    end
  end
end

function o.component_removed(eventname, id, comp)
  f.zeigeNachricht(eventname, id, comp)
  if comp == "redstone" then
    r = nil
  elseif comp == "modem" then
    f.closeModem()
  end
end

function o.component_added(eventname, id, comp)
  f.zeigeNachricht(eventname, id, comp)
  if comp == "redstone" then
    r = component.getPrimary("redstone")
  elseif comp == "modem" then
    if component.isAvailable("modem") and type(Sicherung.Port) == "number" then
      component.modem.open(Sicherung.Port + 1)
      f.openModem()
    end
  end
end

function f.eventlisten(befehl)
  for k, v in pairs(o) do
    event[befehl](k, v)
  end
end

function f.telemetrie()
  if Sicherung.cloud and component.isAvailable("internet") then
    local internet = require("internet")
    local daten = {
        typ = "nexDHD",
        version = version,
        selbst = f.getAddress(sg.localAddress()),
        extra = serialization.serialize(sendeAdressen)
    }
    f.zeigeNachricht(sprachen.cloud_arbeit)
    local inAdressen = ""
    for chunk in internet.request([==[http://s655076808.online.de/]==], daten) do
      inAdressen = inAdressen .. chunk
    end
    inAdressen = serialization.unserialize(inAdressen)
    if type(inAdressen) == "table" then
      f.angekommeneAdressen(inAdressen)
    end
    f.zeigeNachricht(sprachen.cloud_fertig)
  end
end

function f.get_GPU_Tier(gpuid)
  local gpu = component.proxy(gpuid)
  local T = 0
  for screenid in component.list("screen") do
    gpu.bind(screenid)
    local max = gpu.maxDepth()
    if max >= 8 then
      return 3
    elseif max >= 4 and T <= 2 then
      T = 2
    elseif T <= 1 then
      T = 1
    end
  end
  return T
end

function f.checkScreens()
  local gpus = {}
  local screens = {}
  for gpuid in component.list("gpu") do
    table.insert(gpus, gpuid)
  end
  for screenid in component.list("screen") do
    table.insert(screens, screenid)
  end
  if #screens > 1 and #gpus > 1 then
    local gpu_tier3 = {}
    local gpu_tier2 = {}
    local gpu_tier1 = {}
    local gpu2
    for _, gpuid in pairs(gpus) do
      local T = f.get_GPU_Tier(gpuid)
      if T == 3 then
        table.insert(gpu_tier3, gpuid)
      elseif T == 2 then
        table.insert(gpu_tier2, gpuid)
      else
        table.insert(gpu_tier1, gpuid)
      end
    end
    local primarygpu
    if #gpu_tier2 > 0 then
      primarygpu = gpu_tier2[1]
      --component.setPrimary("gpu", primarygpu)
      if gpu_tier3[1] then
        gpu2 = gpu_tier3[1]
      elseif gpu_tier2[2] then
        gpu2 = gpu_tier2[2]
      else
        gpu2 = gpu_tier1[1]
      end
    elseif #gpu_tier3 > 0 then
      primarygpu = gpu_tier3[1]
      --component.setPrimary("gpu", primarygpu)
      if gpu_tier3[2] then
        gpu2 = gpu_tier3[2]
      elseif gpu_tier2[1] then
        gpu2 = gpu_tier2[1]
      else
        gpu2 = gpu_tier1[1]
      end
    else
      f.zeigeFehler("Nur Tier 1 GPUs / Screens gefunden -> Ausschalten")
      f.beendeAlles()
      os.exit()
    end
    gpu = component.proxy(primarygpu)
    local kleine_screens = {}
    local primaryscreen
    for _, screenid in pairs(screens) do
      local x, y = component.proxy(screenid).getAspectRatio()
      if x == 4 and y == 3 then
        primaryscreen = screenid
        --component.setPrimary("screen", primaryscreen)
      elseif x == y then
        table.insert(kleine_screens, screenid)
      else
        gpu.bind(screenid)
        gpu.setResolution(34, 4)
        gpu.fill(1, 1, 34, 4, " ")
        gpu.set(1, 1, "error: wrong screen size")
        gpu.set(1, 2, string.format("current size: %sx%s", x, y))
        gpu.set(1, 3, "primary size: 4x3")
        gpu.set(1, 4, "secondary size: 1x1, 2x2, 3x3, 4x4")
      end
    end
    gpu.bind(primaryscreen)
    chevronAnzeige = loadfile("/stargate/chevron.lua")(component.proxy(gpu2), kleine_screens, gpu, primaryscreen)
  end
end

function f.main()
  f.checken(f.checkScreens)
  f.openModem()
  pcall(screen.setTouchModeInverted, true)
  if OC then
    loadfile("/bin/label.lua")("-a", require("computer").getBootAddress(), string.format("nexDHD %s", version))
  elseif CC then
    shell.run("label set nexDHD")
  end
  Updatetimer = event.timer(20000, f.checkUpdate, math.huge)
  if sg.stargateState() == "Idle" and f.getIrisState() == "Closed" then
    f.irisOpen()
  end
  gpu.setResolution(70, 25)
  f.RedstoneAus(true)
  Bildschirmbreite, Bildschirmhoehe = gpu.getResolution()
  f.zeigeFarben()
  f.zeigeStatus()
  seite = -1
  f.zeigeMenu()
  f.AdressenSpeichern()
  seite = 0
  f.zeigeMenu()
  f.telemetrie()
  f.eventlisten("listen")
  while running do
    local ergebnis, grund = pcall(f.eventLoop)
    if not ergebnis then
      print(grund)
      f.zeigeFehler(grund)
      os.sleep(5)
    end
  end
  f.beendeAlles()
end

Farben = loadfile("/stargate/farben.lua")(Sicherung.Theme, OC, CC)

f.checken(f.main)

local update = f.update
f = nil
o = nil

if v.update == "ja" or v.update == "beta" then
  print(sprachen.aktualisierenJetzt)
  print(sprachen.schliesseIris .. "...\n")
  sg.closeIris()
  if v.update == "ja" then
    pcall(update, "master", Sicherung)
  else
    pcall(update, v.update, Sicherung)
  end
  os.execute("pastebin run -f YVqKFnsP " .. v.update)
end

return reset
