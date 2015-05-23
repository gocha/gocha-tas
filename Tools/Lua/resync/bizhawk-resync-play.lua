-- Snes9x to BizHawk: Playing

if not bit then
  bit = require("bit")
end

local LOGMOVIE_NAME = "doraemon2-tas.dat"

local JOYPAD_NUMS = 1
local FETCH_TARGETS = {
  -- { addr = 0x7E0059, size = "b", type = "u", desc = "Framecount (Clock)" },
  -- { addr = 0x7E00C4, size = "w", type = "u", desc = "Framecount?" },
  -- { addr = 0x7E0B44, size = "w", type = "h", desc = "X position" },
  -- { addr = 0x7E0B43, size = "b", type = "h", desc = "X subpx position" },
  -- { addr = 0x7E0B41, size = "w", type = "h", desc = "Y yosition" },
  -- { addr = 0x7E0B40, size = "b", type = "h", desc = "Y subpx position" },
  -- { addr = 0x7E0E10, size = "b", type = "u", desc = "X speed" },
  -- { addr = 0x7E0E11, size = "b", type = "u", desc = "X speed count" },
  -- { addr = 0x7E0E14, size = "b", type = "u", desc = "Y speed" },
  -- { addr = 0x7E0E15, size = "b", type = "u", desc = "Y speed count" },
  -- { addr = 0x7E0F1B, size = "b", type = "u", desc = "Ability charge" },
  -- { addr = 0x7E0B3E, size = "b", type = "u", desc = "Ability remaining time" },
  -- { addr = 0x7E0B4A, size = "b", type = "u", desc = "Invincibility" },
  -- { addr = 0x7E0E13, size = "b", type = "u", desc = "Walljump help" },
  -- { addr = 0x7E0E09, size = "b", type = "u", desc = "Ingame time (seconds)" },
  -- { addr = 0x7E0E08, size = "b", type = "u", desc = "Ingame time (frames)" },
  -- { addr = 0x7E0C65, size = "b", type = "u", desc = "Conversation state" },
  -- { addr = 0x7E0059, size = "b", type = "u", desc = "Animation counter" },
}

function joy2num(joy)
  local num = 0
  if joy.R      then num = num + 0x0010 end
  if joy.L      then num = num + 0x0020 end
  if joy.X      then num = num + 0x0040 end
  if joy.A      then num = num + 0x0080 end
  if joy.right  then num = num + 0x0100 end
  if joy.left   then num = num + 0x0200 end
  if joy.down   then num = num + 0x0400 end
  if joy.up     then num = num + 0x0800 end
  if joy.start  then num = num + 0x1000 end
  if joy.select then num = num + 0x2000 end
  if joy.Y      then num = num + 0x4000 end
  if joy.B      then num = num + 0x8000 end
  return num
end

function num2joy(num)
  local joy = {}
  joy.R      = bit.band(num, 0x0010) ~= 0
  joy.L      = bit.band(num, 0x0020) ~= 0
  joy.X      = bit.band(num, 0x0040) ~= 0
  joy.A      = bit.band(num, 0x0080) ~= 0
  joy.right  = bit.band(num, 0x0100) ~= 0
  joy.left   = bit.band(num, 0x0200) ~= 0
  joy.down   = bit.band(num, 0x0400) ~= 0
  joy.up     = bit.band(num, 0x0800) ~= 0
  joy.start  = bit.band(num, 0x1000) ~= 0
  joy.select = bit.band(num, 0x2000) ~= 0
  joy.Y      = bit.band(num, 0x4000) ~= 0
  joy.B      = bit.band(num, 0x8000) ~= 0
  return joy
end

function fetch(targets)
  local variables = {}
  for i, v in ipairs(targets) do
    local val

    local addr = v.addr
    if addr >= 0x7e0000 and addr <= 0x7fffff then
      addr = addr - 0x7e0000
    end

    if v.size == "d" then
      if v.type == "s" then
        val = memory.read_s32_le(addr)
      else
        val = memory.read_u32_le(addr)
      end
    elseif v.size == "w" then
      if v.type == "s" then
        val = memory.read_s16_le(addr)
      else
        val = memory.read_u16_le(addr)
      end
    else -- "u"
      if v.type == "s" then
        val = memory.read_s8(addr)
      else
        val = memory.read_u8(addr)
      end
    end
    variables[v.addr] = val
  end
  return variables
end

function load_logmovie(fname)
  local frames = {}
  local file = io.open(fname, "r")
  if file then
    local line = file:read()
    while line do
      local frame = {}
      local tokens = {}
      for token in string.gmatch(line, "[^\t]+") do
        table.insert(tokens, token)
      end

      frame.framecount = tonumber(tokens[1])
      frame.lagged = tokens[2] == "true"

      frame.joypads = {}
      for i = 1, JOYPAD_NUMS do
        frame.joypads[i] = num2joy(tonumber(tokens[3 + i - 1]))
      end

      frame.variables = {}
      for i = 4 + JOYPAD_NUMS - 1, #tokens do
        local delim = tokens[i]:find("=")
        local skey = tokens[i]:sub(1, delim - 1)
        local svalue = tokens[i]:sub(delim + 1)

        local addr = tonumber(skey, 16)
        local val = tonumber(svalue)
        frame.variables[addr] = val
      end

      table.insert(frames, frame)

      line = file:read()
    end

    file:close()
  end
  return frames
end

function match_vars(vars, vars_cur)
  local mismatch_addrs = {}
  for i, v in ipairs(FETCH_TARGETS) do
    if vars[v.addr] then
      if vars[v.addr] ~= vars_cur[v.addr] then
        table.insert(mismatch_addrs, v.addr)
      end
    end
  end
  return #mismatch_addrs == 0, mismatch_addrs
end

local frames = load_logmovie(LOGMOVIE_NAME)
local target_frame = 1
local previous_target_frame = 1
local fetched_vars = {}
local previous_fetched_vars = {}
local panic = false
local last_log_message = ""

-- frame-based procedure
event.onframestart(function()
  last_log_message = ""
  if movie.mode() == "RECORD" then
    fetched_vars = fetch(FETCH_TARGETS)

    local prev_panic = panic
    panic = false

    -- search target frame
    while target_frame <= #frames do
      local frame = frames[target_frame]
      if frame.lagged then
        target_frame = target_frame + 1
      else
        local matched, mismatch_addrs = match_vars(frame.variables, fetched_vars)
        if matched then
          break
        else
          if not prev_panic then
            for addri, mismatch_addr in ipairs(mismatch_addrs) do
              last_log_message = last_log_message ..
                string.format("MISMATCH Current[%d]:$%06X=%d Movie[%d]:$%06X=%d",
                emu.framecount(), mismatch_addr, fetched_vars[mismatch_addr],
                frame.framecount, mismatch_addr, frame.variables[mismatch_addr]) .. "\n"
            end
          end

          local recovered_frame
          local BACK_SEARCH_RANGE = 0
          local MAX_SEARCH_RANGE = 30
          for i = 1, math.min(MAX_SEARCH_RANGE, #frames) do
            if frame.framecount - i < 1 and frame.framecount + i > #frames then
              break
            end

            local future_frame = frame.framecount + i
            if future_frame <= #frames and not frames[future_frame].lagged then
              if match_vars(frames[future_frame].variables, fetched_vars) then
                recovered_frame = future_frame
                break
              end
            end

            if i <= BACK_SEARCH_RANGE then
              local past_frame = frame.framecount - i
              if past_frame >= 1 and not frames[past_frame].lagged then
                if match_vars(frames[past_frame].variables, fetched_vars) then
                  recovered_frame = past_frame
                  break
                end
              end
            end
          end

          if recovered_frame then
            target_frame = recovered_frame
            last_log_message = last_log_message .. 
              string.format("Seek to movie[%d] (frame %d)", target_frame, frames[target_frame].framecount) .. "\n"
          else
            -- last_log_message = last_log_message .. string.format("Unable to recover movie[%d]", target_frame) .. "\n"
            panic = true
          end

          break
        end
      end
    end

    if target_frame <= #frames then
      local frame = frames[target_frame]

      local buttons = {}
      for port = 1, JOYPAD_NUMS do
        local joy = frame.joypads[port]
        local port_prefix = string.format("P%d ", port)

        buttons[port_prefix .. "R"     ] = joy.R      and true or false
        buttons[port_prefix .. "L"     ] = joy.L      and true or false
        buttons[port_prefix .. "X"     ] = joy.X      and true or false
        buttons[port_prefix .. "A"     ] = joy.A      and true or false
        buttons[port_prefix .. "Right" ] = joy.right  and true or false
        buttons[port_prefix .. "Left"  ] = joy.left   and true or false
        buttons[port_prefix .. "Down"  ] = joy.down   and true or false
        buttons[port_prefix .. "Up"    ] = joy.up     and true or false
        buttons[port_prefix .. "Start" ] = joy.start  and true or false
        buttons[port_prefix .. "Select"] = joy.select and true or false
        buttons[port_prefix .. "Y"     ] = joy.Y      and true or false
        buttons[port_prefix .. "B"     ] = joy.B      and true or false
      end
      joypad.set(buttons)
    end
  end
end)

event.onframeend(function()
  if movie.mode() == "RECORD" then
    if not emu.islagged() then
      if last_log_message ~= "" then
        print(last_log_message)
      end

      -- input accepted, do frame advance
      previous_fetched_vars = fetched_vars
      previous_target_frame = target_frame
      target_frame = target_frame + 1
    else
      target_frame = previous_target_frame + 1
    end

    gui.drawText(0, 208, string.format("%d/%d", target_frame, #frames), panic and "red" or "white")
  end
end)
