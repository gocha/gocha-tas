-- Castlevania - Portrait of Ruin
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
	e.igframe = memory.readdword(0x021119e0)
	e.mode = memory.readbyte(0x020f6284)
	e.fade = memory.readbytesigned(0x020f61fc)
	e.region = memory.readbyte(0x02111785)
	e.roomx, e.roomy = memory.readbyte(0x02111778), memory.readbyte(0x0211177a)
	e.scrollx, e.scrolly = memory.readdwordsigned(0x021119fc), memory.readdwordsigned(0x02111a00)
	e.jonathan = {
		posx = memory.readdwordsigned(0x020fcab0),
		posy = memory.readdwordsigned(0x020fcab4),
		hitx1 = memory.readwordsigned(0x0213296e),
		hity1 = memory.readwordsigned(0x02132970),
		hitx2 = memory.readwordsigned(0x02132972),
		hity2 = memory.readwordsigned(0x02132974),
		dir = memory.readbytesigned(0x020ff174),
		pose = memory.readword(0x020fcb04),
		blink = memory.readbyte(0x020fca9f),
		visual = memory.readbyte(0x020fcaf5)
	}
	e.charlotte = {
		posx = memory.readdwordsigned(0x020fcc10),
		posy = memory.readdwordsigned(0x020fcc14),
		hitx1 = memory.readwordsigned(0x02132982),
		hity1 = memory.readwordsigned(0x02132984),
		hitx2 = memory.readwordsigned(0x02132986),
		hity2 = memory.readwordsigned(0x02132988),
		dir = memory.readbytesigned(0x020ffdd4),
		pose = memory.readword(0x020fcc64),
		blink = memory.readbyte(0x020fcbff),
		visual = memory.readbyte(0x020fcc55)
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
		local jo, ch = e.jonathan, e.charlotte
		write(e.rframe, e.lagcount, e.lagged, e.igframe, e.mode, e.fade, e.region, e.roomx, e.roomy, e.scrollx, e.scrolly)
		io.write(" ")
		write(jo.posx, jo.posy, jo.hitx1, jo.hity1, jo.hitx2, jo.hity2, jo.dir, jo.pose, jo.blink, jo.visual)
		io.write(" ")
		write(ch.posx, ch.posy, ch.hitx1, ch.hity1, ch.hitx2, ch.hity2, ch.dir, ch.pose, ch.blink, ch.visual)
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
