-- Ganbare Goemon 3 (J) Simple Memory Display for TAS work

function number_to_bcd(n)
  return tonumber(tostring(n), 16)
end

function bcd_to_number(n)
  return tonumber(string.format("%x", n), 10)
end

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

local Goemon3SimpleHUD = {}
Goemon3SimpleHUD.__index = Goemon3SimpleHUD

-- Class(...) works as same as Class.new(...)
setmetatable(Goemon3SimpleHUD, {
  __call = function (klass, ...)
    return klass.new(...)
  end,
})

-- Storage to restore Lua variables on load state
Goemon3SimpleHUD.savestate_storage = {}

-- Callback on save state
function Goemon3SimpleHUD.onsavestate(savestate_id)
  local self = Goemon3SimpleHUD.instance()
  local lua_savestate = { players = deep_copy(self.players) }
  self.savestate_storage[savestate_id] = lua_savestate
end
event.onsavestate(Goemon3SimpleHUD.onsavestate)

-- Callback on load state
function Goemon3SimpleHUD.onloadstate(savestate_id)
  local self = Goemon3SimpleHUD.instance()
  local lua_savestate = self.savestate_storage[savestate_id]

  self.players = {}
  self:fetch()

  if lua_savestate then
    for player_index = 0, 1 do
      local player = lua_savestate.players[player_index + 1]
      self.players[player_index + 1].velocity_x = player.velocity_x
      self.players[player_index + 1].velocity_y = player.velocity_y
    end
  end

  -- Show the restored status
  print(savestate_id .. ":")
  for player_index = 0, 1 do
    local status_message = string.format("%dP:", player_index + 1)
    local player = self.players[player_index + 1]

    -- position
    status_message = status_message .. string.format(" P(%06X,%06X)", player.x, player.y)
    -- velocity
    status_message = status_message .. string.format(" V(%d,%d)", player.velocity_x, player.velocity_y)

    print(status_message)
  end
  print()
end
event.onloadstate(Goemon3SimpleHUD.onloadstate)

--- Constructor of Goemon3SimpleHUD
function Goemon3SimpleHUD.new()
  local self = setmetatable({}, Goemon3SimpleHUD)

  self.GAME_STATE_OVERWORLD = 0
  self.GAME_STATE_PLATFORM = 1
  self.GAME_STATE_CHASE = 2
  self.GAME_STATE_IMPACT_MARCH = 3
  self.GAME_STATE_IMPACT_BOSS = 4
  return self
end

-- Get instance of the singleton class
function Goemon3SimpleHUD.instance()
  if not Goemon3SimpleHUD.__instance then
    Goemon3SimpleHUD.__instance = Goemon3SimpleHUD()
  end
  return Goemon3SimpleHUD.__instance
end

--- Fetch game variables.
-- @param self Goemon3SimpleHUD object.
function Goemon3SimpleHUD:fetch()
  self.game_state = mainmemory.readbyte(0x0090)
  self.platform_screen = (mainmemory.readbyte(0x00a4) ~= 0)
  self.fade_level = math.min(mainmemory.readbyte(0x1fa0) / 15.0, 1.0)

  self.camera_x = bit.lshift(mainmemory.read_u16_le(0x1662), 8)
  self.camera_y = bit.lshift(mainmemory.read_u16_le(0x1672), 8)

  self.players = self.players or {}
  for player_index = 0, 1 do
    local base_address = 0x0400 + (player_index * 0xc0)
    local player = {}

    player.x = self.camera_x + mainmemory.read_u16_le(base_address + 0x08)
    player.y = self.camera_y + mainmemory.read_u16_le(base_address + 0x0c)
    player.z = mainmemory.read_u16_le(base_address + 0x10)
    if not self.players[player_index + 1] then
      player.velocity_x = mainmemory.read_u16_le(base_address + 0x26)
      player.velocity_y = mainmemory.read_u16_le(base_address + 0x28)
      player.velocity_z = mainmemory.read_u16_le(base_address + 0x2a)
    else
      player.velocity_x = player.x - self.players[player_index + 1].x
      player.velocity_y = player.y - self.players[player_index + 1].y
      player.velocity_z = player.z - self.players[player_index + 1].z
    end
    player.return_x = self.camera_x + bit.lshift(mainmemory.read_u16_le(base_address + 0x80), 8)
    player.return_y = self.camera_y + bit.lshift(mainmemory.read_u16_le(base_address + 0x82), 8)
    self.players[player_index + 1] = player
  end

  self.walker_jump = mainmemory.readbyte(0x042c)
end

--- Render game status to screen.
-- @param self Goemon3SimpleHUD object.
function Goemon3SimpleHUD:render_player_status()
  local hud_x, hud_y = 0, 80
  local font_height = 16

  if self.platform_screen then
    if self.game_state == self.GAME_STATE_OVERWORLD or self.game_state == self.GAME_STATE_PLATFORM then
      for player_index = 0, 1 do
        local status_message = string.format("%dP:", player_index + 1)
        local player = self.players[player_index + 1]

        -- position
        status_message = status_message .. string.format(" P(%06X,%06X)", player.x, player.y)
        -- velocity
        status_message = status_message .. string.format(" V(%d,%d)", player.velocity_x, player.velocity_y)

        gui.text(hud_x, hud_y, status_message)
        hud_y = hud_y + font_height
      end
    end
  end
end

--- Render game status to screen.
-- @param self Goemon3SimpleHUD object.
function Goemon3SimpleHUD:render()
  self:render_player_status()
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

local hud = Goemon3SimpleHUD.instance()

-- frame-based procedure
event.onframeend(function()
  hud:fetch()
  hud:render()
end)
