-- BizHawk MultiTrack script (beta)

local PCKeyState = require "bizhawk-pckeystate"
require "bizhawk-pretty-print"

local MultiTrackLight = {}
MultiTrackLight.__index = MultiTrackLight

-- Class(...) works as same as Class.new(...)
setmetatable(MultiTrackLight, {
  __call = function (klass, ...)
    return klass.new(...)
  end,
})

--- Constructor of MultiTrackLight
function MultiTrackLight.new()
  local self = setmetatable({}, MultiTrackLight)
  self.override_input = {}
  self.captured_inputs = {}
  self.capture_range = 900
  return self
end

--- Clear captured input.
-- @param self MultiTrackLight object.
function MultiTrackLight.clear(self)
  self.captured_inputs = {}
end

--- Capture movie frame.
-- @param self MultiTrackLight object.
-- @param start_frame Start frame of capture.
-- @param end_frame End frame of capture.
function MultiTrackLight.capture(self, ...)
  local args = {...}
  local start_frame = args[1] or (emu.framecount() - self.capture_range)
  local end_frame = args[2] or (emu.framecount() + self.capture_range)

  -- if movie is not available, do nothing.
  if movie.mode() == "INACTIVE" then
    gui.addmessage("No movie, unable to capture input.")
    return
  end

  -- check movie length.
  local last_frame = movie.length() - 1
  if last_frame < 0 then
    return
  end

  -- shift the range and make it long as far as possible.
  if start_frame < 0 then
    end_frame = math.min(end_frame - start_frame, last_frame)
    start_frame = 0
  elseif end_frame > last_frame then
    start_frame = math.max(start_frame - (end_frame - last_frame), 0)
    end_frame = last_frame
  end

  -- capture new frames.
  self.captured_inputs = {}
  for frame = start_frame, end_frame do
    self.captured_inputs[frame + 1] = movie.getinput(frame)
  end

  gui.addmessage(string.format("Captured movie frame [%d..%d].", start_frame, end_frame))
end

--- Input from existing capture.
-- @param self MultiTrackLight object.
function MultiTrackLight.input(self)
  -- movie playback should not be overridden.
  if movie.mode() == "PLAY" then
    return
  end

  -- get expected input (it should contain all key names)
  local keys = joypad.get()

  -- check if key table has a player-based field.
  local player_based = false
  for key, pressed in pairs(keys) do
    player = key:match("^P(%d) ")
    if player then
      player_based = true
      break
    end
  end

  -- override by captured input
  local frame = emu.framecount()
  if self.captured_inputs[frame + 1] then
    local captured_input = self.captured_inputs[frame + 1]
    for key, pressed in pairs(keys) do
      -- detect controller
      player = key:match("^P(%d) ")
      if player then
        player = tonumber(player)
      elseif not player_based then
        player = 1
      end

      -- toggle input if allowed
      if self.override_input[player] and captured_input[key] then
    print(tostring(frame) .. "|" .. tostring(player) .. "|" .. tostring(key) .. "|" .. tostring(not pressed))
        keys[key] = not pressed
      end
    end
  end

  -- set input back
  joypad.set(keys)
end

--- Check if input is enabled for specified player.
-- @param self MultiTrackLight object.
-- @param player Player number.
-- @return true if tracker input is enabled.
function MultiTrackLight.is_active(self, player)
  player = player or 1
  if self.override_input[player] then
    return true
  else
    return false
  end
end

--- Enable or disable input for specified player.
-- @param self MultiTrackLight object.
-- @param player Player number.
-- @param status Switch to enable/disable input. (true of false)
function MultiTrackLight.active(self, player, status)
  player = player or 1
  self.override_input[player] = status
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

local pckey = PCKeyState()
local multi_track = MultiTrackLight()

function toggle_track_input(player)
  local status = not multi_track:is_active(player)
  multi_track:active(player, status)
  gui.addmessage(string.format("%s track input for controller %d.", status and "Enabled" or "Disabled", player))
end

-- hotkey definitions
local hotkeys = {
  { name = "Capture Movie Input", key = "AT", modifiers = { control = true, shift = true }, callback = function() multi_track:capture() end },
  { name = "Toggle Track Input #1", key = "D1", modifiers = { control = true, shift = true }, callback = function() toggle_track_input(1) end },
  { name = "Toggle Track Input #2", key = "D2", modifiers = { control = true, shift = true }, callback = function() toggle_track_input(2) end },
  { name = "Toggle Track Input #3", key = "D3", modifiers = { control = true, shift = true }, callback = function() toggle_track_input(3) end },
  { name = "Toggle Track Input #4", key = "D4", modifiers = { control = true, shift = true }, callback = function() toggle_track_input(4) end },
}

-- register hotkeys
for i, hotkey in ipairs(hotkeys) do
  pckey:onhotkey(hotkey.key, hotkey.modifiers, hotkey.callback)
end

-- frame-based procedure
event.onframestart(function()
  multi_track:input()
end)

-- handle messages
local tick = 0
while true do
  -- process hotkeys
  if tick % 4 == 0 then
    pckey:update()
  end

  -- handle window messages
  emu.yield()
  tick = tick + 1
end
