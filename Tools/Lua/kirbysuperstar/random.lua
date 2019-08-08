--- Kirby Super Star RNG Module

local bit = require "bit"

local RNG = {}
RNG.__index = RNG

-- Class(...) works as same as Class.new(...)
setmetatable(RNG, {
  __call = function (klass, ...)
    return klass.new(...)
  end,
})

--- Constructs new RNG object.
-- @param seed Initial random seed (corresponding to $3743-3744)
function RNG.new(seed)
  local self = setmetatable({}, RNG)
  self.seed = seed or 0x7777
  return self
end

--- Generates the next random number.
function RNG.advance(self)
  -- Reimplementation of $8aba-8ad1 (part of jsl $8a9f)
  local seed = self.seed
  for i = 1, 11 do
    local randbit = bit.band(1, bit.bxor(1, seed, bit.rshift(seed, 1), bit.rshift(seed, 15)))
    seed = bit.band(bit.bor(bit.lshift(seed, 1), randbit), 0xffff)
  end
  self.seed = seed
end

--- Returns the next random number.
-- @param bound the upper bound (exclusive). Must be between 1 and 255, or 0 (works as 256).
-- @return the next random number.
function RNG.random(self, bound)
  self:advance()

  -- Reimplementation of $8ad7-8ae9 (part of jsl $8a9f)
  local value = bit.band(self.seed, 0xff)
  if bound and bound ~= 0 then
    value = bit.rshift(value * bound, 8)
  end
  return value
end

return RNG
