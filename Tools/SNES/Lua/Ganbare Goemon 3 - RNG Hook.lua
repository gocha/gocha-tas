-- Ganbare Goemon 3 RNG Research Script

local readExcludePCs = {
  0x8080EF, -- idle loop

  -- 0x86C43D, -- generic broken pieces display or item drop?
  -- 0x86C440, -- generic broken pieces display or item drop?
  -- 0x86C445, -- generic broken pieces display or item drop?
  -- 0x86C44A, -- generic broken pieces display or item drop?
  -- 0x86C45B, -- ?
  0x8BBFBB, -- boss frog smoke position before appearing
  0x8BC200, -- condition for boss frog smoke after flaming
}

event.onmemoryread(function()
  local pc = emu.getregister("PC")

   for i = 1, #readExcludePCs do
      if pc == readExcludePCs[i] then
         return
      end
   end

  print(string.format("[%d] RNG Read from $%06X", emu.framecount(), pc))
end, 0x0086, "RNG Read")
