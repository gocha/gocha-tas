-- Castlevania: Order of Ecclesia - RNG simulator
-- This script runs on both of normal lua host and emulua host (desmume)

if not bit then
	require("bit")
end

-- pure 32-bit multiplier
function mul32(a, b)
	-- separate the value into two 8-bit values to prevent type casting
	local x, y, z = {}, {}, {}
	x[1] = bit.band(a, 0xff)
	x[2] = bit.band(bit.rshift(a, 8), 0xff)
	x[3] = bit.band(bit.rshift(a, 16), 0xff)
	x[4] = bit.band(bit.rshift(a, 24), 0xff)
	y[1] = bit.band(b, 0xff)
	y[2] = bit.band(bit.rshift(b, 8), 0xff)
	y[3] = bit.band(bit.rshift(b, 16), 0xff)
	y[4] = bit.band(bit.rshift(b, 24), 0xff)
	-- calculate for each bytes
	local v, c
	v = x[1] * y[1]
	z[1], c = bit.band(v, 0xff), bit.rshift(v, 8)
	v = c + x[2] * y[1] + x[1] * y[2]
	z[2], c = bit.band(v, 0xff), bit.rshift(v, 8)
	v = c + x[3] * y[1] + x[2] * y[2] + x[1] * y[3]
	z[3], c = bit.band(v, 0xff), bit.rshift(v, 8)
	v = c + x[4] * y[1] + x[3] * y[2] + x[2] * y[3] + x[1] * y[4]
	z[4], c = bit.band(v, 0xff), bit.rshift(v, 8)
	v = c + x[4] * y[2] + x[3] * y[3] + x[2] * y[4]
	z[5], c = bit.band(v, 0xff), bit.rshift(v, 8)
	v = c + x[4] * y[3] + x[3] * y[4]
	z[6], c = bit.band(v, 0xff), bit.rshift(v, 8)
	v = c + x[4] * y[4]
	z[7], z[8] = bit.band(v, 0xff), bit.rshift(v, 8)
	-- compose them and return it
	return bit.bor(z[1], bit.lshift(z[2], 8), bit.lshift(z[3], 16), bit.lshift(z[4], 24)),
	       bit.bor(z[5], bit.lshift(z[6], 8), bit.lshift(z[7], 16), bit.lshift(z[8], 24))
end

--[ OoE RNG simulator ] --------------------------------------------------------

local OoE_RN = 0

function OoE_Random()
	OoE_RN = bit.tobit(mul32(bit.arshift(OoE_RN, 8), 0x3243f6ad) + 0x1b0cb175)
	return OoE_RN
end

function OoE_RandomSeed(seed)
	OoE_RN = seed
end

function OoE_RandomLast()
	return OoE_RN
end

--------------------------------------------------------------------------------
if not emu then
-- [ main code for normal lua host ] -------------------------------------------

local numsToView = 128
local searchSpecifiedVal = false
local valToSearch

if #arg >= 1 then
	OoE_RandomSeed(tonumber(arg[1]))
	if #arg >= 2 then
		numsToView = tonumber(arg[2])
		if #arg >= 3 then
			searchSpecifiedVal = true
			valToSearch = tonumber(arg[3])
		end
	end
else
	io.write("Input the intial value of RNG: ")
	OoE_RandomSeed(io.read("*n"))
end

for i = 1, numsToView do
	io.write(string.format("%08X", OoE_RandomLast()))
	if i % 8 == 0 then
		io.write("\n")
	else
		io.write(" ")
	end
	if searchSpecifiedVal and OoE_RandomLast() == valToSearch then
		if i % 8 ~= 0 then
			io.write("\n")
		end
		break
	end
	OoE_Random()
end

--------------------------------------------------------------------------------
else
-- [ main code for emulua host ] -----------------------------------------------

local RNG_Previous = 0
local RNG_NumAdvanced = -1
local RAM = { RNG = 0x021389c0 }

emu.registerafter(function()
	local searchMax = 100

	RNG_NumAdvanced = -1
	OoE_RandomSeed(RNG_Previous)
	for i = 0, searchMax do
		if OoE_RandomLast() == bit.tobit(memory.readdword(RAM.RNG)) then
			RNG_NumAdvanced = i
			break
		end
		OoE_Random()
	end
	RNG_Previous = bit.tobit(memory.readdword(RAM.RNG))
end)

gui.register(function()
	OoE_RandomSeed(bit.tobit(memory.readdword(RAM.RNG)))
	agg.text(116, 5, string.format("NEXT:%08X", OoE_Random()))
	agg.text(116, 26, "ADVANCED:" .. ((RNG_NumAdvanced == -1) and "???" or tostring(RNG_NumAdvanced)))
end)

--------------------------------------------------------------------------------
end
