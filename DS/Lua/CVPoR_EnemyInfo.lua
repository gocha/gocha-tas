-- displays enemy's position

gui.register(function()
	local base = 0x02100da8
	local dispy = 1
	for i = 0, 15 do
		if memory.readword(base) > 0 then -- hp
			gui.text(171, dispy, string.format("%X %03d %08X", i, memory.readword(base), memory.readdword(base-0xf8)))
			dispy = dispy + 10
		end
		base = base + 0x160
	end
end)
