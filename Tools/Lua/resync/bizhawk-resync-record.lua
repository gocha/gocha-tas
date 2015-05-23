-- Snes9x to BizHawk: Recording

if not bit then
  bit = require("bit")
end

local JOYPAD_NUMS = 1
local FETCH_TARGETS = {
  { addr = 0x7E0059, size = "b", type = "u", desc = "Framecount (Clock)" },
  { addr = 0x7E00C4, size = "w", type = "u", desc = "Framecount?" },
  { addr = 0x7E0B44, size = "w", type = "h", desc = "X position" },
  { addr = 0x7E0B43, size = "b", type = "h", desc = "X subpx position" },
  { addr = 0x7E0B41, size = "w", type = "h", desc = "Y yosition" },
  { addr = 0x7E0B40, size = "b", type = "h", desc = "Y subpx position" },
  { addr = 0x7E0E10, size = "b", type = "u", desc = "X speed" },
  { addr = 0x7E0E11, size = "b", type = "u", desc = "X speed count" },
  { addr = 0x7E0E14, size = "b", type = "u", desc = "Y speed" },
  { addr = 0x7E0E15, size = "b", type = "u", desc = "Y speed count" },
  { addr = 0x7E0F1B, size = "b", type = "u", desc = "Ability charge" },
  { addr = 0x7E0B3E, size = "b", type = "u", desc = "Ability remaining time" },
  { addr = 0x7E0B4A, size = "b", type = "u", desc = "Invincibility" },
  { addr = 0x7E0E13, size = "b", type = "u", desc = "Walljump help" },
  { addr = 0x7E0E09, size = "b", type = "u", desc = "Ingame time (seconds)" },
  { addr = 0x7E0E08, size = "b", type = "u", desc = "Ingame time (frames)" },
  { addr = 0x7E0C65, size = "b", type = "u", desc = "Conversation state" },
  { addr = 0x7E0059, size = "b", type = "u", desc = "Animation counter" },
}

local frames = {}
local movie_active = false

function joy2num(joy)
  local num = 0
  if joy.R      then num = num + 0x0010 end
  if joy.L      then num = num + 0x0020 end
  if joy.X      then num = num + 0x0040 end
  if joy.A      then num = num + 0x0080 end
  if joy.right  then num = num + 0x0100 end
  if joy.left   then num = num + 0x0200 end
  if joy.down   then num = num + 0x0400 end
  if joy.up     then num = num + 0x0800 end
  if joy.start  then num = num + 0x1000 end
  if joy.select then num = num + 0x2000 end
  if joy.Y      then num = num + 0x4000 end
  if joy.B      then num = num + 0x8000 end
  return num
end

function num2joy(num)
  local joy = {}
  joy.R      = bit.band(num, 0x0010) ~= 0
  joy.L      = bit.band(num, 0x0020) ~= 0
  joy.X      = bit.band(num, 0x0040) ~= 0
  joy.A      = bit.band(num, 0x0080) ~= 0
  joy.right  = bit.band(num, 0x0100) ~= 0
  joy.left   = bit.band(num, 0x0200) ~= 0
  joy.down   = bit.band(num, 0x0400) ~= 0
  joy.up     = bit.band(num, 0x0800) ~= 0
  joy.start  = bit.band(num, 0x1000) ~= 0
  joy.select = bit.band(num, 0x2000) ~= 0
  joy.Y      = bit.band(num, 0x4000) ~= 0
  joy.B      = bit.band(num, 0x8000) ~= 0
  return joy
end

function fetch(targets)
  local variables = {}
  for i, v in ipairs(targets) do
    local val
    if v.size == "d" then
      if v.type == "s" then
        val = memory.readdwordsigned(v.addr)
      else
        val = memory.readdword(v.addr)
      end
    elseif v.size == "w" then
      if v.type == "s" then
        val = memory.readwordsigned(v.addr)
      else
        val = memory.readword(v.addr)
      end
    else -- "u"
      if v.type == "s" then
        val = memory.readbytesigned(v.addr)
      else
        val = memory.readbyte(v.addr)
      end
    end
    variables[v.addr] = val
  end
  return variables
end

function save_logmovie(fname, frames)
  local file = io.open(fname, "w")
  if file then
    for i, frame in ipairs(frames) do
      -- write framecount
      file:write(string.format("%d", frame.framecount))
      -- write lagged
      file:write(string.format("\t%s", frame.lagged and "true" or "false"))
      -- write joypads
      for port, joy in ipairs(frame.joypads) do
        file:write(string.format("\t0x%04X", joy2num(joy)))
      end
      -- write variables
      for i, v in ipairs(FETCH_TARGETS) do
        local val = frame.variables[v.addr]
        local sval
        if v.type == "h" then
          sval = string.format("0x%X", val)
        elseif v.type == "s" then
          sval = string.format("%d", val)
        else -- "u"
          sval = string.format("%u", val)
        end
        file:write(string.format("\t%06X=%s", v.addr, sval))
      end
      file:write("\n")
    end
    file:close()
  end
end

local last_fetch_result = {}
emu.registerbefore(function()
  movie_active = movie.active()
  last_fetch_result = fetch(FETCH_TARGETS)
end)

emu.registerafter(function()
  if movie_active then
    local frame = {}
    frame.framecount = emu.framecount()
    frame.lagged = emu.lagged()
    frame.joypads = {}
    for port = 1, JOYPAD_NUMS do
      frame.joypads[port] = joypad.get(port)
    end
    frame.variables = last_fetch_result
    table.insert(frames, frame)
  end
end)

emu.registerexit(function()
  local fname = os.date("s2b-%Y%m%d%H%M%S.dat")
  save_logmovie(fname, frames)
end)
