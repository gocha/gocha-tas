-- Lua: Override tostring() and provide pretty print for table.
-- This implementation is nearly close to what DeSmuME does.

-- do nothing if it's already prettified
if string.match(tostring({}), "{") then
  return nil
end

local __PrettyToString = {}

__PrettyToString = {
  tostring = tostring;

  -- Return if given table is an array, not hash.
  -- An array which includes nil will be treated as a hash.
  -- @param e Table object.
  -- @return true if given parameter is an array.
  isarray = function(e)
    if type(e) ~= "table" then
      return false
    end

    local expected_array_index = 1
    for k, v in pairs(e) do
      if type(k) ~= "number" or k ~= expected_array_index then
        return false
      end
      expected_array_index = expected_array_index + 1
    end
    return true
  end;

  pretty_tostring = function(e, dumped_tables)
    dumped_tables = dumped_tables or {}
    if type(e) == "table" then
      if dumped_tables[e] then
        -- circular reference, must not dump it again.
        return __PrettyToString.tostring(e)
      else
        dumped_tables[e] = true

        local first = true
        local s = "{"
        local skip_key = __PrettyToString.isarray(e)
        for k, v in pairs(e) do
          if first then
            first = false
          else
            s = s .. ", "
          end

          if not skip_key then
            local key_pre, key_post = "", ""
            if type(k) == "string" then
              if not string.match(k, "^[A-Za-z_]") then
                key_pre, key_post = '["', '"]'
              end
            else
              key_pre, key_post = "[", "]"
            end

            s = s .. key_pre .. __PrettyToString.pretty_tostring(k, dumped_tables) .. key_post .. "="
          end

          local value_pre, value_post = "", ""
          if type(v) == "string" then
            value_pre, value_post = '"', '"'
          end
          s = s .. value_pre .. __PrettyToString.pretty_tostring(v, dumped_tables) .. value_post
        end
        s = s .. "}"

        return s
      end
    else
      return tostring(e)
    end
  end;
}

function tostring(e)
  if type(e) == "table" then
    return __PrettyToString.pretty_tostring(e)
  else
    return __PrettyToString.tostring(e)
  end
end
