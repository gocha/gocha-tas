-- Record DSM segment (desmume 0.9.5 or later)
--   * mic and reset are NOT supported.
--   * movie record always starts from NOW, not reset or snapshot.
-- This script might help to merge an existing movie with slight timing changes.

require("dsmlib")

local kmv_path = "output.dsm"

local kmv = { frame = {}, meta = {} }
local kmv_framecount = 1

function acceptThisFrame()
	-- return true
	return not emu.lagged()
end

emu.registerafter(function()
	local pad = joypad.get()
	local pen = stylus.get()

	if acceptThisFrame() then
		kmv.frame[kmv_framecount] = {}
		for k in pairs(pad) do
			kmv.frame[kmv_framecount][k] = pad[k]
		end
		kmv.frame[kmv_framecount].touchX = pen.x
		kmv.frame[kmv_framecount].touchY = pen.y
		kmv.frame[kmv_framecount].touched = pen.touch
		kmv_framecount = kmv_framecount + 1
	end
end)

emu.registerexit(function()
	local kmvfile = io.open(kmv_path, "w")
	if kmvfile then
		dsmExport(kmv, kmvfile)
		kmvfile:close()
	end
end)

gui.register(function()
	gui.text(0, 0, ""..(kmv_framecount-1))
end)
