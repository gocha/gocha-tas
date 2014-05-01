--- PCKeyState: User hotkey module for BizHawk.

-- See the following page to know OOP in Lua.
-- http://lua-users.org/wiki/ObjectOrientationTutorial

local PCKeyState = {}
PCKeyState.__index = PCKeyState

-- Class(...) works as same as Class.new(...)
setmetatable(PCKeyState, {
  __call = function (klass, ...)
    return klass.new(...)
  end,
})

--- Keyboard symbol to name table
PCKeyState.NAMES = {
  Stop="Stop";
  Period="Period";
  Mute="Mute";
  Mail="Mail";
  Escape="Escape";
  Yen="Yen";
  WebStop="Web Stop";
  WebSearch="Web Search";
  WebRefresh="Web Refresh";
  WebHome="Web Home";
  WebForward="Web Forwards";
  WebFavorites="Web Favorites";
  WebBack="Web Backwards";
  Wake="Wake";
  VolumeUp="Volume Up";
  VolumeDown="Volume Down";
  UpArrow="Up";
  Unlabeled="Unlabeled";
  Underline="Underline";
  PrintScreen="Print Screen";
  Space="Space";
  Slash="Slash";
  Semicolon="Semicolon";
  ScrollLock="Scroll Lock";
  RightWindowsKey="Right Windows";
  RightShift="Right Shift";
  RightAlt="Right Alt";
  RightArrow="Right";
  Return="Enter";
  RightControl="Right Ctrl";
  RightBracket="Right Bracket";
  PreviousTrack="Previous Track";
  PlayPause="Play/Pause";
  Pause="Pause";
  PageUp="Page Up";
  PageDown="Page Down";
  Oem102="OEM102";
  NumberPadStar="Asterisk (NumPad)";
  NumberPadSlash="Slash (NumPad)";
  NumberPadPlus="Plus (NumPad)";
  NumberPadPeriod="Period (NumPad)";
  NumberPadMinus="Minus (NumPad)";
  NumberPadEquals="Equals (NumPad)";
  NumberPadEnter="Enter (NumPad)";
  NumberPadComma="Comma (NumPad)";
  NumberPad0="0 (NumPad)";
  NumberPad1="1 (NumPad)";
  NumberPad2="2 (NumPad)";
  NumberPad3="3 (NumPad)";
  NumberPad4="4 (NumPad)";
  NumberPad5="5 (NumPad)";
  NumberPad6="6 (NumPad)";
  NumberPad7="7 (NumPad)";
  NumberPad8="8 (NumPad)";
  NumberPad9="9 (NumPad)";
  NumberLock="Num Lock";
  NoConvert="No Convert";
  NextTrack="Next Track";
  MyComputer="My Computer";
  Minus="Minus";
  MediaStop="Media Stop";
  MediaSelect="Media Select";
  LeftWindowsKey="Left Windows";
  LeftShift="Left Shift";
  LeftAlt="Left Alt";
  LeftArrow="Left";
  LeftControl="Left Ctrl";
  LeftBracket="Left Bracket";
  Kanji="Kanji";
  Kana="Kana";
  Insert="Insert";
  Home="Home";
  Grave="Grave";
  F1="F1";
  F2="F2";
  F3="F3";
  F4="F4";
  F5="F5";
  F6="F6";
  F7="F7";
  F8="F8";
  F9="F9";
  F10="F10";
  F11="F11";
  F12="F12";
  F13="F13";
  F14="F14";
  F15="F15";
  Equals="Equals";
  DownArrow="Down";
  Delete="Delete";
  Comma="Comma";
  Colon="Colon";
  CapsLock="Caps Lock";
  Calculator="Calculator";
  Backslash="Back Slash";
  Backspace="Backspace";
  AX="Ax";
  AT="At";
  Applications="Applications";
  Apostrophe="Apostrophe";
  AbntC1="AbntC1";
  AbntC2="AbntC2";
  D0="0";
  D1="1";
  D2="2";
  D3="3";
  D4="4";
  D5="5";
  D6="6";
  D7="7";
  D8="8";
  D9="9";
  A="A";
  B="B";
  C="C";
  D="D";
  E="E";
  F="F";
  G="G";
  H="H";
  I="I";
  J="J";
  K="K";
  L="L";
  M="M";
  N="N";
  O="O";
  P="P";
  Q="Q";
  R="R";
  S="S";
  T="T";
  U="U";
  V="V";
  W="W";
  X="X";
  Y="Y";
  Z="Z";
  Tab="Tab";
  Sleep="Sleep";
  Convert="Convert";
  Power="Power";
  End="End";
};

--- Constructor of PCKeyState
function PCKeyState.new()
  local self = setmetatable({}, PCKeyState)
  self.keys_held = {}
  self.keys_down = {}
  self.keys_up = {}
  self.held_length = {}
  self.hotkeys = {}
  return self
end

--- Get keyboard state from system.
-- This function needs to be called quite frequently if you use hotkey feature.
-- Create a loop by using emu.yield() and call this function.
function PCKeyState.update(self)
local keys_held_previous = self.keys_held
  self.keys_held = input.get()

  self.keys_down = {}
  self.keys_up = {}

  -- handle keydown
  for key, held in pairs(self.keys_held) do
    if held then
      if not self.held_length[key] then
        self.keys_down[key] = held
      end
      self.held_length[key] = (self.held_length[key] or 0) + 1
    else
      self.held_length[key] = nil
    end
  end

  -- handle keyup
  for key, held in pairs(keys_held_previous) do
    if held and not self.keys_held[key] then
      self.keys_up[key] = held
      self.held_length[key] = nil
    end
  end

  local bool_equal = function(a, b)
    return (a and b) or (not a and not b)
  end

  -- fire hotkey event
  for i, hotkey in ipairs(self.hotkeys) do
    if self.keys_down[hotkey.key] and
      bool_equal(hotkey.modifiers.control, self:control_held()) and
      bool_equal(hotkey.modifiers.shift, self:shift_held()) and
      bool_equal(hotkey.modifiers.alt, self:alt_held()) and
      bool_equal(hotkey.modifiers.windows, self:windows_held())
    then
      hotkey.callback()
    end
  end
end

--- Check if control key is held.
-- @param self PCKeyState object.
-- @return true if control key is held.
function PCKeyState.control_held(self)
  if self.keys_held.LeftControl or self.keys_held.RightControl then
    return true
  else
    return false
  end
end;

--- Check if shift key is held.
-- @param self PCKeyState object.
-- @return true if shift key is held.
function PCKeyState.shift_held(self)
  if self.keys_held.LeftShift or self.keys_held.RightShift then
    return true
  else
    return false
  end
end;

--- Check if alt key is held.
-- @param self PCKeyState object.
-- @return true if alt key is held.
function PCKeyState.alt_held(self)
  if self.keys_held.LeftAlt or self.keys_held.RightAlt then
    return true
  else
    return false
  end
end;

--- Check if windows key is held.
-- @param self PCKeyState object.
-- @return true if windows key is held.
function PCKeyState.windows_held(self)
  if self.keys_held.LeftWindowsKey or self.keys_held.RightWindowsKey then
    return true
  else
    return false
  end
end;

--- Register hotkey event.
-- @param self PCKeyState object.
-- @param key Key identifier used in input.get()
-- @param modifiers Table to specify modifiers.
-- For example: { control=true, shift=true, alt=false, windows=false }
-- @param callback Hotkey callback function.
function PCKeyState.onhotkey(self, key, modifiers, callback)
  modifiers = modifiers or {}
  table.insert(self.hotkeys, {
    key = key;
    modifiers = {
      control = modifiers.control and (key ~= "LeftControl" and key ~= "RightControl");
      shift = modifiers.shift and (key ~= "LeftShift" and key ~= "RightShift");
      alt = modifiers.alt and (key ~= "LeftAlt" and key ~= "RightAlt");
      windows = modifiers.windows and (key ~= "LeftWindows" and key ~= "RightWindows");
    };
    callback = callback;
  })
end

return PCKeyState
