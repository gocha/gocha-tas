
require("gd")
if not bit then require("bit") end

root = ""
sprw, sprh, sprox, sproy = 128, 128, 64, 100
chgf = "julidb.png"
screenshotKey = "F11"

-- return if an image is a truecolor one
gd.isTrueColor = function(im)
	if im == nil then return nil end
	local gdStr = im:gdStr()
	if gdStr == nil then return nil end
	return (gdStr:byte(2) == 254)
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
	if gd.isTrueColor(imsrc) then return imsrc end

	local im = gd.createTrueColor(imsrc:sizeX(), imsrc:sizeY())
	if im == nil then return nil end

	im:alphaBlending(false)
	local trans = im:colorAllocateAlpha(255, 255, 255, 127)
	im:filledRectangle(0, 0, im:sizeX() - 1, im:sizeY() - 1, trans)
	im:copyResized(imsrc, 0, 0, 0, 0, im:sizeX(), im:sizeY(), im:sizeX(), im:sizeY())
	im:alphaBlending(true) -- TODO: set the mode which imsrc uses

	return im
end
-- flip an image about the vertical axis
gd.flipVertical = function(im)
	if im == nil then return nil end
	im:alphaBlending(false)
	for x = 0, im:sizeX() do
		for y = 0, math.floor(im:sizeY()/2) - 1 do
			local c1, c2 = im:getPixel(x, y), im:getPixel(x, im:sizeY()-1-y)
			im:setPixel(x, y, c2)
			im:setPixel(im:sizeX()-1-x, y, c1)
		end
	end
	im:alphaBlending(true) -- TODO: restore the mode
	return im
end
-- flip an image about the horizontal axis
gd.flipHorizontal = function(im)
	if im == nil then return nil end
	im:alphaBlending(false)
	for y = 0, im:sizeY() do
		for x = 0, math.floor(im:sizeX()/2) - 1 do
			local c1, c2 = im:getPixel(x, y), im:getPixel(im:sizeX()-1-x, y)
			im:setPixel(x, y, c2)
			im:setPixel(im:sizeX()-1-x, y, c1)
		end
	end
	im:alphaBlending(true) -- TODO: restore the mode
	return im
end
-- applies vertical and horizontal flip
gd.flipBoth = function(im)
	gd.flipVertical(im)
	gd.flipHorizontal(im)
	return im
end
-- compare two images and extract only different pixels between two images
-- return value is a truecolor gd image with alpha channel
gd.createDiff = function(imFG, imBG, ...)
	local arg = { ... }
	local xOffsetFG, yOffsetFG = 0, 0
	local xOffsetBG, yOffsetBG = 0, 0
	local width, height = math.min(imFG:sizeX(), imBG:sizeX()), math.min(imFG:sizeY(), imBG:sizeY())

	-- parse argument array
	if #arg == 4 then
		-- xOffset, yOffset, width, height
		xOffsetFG, yOffsetFG = arg[1], arg[2]
		xOffsetBG, yOffsetBG = xOffsetFG, yOffsetFG
		width, height = arg[3], arg[4]
	elseif #arg == 6 then
		-- xOffsetFG, yOffsetFG, xOffsetBG, yOffsetBG, width, height
		xOffsetFG, yOffsetFG = arg[1], arg[2]
		xOffsetBG, yOffsetBG = arg[3], arg[4]
		width, height = arg[5], arg[6]
	elseif #arg > 0 then
		error("too few/much arguments")
	end

	-- range check
--	if (xOffsetFG + width > imFG:sizeX()) or (yOffsetFG + height > imFG:sizeY()) then
--		error("foreground image (argument #1) is too small, or illegal offset. " .. width .. "x" .. height .. " from (" .. xOffsetFG .. "," .. yOffsetFG .. ")")
--	end
--	if (xOffsetBG + width > imBG:sizeX()) or (yOffsetBG + height > imBG:sizeY()) then
--		error("background image (argument #2) is too small, or illegal offset. " .. width .. "x" .. height .. " from (" .. xOffsetBG .. "," .. yOffsetBG .. ")")
--	end

	-- create new gd image
	local imDiff = gd.createTrueColorBlank(width, height)
	imDiff:alphaBlending(false)
	imDiff:copyResized(imFG, 0, 0, xOffsetFG, yOffsetFG, width, height, width, height)

	-- pixel-by-pixel processing
	local colTrans = imDiff:colorAllocateAlpha(255, 255, 255, 127)
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			local colFG = imFG:getPixel(x + xOffsetFG, y + yOffsetFG)
			local colBG = imBG:getPixel(x + xOffsetBG, y + yOffsetBG)
			if colFG and colBG then
				if imFG:red(colFG) == imBG:red(colBG) and
				   imFG:green(colFG) == imBG:green(colBG) and
				   imFG:blue(colFG) == imBG:blue(colBG)
				then
					imDiff:setPixel(x, y, colTrans)
				end
			end
		end
	end
	imDiff:alphaBlending(true)
	imDiff:saveAlpha(false)
	return imDiff
end

gdL = gd.convertToTrueColor(gd.createFromPng(root..chgf))
gdR = gd.flipHorizontal(gd.convertToTrueColor(gd.createFromPng(root..chgf)))
gdL:alphaBlending(true)
gdR:alphaBlending(true)
gdL:saveAlpha(true)
gdR:saveAlpha(true)
chgl = gdL:gdStr()
chgr = gdR:gdStr()

function chDrawSprite(x, y, n, reverse)
	local xi, yi = (n % 0x10), math.floor(n / 0x10)
	if not reverse then
		gui.gdoverlay(x, y, chgl, xi * sprw, yi * sprh, sprw, sprh)
	else
		gui.gdoverlay(x, y, chgr, (15 - xi) * sprw, yi * sprh, sprw, sprh)
	end
end

local input_saved = input.get()
local image_save_lock = false
gui.register(function()
	local input_curr = input.get()
	-- ch_visible = bit.band(memory.readbyte(0x020fcc55), 0x80)==0
	room_x = memory.readbyte(0x020f6e20)
	room_y = memory.readbyte(0x020f6e22)
	area = memory.readbyte(0x020f6e25)
	camx = math.floor(memory.readdwordsigned(0x020f707c) / 0x1000)
	camy = math.floor(memory.readdwordsigned(0x020f7080) / 0x1000)
	ch_x = math.floor(memory.readdword(0x020ca95c) / 0x1000)
	ch_y = math.floor(memory.readdword(0x020ca960) / 0x1000)
	ch_dir = ((memory.readbytesigned(0x020ca96a)<0) and -1 or 0)
	ch_spr = memory.readword(0x020ca9a4)
	ch_spr_timer = memory.readbyte(0x020ca9d2)
	ch_hitx1 = memory.readwordsigned(0x0210af42)
	ch_hity1 = memory.readwordsigned(0x0210af44)
	ch_hitx2 = memory.readwordsigned(0x0210af46)
	ch_hity2 = memory.readwordsigned(0x0210af48)
	gui.text(164, 0, string.format("cams: %d %d", camx, camy))
	gui.text(164, 10, string.format("area: %d %d %d", area, room_x, room_y))
	gui.text(164, 20, string.format("SP: %d %04X", ch_spr_timer, ch_spr))
	gui.text(164, 30, string.format("DB: %d, %d", (ch_spr%0x10)*sprw, math.floor(ch_spr/0x10)*sprh))
	if memory.readbyte(0x020c07e8) ~= 2 then
		return
	end
	fade = math.abs(memory.readbytesigned(0x020c0768)) -- 16=white -16=black?
	if fade > 16 then fade = 16 end
	fade = (16 - fade) / 16.0
	-- if ch_visible then
	gui.opacity(0.68*1 * fade)
	chDrawSprite( sprw + ch_x - camx - sprox, ch_y - camy - sproy, ch_spr, ch_dir >= 0)
	chDrawSprite(-sprw + ch_x - camx - sprox, ch_y - camy - sproy, ch_spr, ch_dir < 0)

	-- remove all Soma's shadows
	for i = 0x020df77c, 0x020df85c, 0x10 do
		memory.writedword(i, 0x00000000)
	end

	if input_curr[screenshotKey] and not input_saved[screenshotKey] and not image_save_lock then
		image_save_lock = true

		local gdEmu = gd.createFromPngStr(gd.createFromGdStr(gui.gdscreenshot()):pngStr())
		--gdEmu:png(root.."screenshot.png")
		local gdBG = gd.createFromPng(root.."SpriteRipBG.png")
		local x, y = ch_x - camx - sprox, ch_y - camy - sproy + 192
		local gdDiff = gd.createDiff(gdEmu, gdBG, x, y, sprw, sprh)
		local xOfsDB, yOfsDB = (ch_spr%0x10) * sprw, math.floor(ch_spr/0x10) * sprh
		gdL:alphaBlending(false)
		gdL:copy(gdDiff, xOfsDB, yOfsDB, 0, 0, sprw, sprh)
		gdL:alphaBlending(true)
		gdL:png(root..chgf)
		print(chgf .. ": sprite #" .. ch_spr .. " saved")

		-- update current display
		chgl = gdL:gdStr()

		image_save_lock = false
	end

	input_saved = input_curr

	gui.opacity(1 * fade)
	gui.box(ch_x - camx - sprox, ch_y - camy - sproy, ch_x - camx - sprox + sprw - 1, ch_y - camy - sproy + sprh - 1, "clear", "#ff000080")
	-- gui.box(ch_hitx1 - camx, ch_hity1 - camy, ch_hitx2 - camx, ch_hity2 - camy, "clear", "green")
	gui.opacity(1 * fade)
	-- end
end)
