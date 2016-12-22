-- Castlevania: Order of Ecclesia
-- Simple RAM Display (good for livestreaming!)

local opacityMaster = 0.68
local showStatus = true
local showHitboxes = false
local showElevatorHitboxes = true
gui.register(function()
  local frame = emu.framecount()
  local lagframe = emu.lagcount()
  local moviemode = ""

  local igframe = memory.readdword(0x02100374)
  local camx = math.floor(memory.readdwordsigned(0x021000bc) / 0x1000)
  local camy = math.floor(memory.readdwordsigned(0x021000c0) / 0x1000)
  local ch_x = memory.readdwordsigned(0x02109850)
  local ch_y = memory.readdwordsigned(0x02109854)
  local ch_vx = memory.readdwordsigned(0x0210985c)
  local ch_vy = memory.readdwordsigned(0x02109860)
  local ch_inv = memory.readbyte(0x021098e5)
  local ch_mptimer = memory.readword(0x020ffec0)
  local ch_atktimer = memory.readword(0x020ffec2)
  local hp = memory.readword(0x021002b4)
  local mp = memory.readword(0x021002b8)
  local mode = memory.readbyte(0x020d88d0)
  local fade = 1.0 -- math.min(1.0, 1.0 - math.abs(memory.readbytesigned(0x020f61fc)/16.0)) -- FIXME
	local region = memory.readbyte(0x020ffcb9)
	local room_x, room_y = memory.readbyte(0x020ffcac), memory.readbyte(0x020ffcae)

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
  if showStatus then
    gui.text(1, 26, string.format("%s\n%d", framestr, lagframe))
  end

  if mode == 0 then
    gui.opacity(opacityMaster * (fade/2 + 0.5))

    if showStatus then
      gui.text(1, 60, string.format("(%6d,%6d) %d %d %d\nHP%03d/MP%03d",
        ch_vx, ch_vy, ch_inv, ch_mptimer, ch_atktimer, hp, mp))
    end

    -- enemy info
    local basead = 0x0210d308
    local dispy = 26
    for i = 0, 63 do
      local base = basead + i * 0x160
      if memory.readword(base) > 0 then
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
        if showStatus then
          -- gui.text(189, dispy, string.format("%02X %08X", i, base))
          -- gui.text(183, dispy, string.format("%02X %4d %4d", i, en_hp, en_mp))
            gui.text(171, dispy, string.format("%X %03d %08X", i, en_hp, en_x))
          -- gui.text(123, dispy, string.format("%02X %4d %d/%02X %d/%02X %d/%02X", i, en_hp, en_dmtyp1, en_inv1, en_dmtyp2, en_inv2, en_dmtyp3, en_inv3))
          dispy = dispy + 10
        end
      end
    end

    -- enemy's hitbox
    if showHitboxes then
      for i = 0, 63 do
        local rectad = 0x02128f62 + (i * 0x14)
        local left = memory.readwordsigned(rectad+0) - camx
        local top = memory.readwordsigned(rectad+2) - camy
        local right = memory.readwordsigned(rectad+4) - camx
        local bottom = memory.readwordsigned(rectad+6) - camy
        if top >= 0 then
          gui.box(left, top, right, bottom, "clear", "#00ff00aa")
        end
      end
    end

    -- Shanoa's hitbox
    if showHitboxes then
      local left = memory.readwordsigned(0x02128c2e) - camx
      local top = memory.readwordsigned(0x02128c30) - camy
      local right = memory.readwordsigned(0x02128c32) - camx
      local bottom = memory.readwordsigned(0x02128c34) - camy
      gui.box(left, top, right, bottom, "clear", "#00ff00aa")
    end

    -- Ignis glitch related hitbox
    if showElevatorHitboxes then
      local lighthouseBossRoom = (region == 9 and room_x == 21 and room_y == 12)

      if lighthouseBossRoom then
        local elevatorIsGone = lighthouseBossRoom
 
        for i = 0, 1 do 
          local base = 0x02113fe0 + (i * 0x160) 
          if memory.readword(base) > 0 then 
            local xabs = memory.readwordsigned(base + 0xd0) 
            local yabs = memory.readwordsigned(base + 0xd2) 
            local x = xabs - camx 
            local y = yabs - camy 
            local width = memory.readwordsigned(base + 0xd4) 
            local height = memory.readwordsigned(base + 0xd6) 
            gui.box(x - (width / 2), y - (height / 2), x + (width / 2), y + (height / 2), "clear", "#ff0000cc") 

            if xabs == 0x80 and width == 0x80 and height == 0x20 then 
              elevatorIsGone = false 
              break 
            end
          end
        end

        if elevatorIsGone then
          gui.text(158, 180, "ELEVATOR IS GONE")
        end
      end
    end

    -- Glyph absorb timer
    local absorbTimerStr = ""
    for i = 0, 15 do
      local baseaddr = 0x02101000 + (i * 0x100)
      local timer = memory.readdwordsigned(baseaddr + 0x144)
      if timer > 0 and (
        memory.readdwordsigned(baseaddr + 0x38) == 0x10000 or
        memory.readdwordsigned(baseaddr + 0x60) == 0x10000 or
        memory.readdwordsigned(baseaddr + 0x88) == 0x10000 or
        memory.readdwordsigned(baseaddr + 0xb0) == 0x10000 or
        memory.readdwordsigned(baseaddr + 0xbc) == 0x10000 or
        memory.readdwordsigned(baseaddr + 0xc4) == 0x10000 or
        memory.readdwordsigned(baseaddr + 0xcc) == 0x10000 or
        memory.readdwordsigned(baseaddr + 0xd4) == 0x10000 or
        memory.readdwordsigned(baseaddr + 0xd8) == 0x10000 or
        memory.readdwordsigned(baseaddr + 0xdc) == 0x10000
      ) then
        -- absorbTimerStr = absorbTimerStr .. i .. ":"
        absorbTimerStr = absorbTimerStr .. string.format("%05X", timer) .. " "
      end
    end
    if absorbTimerStr ~= "" then
      gui.text(1, 183, "(Glyph) " .. absorbTimerStr)
    end
  end
end)
