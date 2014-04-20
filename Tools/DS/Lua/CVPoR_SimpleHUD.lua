-- Castlevania: Portrait of Ruin
-- Simple RAM Display (good for livestreaming!)

local opacityMaster = 0.68
local showHitboxes = true
gui.register(function()
	local frame = emu.framecount()
	local lagframe = emu.lagcount()
	local moviemode = ""

	local igframe = memory.readdword(0x021119e0)
	local camx = math.floor(memory.readdwordsigned(0x02111a08) / 0x1000)
	local camy = math.floor(memory.readdwordsigned(0x02111a0c) / 0x1000)
	local jo_visible = memory.readbyte(0x020fcaf5)<0x80
	local jo_x = memory.readdwordsigned(0x020fcab0)
	local jo_y = memory.readdwordsigned(0x020fcab4)
	local jo_vx = memory.readdwordsigned(0x020fcabc)
	local jo_vy = memory.readdwordsigned(0x020fcac0)
	local jo_inv = memory.readbyte(0x020fcb45)
	local jo_mptimer = memory.readword(0x020fca98)
	local ch_visible = memory.readbyte(0x020fcc55)<0x80
	local ch_x = memory.readdwordsigned(0x020fcc10)
	local ch_y = memory.readdwordsigned(0x020fcc14)
	local ch_vx = memory.readdwordsigned(0x020fcc1c)
	local ch_vy = memory.readdwordsigned(0x020fcc20)
	local ch_inv = memory.readbyte(0x020fcca5)
	local ch_mptimer = memory.readword(0x020fcbf8)
	local hp = memory.readword(0x0211216c)
	local mp = memory.readword(0x02112170)
	local change_cooldown = memory.readdwordsigned(0x021115fc)
	local mode = memory.readbyte(0x020f6284)
	local fade = math.min(1.0, 1.0 - math.abs(memory.readbytesigned(0x020f61fc)/16.0))

	moviemode = movie.mode()
	if not movie.active() then moviemode = "no movie" end

	local framestr = ""
	if movie.active() and not movie.recording() then
		framestr = string.format("%d/%d", frame, movie.length())
	else
		framestr = string.format("%d", frame)
	end
	framestr = framestr .. (moviemode ~= "" and string.format(" (%s)", moviemode) or "")

	gui.opacity(opacityMaster)
	gui.text(1, 26, string.format("%s\n%d", framestr, lagframe))

	if mode == 2 then
		gui.opacity(opacityMaster * (fade/2 + 0.5))

		gui.text(1, 60, string.format("J(%6d,%6d) %d %04X\nC(%6d,%6d) %d %04X\nHP%03d/MP%03d | %d",
			jo_vx, jo_vy, jo_inv, jo_mptimer,
			ch_vx, ch_vy, ch_inv, ch_mptimer,
			hp, mp, change_cooldown
		))

		-- enemy info
		local basead = 0x02100988
		local dispy = 26
		for i = 0, 63 do
			local base = basead + i * 0x160
			if memory.readword(base) > 0 and memory.readbyte(base-8) ~= 0 then
				-- hp display
				local en_hp = memory.readword(base)
				local en_mp = memory.readword(base+2)
				local en_x = memory.readdword(base-0xf8)
				local en_dmtyp1 = memory.readbyte(base-0x66)
				local en_dmtyp2 = memory.readbyte(base-0x65)
				local en_dmtyp3 = memory.readbyte(base-0x64)
				local en_inv1 = memory.readbyte(base-0x63)
				local en_inv2 = memory.readbyte(base-0x62)
				local en_inv3 = memory.readbyte(base-0x61)
				-- gui.text(189, dispy, string.format("%02X %08X", i, base))
				-- gui.text(183, dispy, string.format("%02X %4d %4d", i, en_hp, en_mp))
				gui.text(171, dispy, string.format("%X %03d %08X", i, en_hp, en_x))
				-- gui.text(123, dispy, string.format("%02X %4d %d/%02X %d/%02X %d/%02X", i, en_hp, en_dmtyp1, en_inv1, en_dmtyp2, en_inv2, en_dmtyp3, en_inv3))
				dispy = dispy + 10
			end
		end

		-- enemy's hitbox
		if showHitboxes then
			for i = 0, 63 do
				local rectad = 0x02132cf2 + (i * 0x14)
				local left = memory.readwordsigned(rectad+0) - camx
				local top = memory.readwordsigned(rectad+2) - camy
				local right = memory.readwordsigned(rectad+4) - camx
				local bottom = memory.readwordsigned(rectad+6) - camy
				if top >= 0 then
					gui.box(left, top, right, bottom, "clear", "#00ff00aa")
				end
			end
		end
		-- Jonathan's hitbox
		if showHitboxes and jo_visible then
			local left = memory.readwordsigned(0x0213296e) - camx
			local top = memory.readwordsigned(0x02132970) - camy
			local right = memory.readwordsigned(0x02132972) - camx
			local bottom = memory.readwordsigned(0x02132974) - camy
			gui.box(left, top, right, bottom, "clear", "#00ffffaa")
		end
		-- Charlotte's hitbox
		if showHitboxes and ch_visible then
			local left = memory.readwordsigned(0x02132982) - camx
			local top = memory.readwordsigned(0x02132984) - camy
			local right = memory.readwordsigned(0x02132986) - camx
			local bottom = memory.readwordsigned(0x02132988) - camy
			gui.box(left, top, right, bottom, "clear", "#ff0000aa")
		end
	end
end)
