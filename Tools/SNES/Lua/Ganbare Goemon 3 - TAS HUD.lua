-- Ganbare Goemon 3 (J) Head-Up Display for TASing

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

function note_name(note_number)
  local names = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }
  note_number = math.floor(note_number)
  if note_number >= 0 then
    return string.format("%-2s%d", names[1 + (note_number % 12)], note_number / 12)
  else
    return string.format("%d", note_number)
  end
end

function gui.color(r, g, b, a)
  if not a then
    a = 255
  end

  r = math.floor(r)
  g = math.floor(g)
  b = math.floor(b)
  a = math.floor(a)

  if a > 127 then
    return (r * 65536 + g * 256 + b) - ((256 - a) * 16777216)
  else
    return a * 16777216 + r * 65536 + g * 256 + b
  end
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
  local lua_savestate = { players = deep_copy(self.players), RNGUpdatedTimes_Idle = self.RNGUpdatedTimes_Idle, RNGUpdatedTimesTotal_Idle = self.RNGUpdatedTimesTotal_Idle}
  self.savestate_storage[savestate_id] = lua_savestate
end
event.onsavestate(Goemon3SimpleHUD.onsavestate)

-- Callback on RNG update (idle)
function Goemon3SimpleHUD.OnRNGUpdateIdle()
  local self = Goemon3SimpleHUD.instance()
  self.RNGUpdatedTimes_Idle = self.RNGUpdatedTimes_Idle + 1
end

-- Callback on fireworks ordering
function Goemon3SimpleHUD.OnFireworksOrder()
  local self = Goemon3SimpleHUD.instance()
  self.RNGOnFireworksOrder = mainmemory.read_u16_le(0x0086)
end

-- Callback on load state
function Goemon3SimpleHUD.onloadstate(savestate_id)
  local self = Goemon3SimpleHUD.instance()
  local lua_savestate = self.savestate_storage[savestate_id]

  self.players = {}
  self:fetch()

  if lua_savestate then
    self.RNGUpdatedTimes_Idle = lua_savestate.RNGUpdatedTimes_Idle
    self.RNGUpdatedTimesTotal_Idle = lua_savestate.RNGUpdatedTimesTotal_Idle

    for player_index = 0, 1 do
      local player = lua_savestate.players[player_index + 1]
      self.players[player_index + 1].velocity_x = player.velocity_x
      self.players[player_index + 1].velocity_y = player.velocity_y
    end
  else
    self.RNGUpdatedTimes_Idle = 0
    self.RNGUpdatedTimesTotal_Idle = 0
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

  self.MAX_PLAYERS = 2
  self.MAX_SPRITES = 64
  self.MAX_SOUND_CHANNELS = 8

  self.show_player_status = true
  self.show_hitbox = true
  self.show_sound = true
  self.show_fireworks = true
  self.rng_tracking = false -- slow

  self.RNGUpdatedTimes_Idle = 0
  self.RNGUpdatedTimesTotal_Idle = 0
  self.RNGOnFireworksOrder = 0

  return self
end

-- Get instance of the singleton class
function Goemon3SimpleHUD.instance()
  if not Goemon3SimpleHUD.__instance then
    Goemon3SimpleHUD.__instance = Goemon3SimpleHUD()
  end
  return Goemon3SimpleHUD.__instance
end

--- Reset variables on frame start.
-- @param self Goemon3SimpleHUD object.
function Goemon3SimpleHUD:onframestart()
  self.RNGUpdatedTimes_Idle = 0
  if self.rng_tracking then
    event.onmemoryexecute(Goemon3SimpleHUD.OnRNGUpdateIdle, 0x8080F1, "Goemon3SimpleHUD.OnRNGUpdateIdle")
    event.onmemoryexecute(Goemon3SimpleHUD.OnFireworksOrder, 0x8DB7B3, "Goemon3SimpleHUD.OnFireworksOrder")
  end
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

  self.realtime = {}
  self.realtime.frames = emu.framecount()
  local fps = 21477272.0 / 357366.0
  local realtime_seconds = self.realtime.frames / fps
  self.realtime.subseconds = realtime_seconds - math.floor(realtime_seconds)
  self.realtime.seconds = math.floor(realtime_seconds) % 60
  self.realtime.minutes = math.floor(realtime_seconds) / 60 % 60
  self.realtime.hours = math.floor(math.floor(realtime_seconds) / 60 / 60)
  self.realtime.readable = ((self.realtime.hours == 0) and "" or string.format("%d:", self.realtime.hours)) ..
    string.format("%02d:%05.2f", self.realtime.minutes, self.realtime.seconds + self.realtime.subseconds)

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
  for player_index = 0, self.MAX_PLAYERS - 1 do
    local base_address = 0x0400 + (player_index * 0xc0)
    local player = {}

    player.x_relative = mainmemory.read_s24_le(base_address + 0x08)
    player.y_relative = mainmemory.read_s24_le(base_address + 0x0c)
    player.x = self.camera_x + player.x_relative
    player.y = self.camera_y + player.y_relative
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

    player.hitbox = {}
    player.hitbox.width = mainmemory.read_u16_le(base_address + 0x2e)
    player.hitbox.height = mainmemory.read_u16_le(base_address + 0x30)
    player.hitbox.px_left = math.floor(player.x_relative / 256) - player.hitbox.width
    player.hitbox.px_right = math.floor(player.x_relative / 256) + player.hitbox.width
    player.hitbox.px_top = math.floor(player.y_relative / 256) - player.hitbox.height
    player.hitbox.px_bottom = math.floor(player.y_relative / 256)
    player.hitbox.width = player.hitbox.width * 2

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

  self.sprites = {}
  for sprite_index = 0, self.MAX_SPRITES do
    local base_address = 0x0300 + (sprite_index * 0x50)
    local sprite = {}

    sprite.available = (mainmemory.read_u16_le(base_address) ~= 0)
    sprite.atrributes = {}
    sprite.atrributes.bits = mainmemory.readbyte(base_address + 0x04)
    sprite.x_relative = mainmemory.read_s24_le(base_address + 0x08)
    sprite.y_relative = mainmemory.read_s24_le(base_address + 0x0c)
    sprite.x = self.camera_x + sprite.x_relative
    sprite.y = self.camera_y + sprite.y_relative
    sprite.z = mainmemory.read_s16_le(base_address + 0x10)
    sprite.flag1 = mainmemory.readbyte(base_address + 0x14) -- size of shadow etc
    sprite.shadow_offset = mainmemory.read_s8(base_address + 0x15)
    sprite.character_id = mainmemory.read_u16_le(base_address + 0x18)
    sprite.next_sprite_address = mainmemory.read_u16_le(base_address + 0x16)
    sprite.action = mainmemory.read_u16_le(base_address + 0x1a)
    sprite.timer =  mainmemory.read_u16_le(base_address + 0x20)
    sprite.velocity_x = mainmemory.read_s16_le(base_address + 0x26)
    sprite.velocity_y = mainmemory.read_s16_le(base_address + 0x28)
    sprite.velocity_z = mainmemory.read_s16_le(base_address + 0x2a)
    sprite.hitbox = {}
    sprite.hitbox.width = mainmemory.read_u16_le(base_address + 0x2e)
    sprite.hitbox.height = mainmemory.read_u16_le(base_address + 0x30)
    sprite.hitbox.px_left = math.floor(sprite.x_relative / 256) - sprite.hitbox.width
    sprite.hitbox.px_right = math.floor(sprite.x_relative / 256) + sprite.hitbox.width
    sprite.hitbox.px_top = math.floor(sprite.y_relative / 256) - sprite.hitbox.height
    sprite.hitbox.px_bottom = math.floor(sprite.y_relative / 256)
    sprite.hitbox.width = sprite.hitbox.width * 2
    sprite.hitbox.attributes = mainmemory.read_u16_le(base_address + 0x34)
    sprite.health = mainmemory.readbyte(base_address + 0x36)

    -- workaround for invalid sprites
    if sprite.hitbox.width < 0 or sprite.hitbox.height < 0 or sprite.hitbox.width > 32 or sprite.hitbox.height > 64 then
      sprite.available = false
    elseif sprite.health == 0 then
      sprite.available = false
    end

    self.sprites[sprite_index + 1] = sprite
  end

  -- some other platformer variables
  self.walker_jump = mainmemory.readbyte(0x042c)

  -- fireworks in Omatsurimura
  self.fireworks = nil
  if self.room == 0x0170 then
    self.fireworks = {}
    self.fireworks.count = mainmemory.readbyte(0x0cae)
    self.fireworks.ignited_count = mainmemory.readbyte(0x0c9a)
    self.fireworks.list = {}

    if self.fireworks.count > 0 then
      -- fetch the ignition order and positions of fireworks
      for firework_index = 0, self.fireworks.count - 1 do
        local base_address = 0x0ca0 + (firework_index * 0x50)
        local ignition_index = mainmemory.readbyte(base_address + 0x4a)
        local firework = {}

        firework.x = mainmemory.readbyte(base_address + 0x19)
        firework.y = mainmemory.readbyte(base_address + 0x1d)
        firework.index = firework_index
        self.fireworks.list[ignition_index + 1] = firework
      end

      if self.fireworks.count == #self.fireworks.list then
        -- calculate how much the pattern is optimal
        local total_distance = 0
        local disciple = { x = 192, y = 92 }
        local firework_from = disciple
        local firework_to = self.fireworks.list[1]
        for ignition_index = 1, self.fireworks.count + 1 do
          local distance = math.abs(firework_to.x - firework_from.x) + math.abs(firework_to.y - firework_from.y)
          total_distance = total_distance + distance

          firework_from = firework_to
          if ignition_index < self.fireworks.count then
            firework_to = self.fireworks.list[ignition_index + 1]
          else
            firework_to = disciple
          end
        end
        self.fireworks.total_distance = total_distance
      else
        self.fireworks = nil
      end
    end
  end

  event.unregisterbyname("Goemon3SimpleHUD.OnRNGUpdateIdle")
  event.unregisterbyname("Goemon3SimpleHUD.OnFireworksOrder")
  if self.rng_tracking then
    self.RNGUpdatedTimesTotal_Idle = self.RNGUpdatedTimesTotal_Idle + self.RNGUpdatedTimes_Idle
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

  -- sound
  memory.usememorydomain("APURAM")
  self.sound = { channels = {} }
  for sound_channel = 0, self.MAX_SOUND_CHANNELS - 1 do
    local channel = {}
    channel.address = memory.read_u16_le(0x30 + sound_channel * 2)
    channel.delta_time = memory.readbyte(0x60 + sound_channel * 2)
    channel.available = (memory.readbyte(0xd0 + sound_channel * 2) ~= 0)
    channel.note_number = memory.read_u16_le(0xe0 + sound_channel * 2) / 256.0
    self.sound.channels[sound_channel] = channel
  end

  memory.usememorydomain(saved_memory_domain)
end

--- Render game status to screen.
-- @param self Goemon3SimpleHUD object.
function Goemon3SimpleHUD:render_player_status()
  local hud_x, hud_y = 0, 80
  local font_height = 16
  local status_message

  -- hitboxes
  if self.show_hitbox then
    if self.platform_screen then
      for player_index = 0, self.MAX_PLAYERS - 1 do
        local player = self.players[player_index + 1]
        gui.drawRectangle(player.hitbox.px_left, player.hitbox.px_top, player.hitbox.width, player.hitbox.height, gui.color(255, 255, 255, self.fade_level * 173))
      end

      for sprite_index = 0, self.MAX_SPRITES do
        local sprite = self.sprites[sprite_index + 1]
        if sprite.available then
          gui.drawRectangle(sprite.hitbox.px_left, sprite.hitbox.px_top, sprite.hitbox.width, sprite.hitbox.height, gui.color(255, 0, 0, self.fade_level * 173))
        end
      end
    end
  end

  -- messages
  status_message = "RTA:" .. self.realtime.readable
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

      if self.show_player_status then
        for player_index = 0, self.MAX_PLAYERS - 1 do
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
      end
    elseif self.game_state == self.GAME_STATE_CHASE then
      local meter = self.meters_left
      if meter ~= 0 then
        meter = meter + ((3 - (self.framecount % 4)) / 4.0)
      end

      status_message = status_message .. string.format(" %.2fM", meter)
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
      status_message = status_message .. string.format(" EN%d", self.impact.health)
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

  -- sound
  if self.show_sound then
    hud_x, hud_y = 180, 80
    for sound_channel = 0, self.MAX_SOUND_CHANNELS - 1 do
      local channel = self.sound.channels[sound_channel]
      if channel.available then
        status_message = string.format("%d:%04X %s %d", sound_channel, channel.address, note_name(channel.note_number), channel.delta_time)
        gui.text(hud_x * client.getwindowsize(), hud_y, status_message)
        hud_y = hud_y + font_height
      end
    end
  end

  -- fireworks
  if self.show_fireworks and self.fireworks then
    for i, firework in ipairs(self.fireworks.list) do
      local backcolor, forecolor
      local osc

      if (i - 1) == self.fireworks.ignited_count then
        forecolor = gui.color(255, 255, 255, 255)
        osc = math.floor(0.5 + 1.618 * math.sin(((self.framecount % 60) / 30.0) * math.pi)) - 2
      else
        forecolor = gui.color(255, 255, 255, 128)
        osc = 0
      end

      gui.text(firework.x * client.getwindowsize(),
        (firework.y + osc) * client.getwindowsize(),
        string.format("%d", i), backcolor, forecolor)
    end
  end

  -- RNG
  if self.rng_tracking then
    gui.text(0 * client.getwindowsize(),
      188 * client.getwindowsize() - 32,
      string.format("RNG:%04X FW:%04X", self.random, self.RNGOnFireworksOrder))

    gui.text(0 * client.getwindowsize(),
      188 * client.getwindowsize() - 16,
      string.format("RNG UPD(IDLE):%d(%d/F)", self.RNGUpdatedTimesTotal_Idle, self.RNGUpdatedTimes_Idle))
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
event.onframestart(function()
  hud:onframestart()
end)

-- frame-based procedure
event.onframeend(function()
  hud:fetch()
  hud:render()
end)
