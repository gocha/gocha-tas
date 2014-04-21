-- Castlevania: Portrait of Ruin
-- Simple RAM Display (good for livestreaming!)

local opacityMaster = 0.68
local showHitboxes = true

local instatold = {}
local enemyHUDMode = 3
gui.register(function()
	local frame = emu.framecount()
	local lagframe = emu.lagcount()
	local moviemode = ""

	local igframe = memory.readdword(0x020f703c)
	local camx = math.floor(memory.readdwordsigned(0x020f707c) / 0x1000)
	local camy = math.floor(memory.readdwordsigned(0x020f7080) / 0x1000)
	local posx = memory.readdwordsigned(0x020ca95c)
	local posy = memory.readdwordsigned(0x020ca960)
	local velx = memory.readdwordsigned(0x020ca968)
	local vely = memory.readdwordsigned(0x020ca96c)
	local inv = memory.readbyte(0x020ca9f3)
	local mptimer = memory.readword(0x020ca948)
	local hp = memory.readword(0x020f7410)
	local mp = memory.readword(0x020f7414)
	local mode = memory.readbyte(0x020c07e8)
	local fade = math.min(1.0, 1.0 - math.abs(memory.readbytesigned(0x020c0768)/16.0))

	local instat = input.get()

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
		if instat.rightclick and not instatold.rightclick then
			enemyHUDMode = enemyHUDMode + 1
			if enemyHUDMode > 5 then
				enemyHUDMode = 1
			end
		end

		gui.opacity(opacityMaster * (fade/2 + 0.5))

		gui.text(1, 60, string.format("(%6d,%6d) %d %04X\nHP%03d/MP%03d",
			velx, vely, inv, mptimer, hp, mp
		))

		-- enemy info
		local basead = 0x020d2448
		local dispy = 26
		for i = 0, 63 do
			local base = basead + i * 0x2a0
			if memory.readword(base) > 0
				and (memory.readdword(base-0x22c) ~= 0 or memory.readdword(base-0x228) ~= 0)
			then
				-- hp display
				local en_hp = memory.readword(base)
				local en_mp = memory.readword(base+2)
				local en_x = memory.readdword(base-0x22c)
				local en_y = memory.readdword(base-0x228)
				local en_vx = memory.readdwordsigned(base-0x220)
				local en_vy = memory.readdwordsigned(base-0x21c)
				local en_dmtyp1 = memory.readbyte(base-0x198)
				local en_dmtyp2 = memory.readbyte(base-0x197)
				local en_dmtyp3 = memory.readbyte(base-0x196)
				local en_inv1 = memory.readbyte(base-0x195)
				local en_inv2 = memory.readbyte(base-0x194)
				local en_inv3 = memory.readbyte(base-0x193)
				local en_msg = ""
				if enemyHUDMode == 1 then
					en_msg = string.format("%02X %08X", i, base)
				elseif enemyHUDMode == 2 then
					en_msg = string.format("%02X %4d %4d", i, en_hp, en_mp)
				elseif enemyHUDMode == 3 then
					en_msg = string.format("%X %03d %08X", i, en_hp, en_x)
				elseif enemyHUDMode == 4 then
					en_msg = string.format("%X %03d %8d", i, en_hp, en_vx)
				elseif enemyHUDMode == 5 then
					en_msg = string.format("%02X %4d %d/%02X %d/%02X %d/%02X", i, en_hp, en_dmtyp1, en_inv1, en_dmtyp2, en_inv2, en_dmtyp3, en_inv3)
				end
				gui.text(255 - (#en_msg * 6), dispy, en_msg)
				dispy = dispy + 10
			end
		end

		-- enemy's hitbox
		if showHitboxes then
			for i = 0, 63 do
				local rectad = 0x0210b2ee + (i * 0x14)
				local left = memory.readwordsigned(rectad+0) - camx
				local top = memory.readwordsigned(rectad+2) - camy
				local right = memory.readwordsigned(rectad+4) - camx
				local bottom = memory.readwordsigned(rectad+6) - camy
				if top >= 0 then
					gui.box(left, top, right, bottom, "clear", "#00ff00aa")
				end
			end
		end

		-- Soma's hitbox
		if showHitboxes then
			local left = memory.readwordsigned(0x0210af42) - camx
			local top = memory.readwordsigned(0x0210af44) - camy
			local right = memory.readwordsigned(0x0210af46) - camx
			local bottom = memory.readwordsigned(0x0210af48) - camy
			gui.box(left, top, right, bottom, "clear", "#00ff00aa")
		end
	end

	instatold = copytable(instat)
end)
