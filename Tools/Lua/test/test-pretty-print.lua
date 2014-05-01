-- pretty print test

-- require 'pretty-tostring'
require 'bizhawk-pretty-print'

-- {{[true]=false, [1]={100, 200}, ["!?"]="symbol", [{1, 2}]="table", testfunc=function: 00123ABC}}
local t = {{
  ["!?"] = "symbol";
  [1] = { 100, 200 };
  [{1, 2}] = "table";
  testfunc = tonumber;
  [true] = false;
}} -- nested table
t[t] = t -- recursive reference

print("print\n")
print(tostring(t))
print(t)
print("aaa", "bbb", "ccc")
print("--------------------\n")
print("\n")
if console then
  if console.write then
    print("console.write\n")
    console.write(t, "aaa", "bbb", "ccc")
    print("--------------------\n")
    print("\n")
  end
  if console.writeline then
    print("console.writeline\n")
    console.writeline(t, "aaa", "bbb", "ccc")
    print("--------------------\n")
    print("\n")
  end
  if console.log then
    print("console.log\n")
    console.log(t, "aaa", "bbb", "ccc")
    print("--------------------\n")
    print("\n")
  end
end
