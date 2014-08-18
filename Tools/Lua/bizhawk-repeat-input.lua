-- BizHawk: Repeat recent movie input.

local input_pattern = {}

-- Edit pattern length (in frames) as you like
input_pattern.length = 14

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function shallow_copy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in pairs(orig) do
      copy[orig_key] = orig_value
    end
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

function deep_copy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
        copy[deep_copy(orig_key)] = deep_copy(orig_value)
    end
    setmetatable(copy, deep_copy(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

-- Movie loaded?
if movie.mode() == "INACTIVE" then
  gui.addmessage("Unable to capture movie input.")
  print("No movie.")
  return
end

-- Determine frame #
input_pattern.last_frame = emu.framecount() - 1
input_pattern.first_frame = input_pattern.last_frame - input_pattern.length + 1

-- Validate frame #
if input_pattern.first_frame < 0 or input_pattern.last_frame >= movie.length() then
  gui.addmessage("Unable to capture movie input.")
  print(string.format("Invalid frames [%d...%d]", input_pattern.first_frame, input_pattern.last_frame))
  return
end

-- Remember movie input
input_pattern.buttons = {}
for pattern_frame = 0, input_pattern.length - 1 do
  input_pattern.buttons[pattern_frame + 1] = movie.getinput(input_pattern.first_frame + pattern_frame)
end

-- Show notification message
gui.addmessage(string.format("Start repeating input [%d...%d]", input_pattern.first_frame, input_pattern.last_frame))

-- Inject the pattern input
while true do
  local movie_mode = movie.mode()
  if movie_mode ~= "PLAY" then
    local current_frame = emu.framecount()
    local pattern_frame

    -- Determine the pattern frame #
    pattern_frame = current_frame - input_pattern.first_frame
    if pattern_frame >= 0 then
      pattern_frame = pattern_frame % input_pattern.length
    else
      pattern_frame = input_pattern.length - (-pattern_frame % input_pattern.length)
    end

    joypad.set(input_pattern.buttons[pattern_frame + 1])
  end
  emu.frameadvance()
end
