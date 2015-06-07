-- Ganbare Goemon 3 - Fireworks Simulator (Standalone Application)

if not bit then
  bit = require("bit")
end

function Goemon3HanabiOrder(hanabi_num, initial_rng)
  local next_rng = function(a, x)
    local data_80 = {
      0x18, 0xfb, 0x78, 0xd8, 0xc2, 0x30, 0xa2, 0xaf,
      0x01, 0x9a, 0xc2, 0x30, 0x8b, 0xa9, 0x00, 0x00,
      0x8f, 0x00, 0x00, 0x00, 0xa9, 0xfd, 0x1f, 0xa2,
      0x01, 0x00, 0x9b, 0xc8, 0x54, 0x00
    }

    local data_82 = {
      0xa5, 0x7e, 0x0a, 0xaa, 0x7c, 0x07, 0x80, 0x19,
      0x80, 0x29, 0x80, 0x3f, 0x80, 0xdf, 0x80, 0xf6,
      0x80, 0x6f, 0x81, 0xbd, 0x81, 0x88, 0x83, 0x99,
      0x83, 0x22, 0x00, 0xae, 0x8a, 0x90
    }

    local i = bit.rshift(x, 1)
    local c = bit.band(x, 1)

    local rnd_hi = bit.band(a + data_80[1 + i] + c, 0xff)
    local rnd_lo = bit.bxor(bit.rshift(a, 8), data_82[1 + i])

    return bit.bor(rnd_lo, bit.lshift(rnd_hi, 8)), x + 3
  end

  function range_rng(rng, max_num)
    return bit.rshift(bit.band(rng, 0xff) * max_num, 8)
  end

  -- initialize in descending order
  local hanabi_orders = {}
  for i = 0, hanabi_num - 1 do
    hanabi_orders[1 + i] = hanabi_num - i - 1
  end

  -- swap the order
  local rng = initial_rng
  local rng_index = 0
  for i = 0, hanabi_num - 1 do
    -- get next random number
    rng, rng_index = next_rng(rng, rng_index)

    -- get ranged random number
    local rnd = range_rng(rng, hanabi_num)

    -- swap
    hanabi_orders[1 + i], hanabi_orders[1 + rnd] = hanabi_orders[1 + rnd], hanabi_orders[1 + i]
  end

  return hanabi_orders
end

function main(arg)
  if #arg == 0 then
    print("Usage: this.lua [number of fireworks]")
    return
  end

  local hanabi_nums = tonumber(arg[1])
  if hanabi_nums < 4 or hanabi_nums > 20 then
    print("Out of range " .. hanabi_nums)
    return
  end

  for initial_rng = 0, 0xffff do
    local hanabi_orders = Goemon3HanabiOrder(hanabi_nums, initial_rng)
    print(string.format("$%04x,%s", initial_rng, table.concat(hanabi_orders, ",")))
  end
end
main(arg)
