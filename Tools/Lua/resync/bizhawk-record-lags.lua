-- BizHawk Lua: record lag frames into a file

local fname = os.date("lag-%Y%m%d%H%M%S.dat")
local file = io.open(fname, "w")
if not file then
  error("file open error.")
end

event.onframeend(function()
  if emu.islagged() then
    file:write(string.format("%d\n", emu.framecount()))
  end
end)

event.onexit(function()
  if file then
    -- event.onexit often runs unexpectedly?
    -- please close the emulator when you want to finish recording
    -- file:close()
  end
end)
