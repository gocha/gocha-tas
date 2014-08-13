-- Ganbare Goemon 3 (J) Simple Memory Display for TAS work

function number_to_bcd(n)
  return tonumber(tostring(n), 16)
end

function bcd_to_number(n)
  local num = tonumber(string.format("%x", n), 10)
  return num or 0
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
  local saved_memory_domain = memory.getcurrentmemorydomain()
  memory.usememorydomain("CARTRAM")

  self.framecount = mainmemory.read_u16_le(0x0042)
  self.game_state = mainmemory.readbyte(0x0090)
  self.platform_screen = (mainmemory.readbyte(0x00a4) ~= 0)
  self.fade_level = math.min(mainmemory.readbyte(0x1fa0) / 15.0, 1.0)

  self.ingame = {}
  self.ingame.hours = bcd_to_number(memory.readbyte(0x08ef))
  self.ingame.minutes = bcd_to_number(memory.readbyte(0x08ee))
  self.ingame.seconds = memory.readbyte(0x08f1)
  self.ingame.frames = memory.readbyte(0x08f0)
  self.ingame.subseconds = (self.ingame.frames / 60)
  self.ingame.readable = ((self.ingame.hours == 0) and "" or string.format("%d:", self.ingame.hours)) ..
    string.format("%02d:%05.2f", self.ingame.minutes, self.ingame.seconds + self.ingame.subseconds)

  self.room_transition = (mainmemory.read_u16_le(0x0076) ~= 0)
  self.random = mainmemory.read_u16_le(0x0086)
  self.room = mainmemory.read_u16_le(0x008e)
  self.health = mainmemory.readbyte(0x00ba)
  self.money = bcd_to_number(mainmemory.read_u16_le(0x00be))

  self.meters_left = bcd_to_number(mainmemory.read_u16_le(0x00a2))
  self.chase_finish_cooldown = mainmemory.read_s16_le(0x1cbe)

  if self.game_state == self.GAME_STATE_CHASE or self.game_state == self.GAME_STATE_IMPACT_BOSS then
    self.camera_x = 0
    self.camera_y = 0
  else
    self.camera_x = bit.lshift(mainmemory.read_u16_le(0x1662), 8)
    self.camera_y = bit.lshift(mainmemory.read_u16_le(0x1672), 8)
  end
  self.cooldown_for_room_transition = mainmemory.readbyte(0x1c44)
  self.door_hit_status = mainmemory.read_u16_le(0x197e)

  self.players = self.players or {}
  for player_index = 0, 1 do
    local base_address = 0x0400 + (player_index * 0xc0)
    local player = {}

    player.x = self.camera_x + mainmemory.read_u16_le(base_address + 0x08)
    player.y = self.camera_y + mainmemory.read_u16_le(base_address + 0x0c)
    player.z = mainmemory.read_s16_le(base_address + 0x10)
    if not self.players[player_index + 1] then
      player.velocity_x = mainmemory.read_s16_le(base_address + 0x26) -- does not work in overworld
      player.velocity_y = mainmemory.read_s16_le(base_address + 0x28) -- does not work in overworld
      player.velocity_z = mainmemory.read_s16_le(base_address + 0x2a)
    else
      player.velocity_x = player.x - self.players[player_index + 1].x
      player.velocity_y = player.y - self.players[player_index + 1].y
      player.velocity_z = player.z - self.players[player_index + 1].z
    end
    player.return_x_relative = bit.lshift(mainmemory.read_u16_le(base_address + 0x80), 8)
    player.return_y_relative = bit.lshift(mainmemory.read_u16_le(base_address + 0x82), 8)
    player.return_x = self.camera_x + player.return_x_relative
    player.return_y = self.camera_y + player.return_y_relative

    player.cooldown_for_mermaid_rush = mainmemory.readbyte(base_address + 0x2c)
    player.invulnerable = (mainmemory.readbyte(base_address + 0x38) >= 0x80)
    player.charge_for_pushing = mainmemory.read_s16_le(base_address + 0x44)
    player.charge_for_subweapon = mainmemory.readbyte(base_address + 0x4e)
    player.cooldown_for_invulnerability = mainmemory.read_s8(base_address + 0x52)
    player.charge_for_dash = mainmemory.readbyte(base_address + 0x64)
    player.cooldown_for_transformation = mainmemory.readbyte(base_address + 0x68)
    player.charge_for_jump = mainmemory.readbyte(base_address + 0x9c)
    player.charge_for_falldown_x = mainmemory.readbyte(base_address + 0xbc)
    player.charge_for_falldown_y = mainmemory.readbyte(base_address + 0xbd)

    self.players[player_index + 1] = player
  end

  self.impact = self.impact or {}
  self.impact.kills = mainmemory.read_u16_le(0x1ca6)
  self.impact.energy_gained = mainmemory.read_u16_le(0x1ca8)
  self.impact.money_gained = mainmemory.read_u16_le(0x1caa) * 2
  self.impact.bombs_gained = math.floor(mainmemory.read_u16_le(0x1cac) / 2)
  self.impact.charge_for_koban = mainmemory.read_u16_le(0x1c40)
  self.impact.charge_for_punch = mainmemory.read_u16_le(0x1c44)
  if self.game_state == self.GAME_STATE_IMPACT_MARCH then
    self.impact.health = bcd_to_number(memory.read_u16_le(0x07ba))
  else
    self.impact.health = bcd_to_number(mainmemory.read_u16_le(0x1c48))
  end
  self.impact.enemy_health = bcd_to_number(mainmemory.read_u16_le(0x0dd0))
  self.impact.cooldown_for_code_sequence = mainmemory.read_u16_le(0x1cd0)
  if mainmemory.read_u16_le(0x1c94) ~= 0 then
    self.impact.cooldown_for_step = mainmemory.read_u16_le(0x1c90)
  else
    self.impact.cooldown_for_step = 0
  end

  self.walker_jump = mainmemory.readbyte(0x042c)

  memory.usememorydomain(saved_memory_domain)
end

--- Render game status to screen.
-- @param self Goemon3SimpleHUD object.
function Goemon3SimpleHUD:render_player_status()
  local hud_x, hud_y = 0, 80
  local font_height = 16
  local status_message

  status_message = self.ingame.readable

  if self.platform_screen then
    if self.game_state == self.GAME_STATE_OVERWORLD or self.game_state == self.GAME_STATE_PLATFORM then
      status_message = status_message .. string.format(" ROOM:%03X", self.room)
      if self.walker_jump ~= 0 then
        status_message = status_message .. string.format(" WJ:%d", self.walker_jump)
      end
      if self.cooldown_for_room_transition ~= 0 then
        status_message = status_message .. string.format(" CDOOR:%d", self.cooldown_for_room_transition)
      end
      if self.door_hit_status ~= 0 then
        status_message = status_message .. string.format(" HDOOR:%X", self.door_hit_status)
      end

      gui.text(hud_x, hud_y, status_message)
      hud_y = hud_y + font_height

      for player_index = 0, 1 do
        status_message = string.format("%dP:", player_index + 1)
        local player = self.players[player_index + 1]

        status_message = status_message .. string.format(" P(%06X,%06X)", player.x, player.y)
        status_message = status_message .. string.format(" V(%d,%d)", player.velocity_x, player.velocity_y)

        gui.text(hud_x, hud_y, status_message)
        hud_y = hud_y + font_height

        status_message = "   "
        status_message = status_message .. string.format(" R(%04X,%04X)", player.return_x_relative, player.return_y_relative)
        if player.charge_for_dash ~= 0 then
          status_message = status_message .. string.format(" D%d", player.charge_for_dash)
        end
        if player.charge_for_subweapon ~= 0 then
          status_message = status_message .. string.format(" W%d", player.charge_for_subweapon)
        end
        if player.cooldown_for_invulnerability > 0 then
          status_message = status_message .. string.format(" I%d", player.cooldown_for_invulnerability)
        end
        if player.cooldown_for_transformation ~= 0 then
          status_message = status_message .. string.format(" T%d", player.cooldown_for_transformation)
        end
        if player.charge_for_jump ~= 0 then
          status_message = status_message .. string.format(" J%d", player.charge_for_jump)
        end
        if player.cooldown_for_mermaid_rush ~= 0 then
          status_message = status_message .. string.format(" M%d", player.cooldown_for_mermaid_rush)
        end
        if player.charge_for_falldown_x ~= 0 then
          status_message = status_message .. string.format(" FX%d", player.charge_for_falldown_x)
        end
        if player.charge_for_falldown_y ~= 0 then
          status_message = status_message .. string.format(" FY%d", player.charge_for_falldown_y)
        end
        if player.charge_for_pushing ~= 0 then
          status_message = status_message .. string.format(" P%d", player.charge_for_pushing)
        end

        gui.text(hud_x, hud_y, status_message)
        hud_y = hud_y + font_height
      end
    elseif self.game_state == self.GAME_STATE_CHASE then
      local meter = self.meters_left
      if meter ~= 0 then
        meter = meter + ((3 - (self.framecount % 4)) / 4.0)
      end

      status_message = string.format(" %.2fM", meter)
      if self.chase_finish_cooldown > 0 then
        status_message = status_message .. string.format(" %d", self.chase_finish_cooldown)
      end

      gui.text(hud_x, hud_y, status_message)
      hud_y = hud_y + font_height
    elseif self.game_state == self.GAME_STATE_IMPACT_MARCH then
      status_message = string.format(" EN%d D%d", self.impact.health, math.floor(self.camera_x / 256))
      if self.impact.cooldown_for_step ~= 0 then
        status_message = status_message .. string.format(" W%d", self.impact.cooldown_for_step)
      end

      gui.text(hud_x, hud_y, status_message)
      hud_y = hud_y + font_height

      status_message = string.format("KILL%d EN+%d GOLD+%d BOMB+%d", self.impact.kills, self.impact.energy_gained, self.impact.money_gained, self.impact.bombs_gained)

      gui.text(hud_x, hud_y, status_message)
      hud_y = hud_y + font_height
    end
  else
    if self.game_state == self.GAME_STATE_IMPACT_BOSS then
      status_message = string.format(" EN%d", self.impact.health)
      if self.impact.charge_for_koban ~= 0 then
        status_message = status_message .. string.format(" K%d", self.impact.charge_for_koban)
      end
      if self.impact.charge_for_punch ~= 0 then
        status_message = status_message .. string.format(" P%d", self.impact.charge_for_punch)
      end
      if self.impact.cooldown_for_code_sequence ~= 0 then
        status_message = status_message .. string.format(" COM%d", self.impact.cooldown_for_code_sequence)
      end

      gui.text(hud_x, hud_y, status_message)
      hud_y = hud_y + font_height
    else
      gui.text(hud_x, hud_y, status_message)
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
