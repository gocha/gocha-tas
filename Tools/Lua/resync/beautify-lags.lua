-- Standalone Lua: replace lag frame input by previous input

local LAG_FNAME = "doraemon2-tas-lag.dat"
local INPUT_FNAME = "Input Log.txt"
local OUTPUT_FNAME = "Input Log - Beautified.txt"

local INPUT_HEADER_LINES = 1

-- import lag database
function import_lag_database(fname)
  local file = io.open(fname, "r")
  if not file then
    error("File open error \"" .. fname .. "\"")
  end

  local lagframes = {}
  local line = file:read()
  while line do
    local framecount = tonumber(line)
    lagframes[framecount] = true
    line = file:read()
  end
  file:close()
  return lagframes
end

local lagged = import_lag_database(LAG_FNAME)
local in_file = io.open(INPUT_FNAME, "r")
local out_file = io.open(OUTPUT_FNAME, "w")

if not in_file then
  error("File open error \"" .. INPUT_FNAME .. "\"")
end

if not out_file then
  error("File open error \"" .. OUTPUT_FNAME .. "\"")
end

-- copy header lines
for i = 1, INPUT_HEADER_LINES do
  out_file:write(in_file:read(), "\n")
end

-- import frame text
local line = in_file:read()
local frames = {}
while line do
  table.insert(frames, line)
  line = in_file:read()
end
in_file:close()

local last_valid_frame = 1
for framecount = 1, #frames do
  if lagged[framecount] then
    out_file:write(frames[last_valid_frame], "\n")
  else
    out_file:write(frames[framecount], "\n")
    last_valid_frame = framecount
  end
end

out_file:close()
