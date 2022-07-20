-- Ganbare Goemon 3 RNG Research Script

local readExcludePCs = {
  0x8080EF, -- idle loop

  -- 0x86C43D, -- part of $86C43D, RNG update routine
  0x86C440, -- part of $86C43D, RNG update routine
  0x86C445, -- part of $86C43D, RNG update routine
  0x86C44A, -- part of $86C43D, RNG update routine
  -- 0x86C45B, -- ?
  -- 0x8BBFBB, -- boss frog smoke position before appearing
  -- 0x8BC200, -- condition for boss frog smoke after flaming
}

event.onmemoryread(function()
  local pc = emu.getregister("PC")

  for i = 1, #readExcludePCs do
    if pc == readExcludePCs[i] then
      return
    end
  end

  if pc == 0x86C43D then
    local s = emu.getregister("S")
    local caller_pc = mainmemory.read_u24_le(s + 1)
    print(string.format("[%d] RNG Advance from $%06X", emu.framecount(), caller_pc))
  else
    print(string.format("[%d] RNG Read from $%06X", emu.framecount(), pc))
  end
end, 0x0086, "RNG Read")
