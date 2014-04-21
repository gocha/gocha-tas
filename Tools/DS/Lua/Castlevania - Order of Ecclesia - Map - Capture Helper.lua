
gd = require("gd")

local curRoomId = ""
local gdMap = nil

if not gui.setgfx3dvisibility then
	gui.setgfx3dvisibility = function(gfx3dStart, gfx3dEnd)
		return -- do nothing, this is just a dummy.
	end
end

function getScreenSize()
	return 256, 192
end

local cappt = { x = 0, y = 0 }
local capsx, capsy = getScreenSize()
capsx, capsy = capsx - cappt.x, capsy - cappt.y

function getRoomId()
	local x = memory.readbyte(0x020ffcac)
	local y = memory.readbyte(0x020ffcae)
	return string.format("%04x-%d-%d", memory.readword(0x020ffcb8), x, y)
	-- return string.format("%04x-%08x", memory.readword(0x020ffcb8), memory.readdword(0x020ffc9c))
end

function getRoomSize()
	if getRoomId() == "" then
		return 0, 0
	end

	-- see also: 020ffcxx
	local sx, sy = getScreenSize()
	local xcount = memory.readbyte(0x0213a5f9)
	local ycount = memory.readbyte(0x0213a5fb) + 1
	return xcount * sx, ycount * sy
end

function getCameraPosition()
	local x = math.floor(memory.readdwordsigned(0x021000bc) / 0x1000)
	local y = math.floor(memory.readdwordsigned(0x021000c0) / 0x1000)
	return x, y
end

function isScreenAvailable()
	local gamemode = memory.readbyte(0x020d88d0)
	local fade = math.abs(memory.readbytesigned(0x02100ad8))
	if gamemode ~= 0 or fade ~= 0 or memory.readbyte(0x0210114e) ~= 0 then
		return false
	end

	return true
end

function applyCheats()
	memory.writebyte(0x021098c1, 2) -- make Shanoa invisible
	memory.writebyte(0x021098e5, 60)-- make Shanoa invulnerable
	memory.writebyte(0x021098e6, 60)
	memory.writebyte(0x021098e7, 60)
end

function removeCheats()
	memory.writebyte(0x021098c1, 0) -- make Shanoa visible
end

-- create a blank truecolor image
gd.createTrueColorBlank = function(x, y)
	local im = gd.createTrueColor(x, y)
	if im == nil then return nil end

	local trans = im:colorAllocateAlpha(255, 255, 255, 127)
	im:alphaBlending(false)
	im:filledRectangle(0, 0, im:sizeX() - 1, im:sizeY() - 1, trans)
	im:alphaBlending(true) -- TODO: restore the blending mode to default
	return im
end
-- return a converted image (source image won't be changed)
gd.convertToTrueColor = function(imsrc)
	if imsrc == nil then return nil end
--	if gd.isTrueColor(imsrc) then return imsrc end

	local im = gd.createTrueColor(imsrc:sizeX(), imsrc:sizeY())
	if im == nil then return nil end

	im:alphaBlending(false)
	local trans = im:colorAllocateAlpha(255, 255, 255, 127)
	im:filledRectangle(0, 0, im:sizeX() - 1, im:sizeY() - 1, trans)
	im:copy(imsrc, 0, 0, 0, 0, im:sizeX(), im:sizeY())
	im:alphaBlending(true) -- TODO: set the mode which imsrc uses

	return im
end

emu.registerbefore(function()
	applyCheats()
end)

local screenmoving = false
local prevcamerax1, prevcameray1 = 0, 0
local prevcamerax2, prevcameray2 = 0, 0
local prevcamerax3, prevcameray3 = 0, 0
emu.registerafter(function()
	local camerax, cameray = getCameraPosition()
	screenmoving = (camerax ~= prevcamerax1 or cameray ~= prevcameray1)
		or (prevcamerax1 ~= prevcamerax2 or prevcameray1 ~= prevcameray2)
		or (prevcamerax2 ~= prevcamerax3 or prevcameray2 ~= prevcameray3)
	prevcamerax3, prevcameray3 = prevcamerax2, prevcameray2
	prevcamerax2, prevcameray2 = prevcamerax1, prevcameray1
	prevcamerax1, prevcameray1 = camerax, cameray

	if isScreenAvailable() then
		local newRoomId = getRoomId()
		local roomSizeX, roomSizeY = getRoomSize()
		if newRoomId ~= "" and (newRoomId ~= curRoomId or gdMap:sizeX() ~= roomSizeX or gdMap:sizeY() ~= roomSizeY) then
			if curRoomId ~= "" and gdMap then
				-- save the last image
				--gdMap:png(getRoomId() .. ".png")
			end

			curRoomId = newRoomId

			-- create a new canvas
			gdMap = gd.createTrueColorBlank(roomSizeX, roomSizeY)
			gdMap:saveAlpha(false)
			gdMap:alphaBlending(false)
		end
	end
end)

local keys = { {}, {} }
gui.register(function()
	keys[1] = input.get()
	if isScreenAvailable() then
		local igframe = memory.readdword(0x02100374)
		local camerax, cameray = getCameraPosition()
		local left = memory.readwordsigned(0x02128c2e) - camerax
		local top = memory.readwordsigned(0x02128c30) - cameray
		local right = memory.readwordsigned(0x02128c32) - camerax
		local bottom = memory.readwordsigned(0x02128c34) - cameray
		gui.box(left, top, right, bottom, "#ffffff80", "#ffffffff")

		gui.text(4, 34, getRoomId())
		gui.text(4, 44, string.format("%d,%d", getRoomSize()))
		gui.text(4, 54, string.format("%d,%d", getCameraPosition()))

		local captureThisFrame = gdMap and not screenmoving and keys[1].F11
		if captureThisFrame then
			local gdSrc = gd.createFromGdStr(gui.gdscreenshot())
			gdSrc:saveAlpha(false)
			gdSrc:alphaBlending(false)
			gd.copy(gdMap, gdSrc, camerax + cappt.x, cameray + cappt.y, 0 + cappt.x, 192 + cappt.y, capsx, capsy)
			-- save the last image
		end
		if captureThisFrame then
			gdMap:png(getRoomId() .. ".png")
		end
	end
	keys[2] = keys[1]
end)

emu.registerexit(function()
	removeCheats()
end)
