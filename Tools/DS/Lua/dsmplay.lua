-- Play DSM segment (desmume 0.9.5 or later)
--   * mic and reset are NOT supported.
--   * movie playback always starts from NOW, not reset or snapshot.
-- This script might help to merge an existing movie with slight timing changes.

require("dsmlib")

local kmv_path = "input.dsm"
local kmv_framecount = 1 -- 1 = first frame
local skiplagframe = true
local playback_loop = false

local kmvfile = io.open(kmv_path, "r")
if not kmvfile then
	error('could not open "'..kmv_path..'"')
end
local kmv = dsmImport(kmvfile)

function exitFunc()
	if kmvfile then
		kmvfile:close()
	end
end

-- when this function return false,
-- script will send previous input and delay to process input.
function sendThisFrame()
	return true
end

local pad_prev = joypad.get()
local pen_prev = stylus.get()
local frameAdvance = false
emu.registerbefore(function()
	if kmv_framecount > #kmv.frame then
		if not playback_loop then
			print("movie playback stopped.")
			emu.registerbefore(nil)
			emu.registerafter(nil)
			emu.registerexit(nil)
			gui.register(nil)
			exitFunc()
			return
		else
			kmv_framecount = 1
		end
	end

	local pad = pad_prev
	local pen = pen_prev
	frameAdvance = sendThisFrame()
	if frameAdvance then
		for k in pairs(pad) do
			pad[k] = kmv.frame[kmv_framecount][k]
		end
		pen.x = kmv.frame[kmv_framecount].touchX
		pen.y = kmv.frame[kmv_framecount].touchY
		pen.touch = kmv.frame[kmv_framecount].touched
	end
	joypad.set(pad)
	stylus.set(pen)
	pad_prev = copytable(pad)
	pen_prev = copytable(pen)
end)

emu.registerafter(function()
	local lagged = skiplagframe and emu.lagged()
	if frameAdvance and not lagged then
		if lagged then
			-- print(string.format("%06d", emu.framecount()))
		end
		kmv_framecount = kmv_framecount + 1
	end
end)

emu.registerexit(exitFunc)

gui.register(function()
	gui.text(0, 0, ""..(kmv_framecount-1).."/"..#kmv.frame)
end)
