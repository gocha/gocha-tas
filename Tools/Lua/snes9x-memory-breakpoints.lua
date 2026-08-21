-- Simple memory breakpoint script for casual research
-- For Snes9x rerecording 1.43/1.51

-- User configuration
local deduplicate = true

local breakpoints = {
    { type = "exec",  addr = 0x83D22C, name = "damage" },
    { type = "read",  addr = 0x7E044E, name = "subweapon charge" },
    { type = "write", addr = 0x7E008E, name = "room number" },
}

-- Internal state
local seen = {}

if deduplicate then
    print("Deduplication enabled: each address/PC combination is reported only once.")
end

local function should_print(addr, pc)
    if not deduplicate then
        return true
    end

    local key = string.format("%06X:%06X", addr, pc)

    if seen[key] then
        return false
    end

    seen[key] = true
    return true
end

-- Callbacks
function on_execute(addr, size)
    local pc = memory.getregister("pbpc")

    if not should_print(addr, pc) then
        return
    end

    print(string.format(
        "Frame %d | Execute at $%06X.",
        emu.framecount(), addr
    ))
end

function on_read(addr, size)
    local pc = memory.getregister("pbpc")

    if not should_print(addr, pc) then
        return
    end

    local value
    if size == 2 then
        value = memory.readword(addr)
    else
        value = memory.readbyte(addr)
    end

    print(string.format(
        "Frame %d | Read $%06X at $%06X (%d byte(s)) = $%X.",
        emu.framecount(), addr, pc, size, value
    ))
end

function on_write(addr, size)
    local pc = memory.getregister("pbpc")

    if not should_print(addr, pc) then
        return
    end

    local value
    if size == 2 then
        value = memory.readword(addr)
    else
        value = memory.readbyte(addr)
    end

    print(string.format(
        "Frame %d | Write $%06X at $%06X (%d byte(s)) = $%X.",
        emu.framecount(), addr, pc, size, value
    ))
end

-- Register callback for breakpoints
for _, breakpoint in ipairs(breakpoints) do
    if breakpoint.type == "exec" then
        memory.registerexec(breakpoint.addr, on_execute)
    elseif breakpoint.type == "read" then
        memory.registerread(breakpoint.addr, on_read)
    elseif breakpoint.type == "write" then
        memory.registerwrite(breakpoint.addr, on_write)
    else
        print(string.format(
            "Invalid breakpoint type: %s (address $%06X).",
            tostring(breakpoint.type), breakpoint.addr
        ))
    end
end
