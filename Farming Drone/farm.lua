local docking = component.proxy(component.list("dock")())
local drone = component.proxy(component.list("drone")())
local nav = component.proxy(component.list("navigation")())

local baseSleep = 5
local waypointLookRadius = 64
local colours = {["travelling"] = 0xFFFFFF, ["farming"] = 0x332400, ["waiting"] = 0x0092FF, ["dropping"] = 0x33B640}

local cx, cy, cz
local BASE
local DROPOFF
local FARMROWs

function getWaypoints()
  BASE, DROPOFF, FARMROWs = {}, {}, {}
  cx, cy, cz = 0, 0, 0
  local waypoints = nav.findWaypoints(waypointLookRadius)
  for i=1, waypoints.n do
    if waypoints[i].label == "BASE" then
      BASE.x = waypoints[i].position[1]
      BASE.y = waypoints[i].position[2]
      BASE.z = waypoints[i].position[3]
    elseif waypoints[i].label == "DROPOFF" then
      DROPOFF.x = waypoints[i].position[1]
      DROPOFF.y = waypoints[i].position[2]
      DROPOFF.z = waypoints[i].position[3]
    elseif waypoints[i].label:find("FARMROW") == 1 then
      local tempTable = {}
      tempTable.x = waypoints[i].position[1]
      tempTable.y = waypoints[i].position[2]
      tempTable.z = waypoints[i].position[3]
      tempTable.l = waypoints[i].label:match("LEN(%d+)")
      table.insert(FARMROWs, tempTable)
    end
  end
end

function colour(state)
  drone.setLightColor(colours[state] or 0x000000)
end

function move(tx, ty, tz)
  local dx = tx - cx
  local dy = ty - cy
  local dz = tz - cz
  drone.move(dx, dy, dz)
  while drone.getOffset() > 0.7 or drone.getVelocity() > 0.7 do
    computer.pullSignal(0.2)
  end
  cx, cy, cz = tx, ty, tz
end

function getCharge()
  return computer.energy()/computer.maxEnergy()
end

function waitAtBase()
    colour("travelling")
    move(BASE.x, BASE.y+1, BASE.z)
    while docking.dock()~= true do computer.pullSignal(.1) end

    colour("waiting")
    computer.pullSignal(baseSleep*#FARMROWs)
    --poké-heal sound GGGEC
    computer.beep(783.99) computer.pullSignal(.25) computer.beep(783.99) computer.pullSignal(.25) computer.beep(783.99) computer.beep(659.25) computer.beep(1046.5)
    docking.release()
end

function findCrop()
  for i=2, 5 do
    local isBlock, type = drone.detect(i)
    if type == "passable" then
      return i
    end
  end
end

function farm()
  for i=1, #FARMROWs do
    local row = FARMROWs[i]
    colour("travelling")
    move(row.x, row.y, row.z)
    colour("farming")
    local direction = findCrop()
    local l, r, tx, tz
    if direction == 2 then l,r,tx,tz = 4,5,0,-1 end
    if direction == 3 then l,r,tx,tz = 5,4,0,1 end
    if direction == 4 then l,r,tx,tz = 3,2,-1,0 end
    if direction == 5 then l,r,tx,tz = 2,3,1,0 end

    drone.use(direction)
    for i=1, row.l do
      move(cx+tx, cy, cz+tz)
      colour("farming")
      drone.use(l)
      drone.use(r)
      if i < tonumber(row.l) then
        drone.use(direction)
      end
    end
  end
end

function dropoff()
  colour("travelling")
  move(DROPOFF.x, DROPOFF.y+1, DROPOFF.z)
  while docking.dock()~= true do computer.pullSignal(.1) end
  colour("dropping")
  for i=1, drone.inventorySize() do
    docking.dropItem(i, 64)
    computer.pullSignal(1)
  end
  docking.release()
end

function init()
  getWaypoints()
  waitAtBase()
  while true do
    getWaypoints()
    farm()
    dropoff()
    waitAtBase()
  end
end

init()
