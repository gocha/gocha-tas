-- Ganbare Goemon 3 (J) Simple Memory Display for TAS work

function number_to_bcd(n)
  return tonumber(tostring(n), 16)
end

function bcd_to_number(n)
  return tonumber(string.format("%x", n), 10)
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

--- Constructor of Goemon3SimpleHUD
function Goemon3SimpleHUD.new()
  local self = setmetatable({}, Goemon3SimpleHUD)
  return self
end

--- Fetch game variables.
-- @param self Goemon3SimpleHUD object.
function Goemon3SimpleHUD.fetch(self)
  self.game_state = mainmemory.readbyte(0x0090)
  self.fade_level = math.min(mainmemory.readbyte(0x1fa0) / 15.0, 1.0)

  self.camera_x = bit.lshift(mainmemory.read_u16_le(0x1662), 8)
  self.camera_y = bit.lshift(mainmemory.read_u16_le(0x1672), 8)

  self.player = {}
  for player_index = 0, 1 do
    local base_address = 0x0400 + (player_index * 0xc0)
    self.player[player_index + 1] = {}
    self.player[player_index + 1].x = self.camera_x + mainmemory.read_u16_le(base_address + 0x08)
    self.player[player_index + 1].y = self.camera_y + mainmemory.read_u16_le(base_address + 0x0c)
    self.player[player_index + 1].return_x = self.camera_x + bit.lshift(mainmemory.read_u16_le(base_address + 0x80), 8)
    self.player[player_index + 1].return_y = self.camera_y + bit.lshift(mainmemory.read_u16_le(base_address + 0x82), 8)
  end

  self.walker_jump = mainmemory.readbyte(0x042c)
end

--- Render game status to screen.
-- @param self Goemon3SimpleHUD object.
function Goemon3SimpleHUD.render_player_status(self)
  if self.game_state == 2 or self.game_state == 4 then
    return
  end

  local hud_x, hud_y = 0, 64
  local font_height = 16
  for player_index = 0, 1 do
    local status_message = string.format("%dP: P(%06X,%06X)", player_index + 1, self.player[player_index + 1].x, self.player[player_index + 1].y)
    gui.text(hud_x, hud_y, status_message)
    hud_y = hud_y + font_height
  end
end

--- Render game status to screen.
-- @param self Goemon3SimpleHUD object.
function Goemon3SimpleHUD.render(self)
  self:render_player_status()
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

local hud = Goemon3SimpleHUD()

-- frame-based procedure
event.onframestart(function()
  hud:fetch()
  hud:render()
end)
