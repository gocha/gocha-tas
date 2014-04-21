-- Castlevania - Dawn of Sorrow
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
	e.igframe = memory.readdword(0x020f703c)
	e.mode = memory.readbyte(0x020c07e8)
	e.fade = memory.readbytesigned(0x020c0768)
	e.region = memory.readbyte(0x020f6e25)
	e.roomx, e.roomy = memory.readbyte(0x020f6e20), memory.readbyte(0x020f6e22)
	e.scrollx, e.scrolly = memory.readdwordsigned(0x020f707c), memory.readdwordsigned(0x020f7080)
	e.player = {
		posx = memory.readdwordsigned(0x020caa40),
		posy = memory.readdwordsigned(0x020caa44),
		hitx1 = memory.readwordsigned(0x0210af42),
		hity1 = memory.readwordsigned(0x0210af44),
		hitx2 = memory.readwordsigned(0x0210af46),
		hity2 = memory.readwordsigned(0x0210af48),
		dir = memory.readbytesigned(0x020ca9a0),
		pose = memory.readword(0x020ca9a4),
		who = memory.readbyte(0x020f740e)
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
		write(ch.posx, ch.posy, ch.hitx1, ch.hity1, ch.hitx2, ch.hity2, ch.dir, ch.pose, ch.who)
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
