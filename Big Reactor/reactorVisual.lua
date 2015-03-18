local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local unicode = require("unicode")
local gpu = component.gpu

local touchAreas = {}
local w, h = gpu.getResolution()
local rightMenuActive = false
local rightX
local rightY

local bgColour = gpu.setPaletteColor(1, 0xEEEEEE)
local myGray = 0x222222
local barLRPadding = 1
local barWidth = 8
local barHeight = h - 5
local barColour = gpu.setPaletteColor(2, 0x3AAC93)
local rMenuColour = gpu.setPaletteColor(3, 0x111111)

local bars = {
  fuel = {
    pos = 0,
    name = "Fuel"
  },
  fuelTemp = {
    pos = 1,
    name = "Fuel Temp."
  },
  caseTemp = {
    pos = 2,
    name = "Case Temp."
  },
  RF = {
    pos = 3,
    name = "RF"
  }
}

local publicFunctions = {}

function center(width, textWidth)
  return math.floor((width-textWidth)/2)
end

function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

function publicFunctions.clear()
  gpu.setBackground(bgColour)
  gpu.fill(1, 2, w, h, " ")
end

function unregisterMenu()
  rightMenuActive = false
  for k,v in pairs(touchAreas) do
    if (v.xMin == rightX+1) then
      touchAreas[k] = nil
    end
  end
end

function drawRightMenu(func, x, y)
  publicFunctions.drawButton(x+1, y,   9, 1, nil, nil, function() func("Active") unregisterMenu() end, true)
  publicFunctions.drawButton(x+1, y+1, 9, 1, nil, nil, function() func("Auto") unregisterMenu() end, true)
  publicFunctions.drawButton(x+1, y+2, 9, 1, nil, nil, function() func("Inactive") unregisterMenu() end, true)
  rightX = x
  rightY = y
end

function publicFunctions.drawRight(mode)
  if (rightMenuActive) then
    gpu.setBackground(rMenuColour)
    gpu.setForeground(0xFFFFFF)
    gpu.fill(rightX, rightY, 10, 3, " ")
    gpu.set(rightX+1, rightY, "Active")
    gpu.set(rightX+1, rightY+1, "Auto")
    gpu.set(rightX+1, rightY+2, "Inactive")
    gpu.setBackground(barColour)
    gpu.set(rightX, rightY + ((mode == "Active") and 0 or (mode == "Auto") and 1 or 2), " ")
  end
end

function publicFunctions.setupRightMenu(func)
  publicFunctions.drawButton(1, 2, w, h-1, nil, nil, function (button, x, y)
    if (button == 1) then
      rightMenuActive = true
      drawRightMenu(func, x, y)
    else
      rightMenuActive = false
    end
  end, false)
end

function publicFunctions.drawButton(x, y, width, height, text, colour, action, first)
  if (colour ~= nil) then
    gpu.setBackground(colour)
    gpu.fill(x, y, width, height, " ")
  end
  if (text ~= nil) then
    gpu.set(x+math.floor((math.abs(unicode.len(text)-width)/2)), y+math.floor(height/2), text)
  end
  if (first) then
    table.insert(touchAreas, 1, {func=function(button, x, y) action(button, x, y) end, xMin=x, xMax=x+width, yMin=y, yMax=y+height-1})
  else
    table.insert(touchAreas, {func=function(button, x, y) action(button, x, y) end, xMin=x, xMax=x+width, yMin=y, yMax=y+height-1})
  end
  gpu.setBackground(bgColour)
end

function publicFunctions.drawDate()
  local date = os.date("%d/%m/%Y %H:%M")
  gpu.setBackground(0)
  gpu.setForeground(0xFFFFFF)
  gpu.set(w-unicode.len(date), 1, date)
  gpu.setBackground(bgColour)
  gpu.setForeground(myGray)
end

function drawTopBar()
  local versionText = "Reactor Control v1.0 by mathiasNotDJ"
  gpu.setBackground(0)
  gpu.fill(1, 1, w, 1, " ")
  gpu.set(math.floor((w-unicode.len(versionText))/2), 1, versionText)
  publicFunctions.drawDate()
  publicFunctions.drawButton(1+barLRPadding, 1, 1, 1, "X", 0xFF0000, function () computer.shutdown() end, false)
end

function drawControls(mode)
  local activeColour   = (mode == "Active")   and 0 or 0
  local autoColour     = (mode == "Auto")     and 0 or 0
  local inactiveColour = (mode == "Inactive") and 0 or 0
end

function publicFunctions.drawBar(type, amount, suffix, pct)
  local pos = bars[type].pos
  local xMin = barLRPadding+barWidth*pos+3+pos*4
  local barPctHeight = math.ceil(barHeight*pct)
  amount = tostring(round(amount))..suffix

  local spacing = math.floor((barWidth-unicode.len(amount))/2)
  for i=1, spacing do amount = " "..amount end

  gpu.setBackground(myGray)
  gpu.fill(xMin, 5, barWidth, barHeight, " ")

  gpu.setBackground(barColour)
  gpu.fill(xMin, 5+barHeight-barPctHeight, barWidth, barPctHeight, " ")
  if (barPctHeight > 0) then
    gpu.setForeground(myGray)
    gpu.set(xMin, 5+barHeight-barPctHeight, amount)
  end

  gpu.setBackground(bgColour) gpu.setForeground(barColour)
  gpu.set(2 + math.floor(xMin + 2 - unicode.len(bars[type].name)/2), 3, bars[type].name)
  gpu.setForeground(myGray)
end

function publicFunctions.drawCapacitor(capacity, maxCapacity, flux)
  capacity = math.ceil(capacity/1000)
  maxCapacity = math.ceil(maxCapacity/1000)
  local fluxChar = (flux == 0) and "↨" or (flux > 0) and "↑" or "↓"

  gpu.setBackground(barColour)
  gpu.setForeground(0xFFFFFF)
  gpu.fill(w-28, 5, 28, 6, " ")
  gpu.set(w-28+center(28, unicode.len("Capacitor Bank")), 5, "Capacitor Bank")
  gpu.set(w-28+center(28, unicode.len("Storage: ")+4), 7, "Storage: "..math.ceil(capacity/maxCapacity*100).."%")
  gpu.set(w-28+center(28, unicode.len(tostring(capacity)..tostring(maxCapacity))+9), 8,capacity.." kRF/"..maxCapacity.." kRF")
  gpu.set(w-28+center(28, unicode.len(flux)+7), 10, fluxChar.." "..math.ceil(math.abs(flux)/20).." RF/t")
end

function publicFunctions.drawExtra(reactivity, fuelFlux, RFFlux, rods)
  gpu.setBackground(barColour)
  gpu.setForeground(0xFFFFFF)
  gpu.fill(w-28, 14, 28, 11, " ")
  gpu.set(w-28+center(28, unicode.len("Reactivity")),           14, "Reactivity")
  gpu.set(w-28+center(28, unicode.len(tostring(reactivity))+1), 15, reactivity.."%")
  gpu.set(w-28+center(28, unicode.len("Fuel Usage")),           17, "Fuel Usage")
  gpu.set(w-28+center(28, unicode.len(tostring(fuelFlux))+5),   18, fuelFlux.." mB/t")
  gpu.set(w-28+center(28, unicode.len("Energy Production")),    20, "Energy Production")
  gpu.set(w-28+center(28, unicode.len(tostring(RFFlux))+5),     21, RFFlux.." RF/t")
  gpu.set(w-28+center(28, unicode.len("Rod Insertion")),        23, "Rod Insertion")
  gpu.set(w-28+center(28, unicode.len(tostring(rods))+1),       24, rods.."%")
end

function publicFunctions.tabletTouched (_, _, x, y, button, playerName)
  for k,v in pairs(touchAreas) do
    if (x >= v.xMin and x <= v.xMax and y >= v.yMin and y <= v.yMax) then
      v.func(button, x, y)
      break
    end
  end
end

function publicFunctions.init()
  publicFunctions.clear()
  drawTopBar()
  gpu.setForeground(myGray)
  term.setCursor(1, 2)
  event.listen('touch', publicFunctions.tabletTouched)
end

return publicFunctions
