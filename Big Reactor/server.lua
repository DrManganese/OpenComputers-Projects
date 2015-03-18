local component = require("component")
local event = require("event")
local fs = require("filesystem")
local io = require("io")
local serialization = require("serialization")
local keyboard = component.keyboard
local port = 54598
local statusFile = "reactorStatus"

local maxFuel
local maxRF = 10^7
local maxCoreHeat = 1900
local maxCaseHeat = 1900
local running
local mode

local modem
local reactor
local capacitor = {isThere=false}
local timerID
local errors = ""

function calcCapacitorFlux()
  local tempCapacitorRF = capacitor.component.getEnergyStored(1)
  capacitor.flux =  tempCapacitorRF - capacitor.rf
  capacitor.rf = tempCapacitorRF
end

function init()
  -- Check if status file exists, if not create it
  if (not fs.exists(statusFile)) then
    local f = fs.open(statusFile, "w")
    f:write("Inactive")
    f:close()
  end

  -- Check if a br is found
  if (component.isAvailable("br_reactor")) then
    reactor = component.br_reactor
  else
    errors = errors ..  "Computer is not attached to a Reactor Computer Port\n"
  end

  -- Check if computer has (wireless) network card
  if (component.isAvailable("modem")) then
    modem = component.modem

    -- Open port if closed
    if (not modem.isOpen(port)) then modem.open(port) end
  else
    errors = errors .. "Please insert a (Wireless) Network Card"
  end

  if (component.isAvailable("capacitor_bank")) then
    capacitor.isThere = true
    capacitor.component = component.tile_blockcapacitorbank_name
    capacitor.rf = capacitor.component.getEnergyStored(1)
    capacitor.flux = 0
    capacitor.max = capacitor.component.getMaxEnergyStored(1)
    capacitorTimerID = event.timer(1, calcCapacitorFlux, math.huge)
  else

  end

  if (errors == "") then
    return true
  else
    return false
  end
end

function send (to, data)
  modem.send(to, port, serialization.serialize(data))
end

function sendInit (to)
  send(to, {action="answer", value="init", info=getMaxes()})
end

function sendData (to)
  send(to, {action="answer", value="data", info=getValues()})
end

--****REACTOR****--
function setMaxes ()
  maxFuel = reactor.getFuelAmountMax()
  running = reactor.getActive()
end

function getMaxes ()
  local maxes = {
    maxFuel = maxFuel,
    maxCoreHeat = maxCoreHeat,
    maxCaseHeat = maxCaseHeat,
    maxRF = maxRF,
    running = running
  }

  if (capacitor.isThere) then
    maxes.capacitorMax = capacitor.max
  end

  return maxes
end

function getValues()
  running = reactor.getActive()
  local values = {
    fuel = reactor.getFuelAmount(),
    coreHeat = reactor.getFuelTemperature(),
    caseHeat = reactor.getCasingTemperature(),
    RF = reactor.getEnergyStored(),
    reactivity = math.ceil(reactor.getFuelReactivity()),
    fuelFlux = math.ceil(reactor.getFuelConsumedLastTick()*1000)/1000,
    RFFlux = math.ceil(reactor.getEnergyProducedLastTick()),
    running = running
  }

  if (capacitor.isThere) then
    values.capacitor = capacitor.rf
    values.capacitorFlux = capacitor.flux
  end

  return values
end

function getMode()
  return io.input(statusFile):read()
end

function storeMode(newMode)
  if (newMode == "Active" or newMode == "Auto" or newMode == "Inactive") then
    local f = fs.open(statusFile, "w")
    f:write(newMode)
    f:close()
    mode = newMode
    return {action="answer", value="set", mode=newMode}
  else
    return false
  end
end

function manageReactor()
  local values = getValues()
  --print(getMode())
  if (values.running) then reactor.setAllControlRodLevels(math.ceil(100*values.RF/maxRF)) end

  if (mode == "Auto") then
    if (values.running and values.RF/maxRF > .99) then
      reactor.setActive(false)
    end

    if (not values.running and values.RF/maxRF < .5) then
      reactor.setActive(true)
    end
  elseif (values.running and mode == "Inactive") then
    reactor.setActive(false)
  elseif (not values.running and mode == "Active") then
    reactor.setActive(true)
  end
end

--****EVENTS****--
local eventHandlers = setmetatable({}, {__index = function() return unknownEvent end})

function eventHandlers.modem_message (to, from, port, distance, data)
  print(from.." asked for: "..data)

  data = serialization.unserialize(data)
  if (data.action == "get") then
    if (data.value == "init") then
      sendInit(from)
    elseif (data.value == "data") then
      sendData(from)
    else
      send(from, false)
    end
  elseif (data.action == "set") then
    send(from, storeMode(data.value))
  elseif (data.action == "hello") then
    send(from, {action="hello"})
  else
    send(from, false)
  end
end

function eventHandlers.key_down (_, char, _, _)
  if (char == require("string").byte("w")) then
    event.cancel(timerID)
    event.cancel(capacitorTimerID)
    modem.broadcast(port, serialization.serialize({action="goodbye"}))
    os.exit()
  end
end

function handleEvent(eventID, ...)
  if (eventID) then
    eventHandlers[eventID](...)
  end
end

function unknownEvent() end


init()
setMaxes()
mode = getMode()
timerID = event.timer(1, manageReactor, math.huge)


while true do
  handleEvent(event.pull())
end
