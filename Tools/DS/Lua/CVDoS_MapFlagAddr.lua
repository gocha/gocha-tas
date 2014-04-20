-- Address view for memory writing with zipping
-- Open the memory viewer to see what's actually going on.

if not emu then
  error("This script runs under DeSmuME.")
end

if not bit then
	require("bit")
end

function cvdosPosToMapFlag(x, y)
  x, y = x % 256, y % 256

  local xl, xh = x % 16, math.floor(x / 16) % 16
  local i = (y * 16) + (xh * 46 * 16) + xl
  local pos = 0x20F6E34 + math.floor(i / 8)
  local mask = math.pow(2, math.floor(i % 8))
  return pos, mask
end

gui.register(function()
  local x = memory.readbyte(0x0210F018)
  local y = memory.readbyte(0x0210F014)
  local i = (y * 16) + x
  local pos, mask = cvdosPosToMapFlag(x, y)
  agg.text(140, 5, string.format("%08X:%02x", pos, mask))
  agg.text(140, 24, string.format("[%04X-%04X]", cvdosPosToMapFlag(x - (x % 0x10), 0) % 0x10000, cvdosPosToMapFlag(bit.bor(x, 0x0f), 255) % 0x10000))
  agg.text(140, 43, string.format("[%04X-%04X]", cvdosPosToMapFlag(x - (x % 0x10) + 0x10, 0) % 0x10000, cvdosPosToMapFlag(bit.bor(x, 0x0f) + 0x10, 255) % 0x10000))
  agg.text(140, 62, string.format("(%03d/%X,%03d)", x, x % 16, y))
end)
