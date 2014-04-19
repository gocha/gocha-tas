-- Castlevania - Order of Ecclesia
-- Ghost record script, some parts come from amaurea's script.

root_dir = ""
outprefix = root_dir.."ghost"
dumpfile = outprefix..".dump"
nomovie = false
io.output(dumpfile)

function getFrameState()
	local e = {}
	e.rframe = emu.framecount()
	e.lagcount = emu.lagcount()
	e.lagged = (emu.lagged() and 1 or 0)
	e.igframe = memory.readdword(0x02100374)
	e.mode = memory.readbyte(0x020d88d0)
	e.fade = memory.readdwordsigned(0x02100b00)
	e.region = memory.readbyte(0x020ffcb9)
	e.roomx, e.roomy = memory.readbyte(0x020ffcac), memory.readbyte(0x020ffcae)
	e.scrollx, e.scrolly = memory.readdwordsigned(0x021000bc), memory.readdwordsigned(0x021000c0)
	e.player = {
		posx = memory.readdwordsigned(0x02109850),
		posy = memory.readdwordsigned(0x02109854),
		hitx1 = memory.readwordsigned(0x02128c2e),
		hity1 = memory.readwordsigned(0x02128c30),
		hitx2 = memory.readwordsigned(0x02128c32),
		hity2 = memory.readwordsigned(0x02128c34),
		dir = memory.readbytesigned(0x02109894),
		pose = memory.readword(0x021098a4),
		albus = 0 -- reserved, for Albus Mode
	}
	return e
end

emu.registerafter(function()
	if nomovie or movie.active() then
		local e = getFrameState()
		local write = function(...)
			local arg = {...}
			local s = ""
			for i, v in ipairs(arg) do
				if i > 1 then s = s .. " " end
				s = s .. tostring(v)
			end
			io.write(s)
		end
		local ch = e.player
		write(e.rframe, e.lagcount, e.lagged, e.igframe, e.mode, e.fade, e.region, e.roomx, e.roomy, e.scrollx, e.scrolly)
		io.write(" ")
		write(ch.posx, ch.posy, ch.hitx1, ch.hity1, ch.hitx2, ch.hity2, ch.dir, ch.pose, ch.albus)
		io.write("\n")
	end
end)

emu.registerexit(function()
	io.input(io.stdout)
end)

if gui.register then
	gui.register(function()
		if not nomovie and not movie.active() then
			gui.text(12,24,"Please load the movie file now")
		end
	end)
else
	if not nomovie and not movie.active() then
		print("Please load the movie file now")
	end
end
