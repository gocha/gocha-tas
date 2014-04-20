-- DSM (DeSmuME movie) import/export functions.
-- Note: Lua cannot handle non 7-bit ASCII characters well, beware.
-- Note: Those functions don't care about corrupt files much.
-- Note: Those functions don't care the order of meta items.

-- Import DSM file from 'file' and return an array if succeeded (nil if failed).
function dsmImport(file)
	if file == nil then
		return nil
	end

	local line = file:read("*l")
	local dsm = {}
	local f = 1
	dsm.frame = {}
	dsm.meta = {}
	while line do
		if string.sub(line, 1, 1) == "|" then
			local buttonMappings = { "right", "left", "down", "up", "select", "start", "B", "A", "Y", "X", "L", "R", "debug" }
			local cmdMappings = { "mic", "reset", "lid" }
			local padOfs = string.find(line, "|", 2) + 1
			local cmd = tonumber(string.sub(line, 2, padOfs - 2))

			dsm.frame[f] = {}
			for i = 0, #buttonMappings - 1 do
				s = string.sub(line, padOfs + i, padOfs + i);
				dsm.frame[f][ buttonMappings[i+1] ] = ((s~="." and s~=" ") and true or false)
			end
			for i = 0, #cmdMappings - 1 do
				local bitf = math.pow(2, i) -- (1 << i)
				if math.floor(cmd / bitf) % 2 ~= 0 then -- (cmd & bitf) ~= 0
					dsm.frame[f][ cmdMappings[i+1] ] = true
				else
					dsm.frame[f][ cmdMappings[i+1] ] = false
				end
			end

			dsm.frame[f].touched = ((tonumber(string.sub(line, padOfs + 21, padOfs + 21))~=0) and true or false)
			if dsm.frame[f].touched then
				dsm.frame[f].touchX = tonumber(string.sub(line, padOfs + 13, padOfs + 15))
				dsm.frame[f].touchY = tonumber(string.sub(line, padOfs + 17, padOfs + 19))
			else
				dsm.frame[f].touchX = tonumber(string.sub(line, padOfs + 13, padOfs + 15))
				dsm.frame[f].touchY = tonumber(string.sub(line, padOfs + 17, padOfs + 19))
			end
			f = f + 1
		else
			local sep = string.find(line, " ")
			if sep == nil then
				io.stderr:write("dsmImport: Unknown line: "..line.."\n")
			else
				local decFields = "useExtBios rerecordCount emuVersion version"
				local k = string.sub(line, 1, sep-1)
				local v = string.sub(line, sep+1)
				if dsm.meta[k] then
					io.stderr:write("dsmImport: Duplicated item: "..k.."\n")
				end
				if string.find(decFields, k, 0, 0) ~= nil then
					dsm.meta[k] = tonumber(v)
				--elseif k == "romChecksum" and string.len(v) <= 8 then
				--	dsm.meta[k] = tonumber(v, 16)
				else
					dsm.meta[k] = v
				end
			end
		end
		line = file:read("*l")
	end
	dsm.frameRate = 33513982.0/560190.0

	return dsm
end

-- Export DSM file to 'file'
function dsmExport(dsm, file)
	if file == nil then
		return false
	end

	for k, v in pairs(dsm.meta) do
		if type(v) == "string" then
			file:write(k.." "..v.."\n")
		elseif k == "romChecksum" then
			file:write(k.." "..string.format("%08X", v).."\n")
		else
			file:write(k.." "..tostring(v).."\n")
		end
	end

	for f = 1, #dsm.frame do
		local buttonMappingsR = { "right", "left", "down", "up", "select", "start", "B", "A", "Y", "X", "L", "R", "debug" }
		local buttonMappingsW = { "R", "L", "D", "U", "T", "S", "B", "A", "Y", "X", "W", "E", "G" }
		local cmdMappings = { "mic", "reset", "lid" }
		local cmd

		cmd = 0
		for i = 0, #cmdMappings - 1 do
			local bitf = math.pow(2, i) -- (1 << i)
			if dsm.frame[f][ cmdMappings[i+1] ] then
				cmd = cmd + bitf
			end
		end

		file:write("|"..cmd.."|")
		for i = 1, #buttonMappingsW do
			file:write((dsm.frame[f][ buttonMappingsR[i] ] and buttonMappingsW[i] or "."))
		end
		if dsm.frame[f].touched then
			file:write(string.format("%03d %03d 1|", dsm.frame[f].touchX, dsm.frame[f].touchY))
		else
			file:write("000 000 0|")
		end
		file:write("\n")
	end

	return true
end
