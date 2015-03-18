local component = require("component")
local event = require("event")
local keyboard = require("keyboard")
local serialization = require("serialization")
local term = require("term")

local visual = require("reactorVisual")

local modem

local getServerTimerID
local serverAdress
local port = 54598
local updateSpeed = 1

local maxRF
local maxFuel
local maxCaseHeat
local maxCoreHeat
local RF
local fuel
local caseHeat
local coreHeat
local running
local mode
local capacitor = false
local capacitorRF = 0
local capacitorMax

--****Helper functions****--
function srlz(myTable)
  return serialization.serialize(myTable)
end

function unsrlz(myString)
  return serialization.unserialize(myString)
end

function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

function send(myTable)
  modem.send(serverAdress, port, srlz(myTable))
end

function serverNotFound()
  print("Could not find a server on port "..port)
  os.exit(false)
end

function setMode(newMode)
  send({action="set", value=newMode})
end

function getMaxes()
  send({action="get", value="init"})
end

function setMaxes(info)
  maxRF = info.maxRF
  maxFuel = info.maxFuel
  maxCoreHeat = info.maxCoreHeat
  maxCaseHeat = info.maxCaseHeat
  running = info.running
  if (info.capacitorMax ~= nil) then
    capacitor = true
    capacitorMax = info.capacitorMax
    print("Capacitor found with "..capacitorMax.."RF capacity.")
    print("Initializing right-click menu")
    visual.setupRightMenu(setMode)
    visual.clear()
  end
end

function updateValues(info)
  RF = info.RF
  fuel = info.fuel
  coreHeat = info.coreHeat
  caseHeat = info.caseHeat
  running = info.running

  visual.clear()
  visual.drawBar("fuel", fuel, "mB", fuel/maxFuel)
  visual.drawBar("caseTemp", caseHeat, "°C", caseHeat/maxCaseHeat)
  visual.drawBar("fuelTemp", coreHeat, "°C", coreHeat/maxCoreHeat)
  visual.drawBar("RF", math.ceil(RF/1000), "kRF", RF/maxRF)

  if capacitor then
    capacitorRF = info.capacitor
    capacitorFlux = info.capacitorFlux
    visual.drawCapacitor(capacitorRF, capacitorMax, capacitorFlux)
  end

  local reactivity = info.reactivity
  local fuelFlux = info.fuelFlux
  local RFFlux = info.RFFlux
  visual.drawExtra(reactivity, fuelFlux, RFFlux, math.ceil(100*RF/maxRF))
  visual.drawRight(mode)
end

--**EVENTS**--
local eventHandlers = setmetatable({}, {__index = function() return unknownEvent end})

function eventHandlers.modem_message(to, from, port, distance, data)
  data = unsrlz(data)
  --LUA y u no have switch case
  local action = data.action
  local value = data.value
  if (action == "hello") then
    serverAdress = from
    event.cancel(getServerTimerID)
    print("Server "..from.." found "..(round(distance, 2)).." meters away.")
    getMaxes()
  elseif (action == "goodbye") then
    print("Server shutdown, goodbye!")
    os.exit()
  elseif (action == "answer") then
    if (value == "init") then
      setMaxes(data.info)
      os.sleep(.5)
      timerID = event.timer(updateSpeed, update, math.huge)
    elseif (value == "data") then
      updateValues(data.info)
    elseif (value == "set") then
      mode = data.mode
    end
  end
end

function eventHandlers.key_down(_, char, _, _)
  if (char == require("string").byte("w")) then
    event.cancel(getServerTimerID)
    event.cancel(timerID)
    event.ignore('touch', visual.tabletTouched)
    os.exit()
  end
end

function handleEvent(eventID, ...)
  if (eventID) then
    eventHandlers[eventID](...)
  end
end

function unknownEvent() end

-- Check if computer is setup for the program
function init()
  term.setCursor(1,2)
  -- Check if computer has (wireless) network card
  if (component.isAvailable("modem")) then
    modem = component.modem
    -- Open port if closed
    if (not modem.isOpen(port)) then modem.open(port) end
  else
    print("Please insert a (Wireless) Network Card")
    os.exit(false)
  end

  modem.broadcast(port, srlz({action="hello"}))
  print("Finding server...")
  getServerTimerID = event.timer(10, serverNotFound)
end

function update()
  send({action="get", value="data"})
  visual.drawDate()
end


visual.init()
init()

while true do
  handleEvent(event.pull())
end
