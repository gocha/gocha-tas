
PCKeyState = require "bizhawk-pckeystate"

local pckey = PCKeyState()

pckey:onhotkey("Z", { control=true, shift=true }, function()
  print("Ctrl+Shift+Z pressed")
end)

-- frame-based stuff
event.onframestart(function()
  gui.text(0, 100, "Frame Test " .. tostring(os.time()))
end)

while true do
  pckey:update()
  gui.text(0, 150, "PCKeyState Test (Press Ctrl+Shift+Z)" .. "\n" ..
  "control=" .. tostring(pckey:control_held()) .. "\n" ..
  "shift=" .. tostring(pckey:shift_held()) .. "\n" ..
  "alt=" .. tostring(pckey:alt_held()))
  emu.yield()
end
