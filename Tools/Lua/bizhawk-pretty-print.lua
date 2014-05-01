-- BizHawk Lua: override console output functions to use tostring()

require 'pretty-tostring'

if console == nil then
  return
end

local __BizHawkConsoleToString = {};

__BizHawkConsoleToString = {
  console_write = console.write;
  console_writeline = console.writeline;
  console_log = console.log;
  console_output = console.output;
  print = print;

  tostringall = function(...)
    local args = {...}
    for i = 1, #args do
      args[i] = tostring(args[i])
    end
    return unpack(args)
  end;
}

if __BizHawkConsoleToString.console_write then
  function console.write(...)
    return __BizHawkConsoleToString.console_write(__BizHawkConsoleToString.tostringall(...))
  end
end

if __BizHawkConsoleToString.console_writeline then
  function console.writeline(...)
    return __BizHawkConsoleToString.console_writeline(__BizHawkConsoleToString.tostringall(...))
  end
end

if __BizHawkConsoleToString.console_log then
  function console.log(...)
    return __BizHawkConsoleToString.console_log(__BizHawkConsoleToString.tostringall(...))
  end
end

if __BizHawkConsoleToString.console_output then
  function console.output(...)
    return __BizHawkConsoleToString.console_output(__BizHawkConsoleToString.tostringall(...))
  end
end

function print(...)
  return __BizHawkConsoleToString.print(__BizHawkConsoleToString.tostringall(...))
end
