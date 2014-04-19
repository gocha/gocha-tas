
require("gd")
if not bit then require("bit") end

root = ""
sprw, sprh, sprox, sproy = 128, 128, 64, 120
jogf, chgf = "jonadb.png", "chardb.png"
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
	im:copyResampled(imsrc, 0, 0, 0, 0, im:sizeX(), im:sizeY(), im:sizeX(), im:sizeY())
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
	if (xOffsetFG + width > imFG:sizeX()) or (yOffsetFG + height > imFG:sizeY()) then
		error("foreground image (argument #1) is too small, or illegal offset. " .. width .. "x" .. height .. " from (" .. xOffsetFG .. "," .. yOffsetFG .. ")")
	end
	if (xOffsetBG + width > imBG:sizeX()) or (yOffsetBG + height > imBG:sizeY()) then
		error("background image (argument #2) is too small, or illegal offset. " .. width .. "x" .. height .. " from (" .. xOffsetBG .. "," .. yOffsetBG .. ")")
	end

	-- create new gd image
	local imDiff = gd.createTrueColor(width, height)
	imDiff:alphaBlending(false)
	imDiff:copyResized(imFG, 0, 0, xOffsetFG, yOffsetFG, width, height, width, height)

	-- pixel-by-pixel processing
	local colTrans = imDiff:colorAllocateAlpha(255, 255, 255, 127)
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			local colFG = imFG:getPixel(x + xOffsetFG, y + yOffsetFG)
			local colBG = imBG:getPixel(x + xOffsetBG, y + yOffsetBG)
			if imFG:red(colFG) == imBG:red(colBG) and
			   imFG:green(colFG) == imBG:green(colBG) and
			   imFG:blue(colFG) == imBG:blue(colBG)
			then
				imDiff:setPixel(x, y, colTrans)
			end
		end
	end
	imDiff:alphaBlending(true)
	imDiff:saveAlpha(false)
	return imDiff
end

gdJoL = gd.convertToTrueColor(gd.createFromPng(root..jogf))
gdJoR = gd.flipHorizontal(gd.convertToTrueColor(gd.createFromPng(root..jogf)))
gdChL = gd.convertToTrueColor(gd.createFromPng(root..chgf))
gdChR = gd.flipHorizontal(gd.convertToTrueColor(gd.createFromPng(root..chgf)))
gdJoL:alphaBlending(true)
gdJoR:alphaBlending(true)
gdChL:alphaBlending(true)
gdChR:alphaBlending(true)
gdJoL:saveAlpha(true)
gdJoR:saveAlpha(true)
gdChL:saveAlpha(true)
gdChR:saveAlpha(true)

jogl = gdJoL:gdStr()
jogr = gdJoR:gdStr()
chgl = gdChL:gdStr()
chgr = gdChR:gdStr()

function joDrawSprite(x, y, n, reverse)
	local xi, yi = (n % 0x10), math.floor(n / 0x10)
	if not reverse then
		gui.gdoverlay(x, y, jogl, xi * sprw, yi * sprh, sprw, sprh)
	else
		gui.gdoverlay(x, y, jogr, (15 - xi) * sprw, yi * sprh, sprw, sprh)
	end
end

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
	jo_visible = bit.band(memory.readbyte(0x020fcaf5), 0x80)==0
	ch_visible = bit.band(memory.readbyte(0x020fcc55), 0x80)==0
	room_x = memory.readbyte(0x02111778)
	room_y = memory.readbyte(0x0211177a)
	area = memory.readbyte(0x02111785)
	-- world: 02111784
	-- camera 021119fc 02111a08 02111f90
	-- jo ani sheet 020fcaf0
	-- jo ani pat#? 020fcafc
	-- jo ani pat#? 020fcafe
	-- jo ani timer 020fcb02
	-- ch ani sheet 020fcc50 ...
	-- jo blinking? 020fca9f
	-- ch blinking? 020fcbff
	camx = math.floor(memory.readdwordsigned(0x02111a08) / 0x1000)
	camy = math.floor(memory.readdwordsigned(0x02111a0c) / 0x1000)
	jo_x = math.floor(memory.readdword(0x020FCBA4) / 0x1000)
	jo_y = math.floor(memory.readdword(0x020FCBA8) / 0x1000)
	jo_dir = ((memory.readbytesigned(0x020ff174)<0) and -1 or 0)
	jo_spr = memory.readword(0x020fcb04)
	jo_hitx1 = memory.readwordsigned(0x0213296e)
	jo_hity1 = memory.readwordsigned(0x02132970)
	jo_hitx2 = memory.readwordsigned(0x02132972)
	jo_hity2 = memory.readwordsigned(0x02132974)
	ch_x = math.floor(memory.readdword(0x020FCD04) / 0x1000)
	ch_y = math.floor(memory.readdword(0x020FCD08) / 0x1000)
	ch_dir = ((memory.readbytesigned(0x020ffdd4)<0) and -1 or 0)
	ch_spr = memory.readword(0x020fcc64)
	ch_hitx1 = memory.readwordsigned(0x02132982)
	ch_hity1 = memory.readwordsigned(0x02132984)
	ch_hitx2 = memory.readwordsigned(0x02132986)
	ch_hity2 = memory.readwordsigned(0x02132988)
	my_x = jo_x
	my_y = jo_y
	my_dir = jo_dir
	my_spr = jo_spr
	my_hitx1 = jo_hitx1
	my_hity1 = jo_hity1
	my_hitx2 = jo_hitx2
	my_hity2 = jo_hity2
	mygd = gdJoL
	mygdFilename = jogf
	gui.text(164, 0, string.format("cams: %d %d", camx, camy))
	gui.text(164, 10, string.format("area: %d %d %d", area, room_x, room_y))
	if jo_visible then
		gui.text(164, 20, string.format("J: %d %04X", memory.readbyte(0x020fcb02), jo_spr))
		gui.text(164, 30, string.format("J: %d, %d", (jo_spr%0x10)*sprw, math.floor(jo_spr/0x10)*sprh))
	end
	if ch_visible then
		gui.text(164, 40, string.format("C: %d %04X", memory.readbyte(0x020fcc62), ch_spr))
		gui.text(164, 50, string.format("C: %d, %d", (ch_spr%0x10)*sprw, math.floor(ch_spr/0x10)*sprh))
	end
	if memory.readbyte(0x020f6284) ~= 2 then
		return
	end
	fade = math.abs(memory.readbytesigned(0x020f61fc)) -- 16=white -16=black?
	if fade > 16 then fade = 16 end
	fade = (16 - fade) / 16.0
	if jo_visible then
		gui.opacity(0.68*1 * fade)
		joDrawSprite( sprw + jo_x - camx - sprox, jo_y - camy - sproy, jo_spr, jo_dir >= 0)
		joDrawSprite(-sprw + jo_x - camx - sprox, jo_y - camy - sproy, jo_spr, jo_dir < 0)

		gui.opacity(1 * fade)
		gui.box(jo_x - camx - sprox, jo_y - camy - sproy, jo_x - camx - sprox + sprw - 1, jo_y - camy - sproy + sprh - 1, "clear", "#ff000080")
		-- gui.box(jo_hitx1 - camx, jo_hity1 - camy, jo_hitx2 - camx, jo_hity2 - camy, "clear", "green")
		gui.opacity(1 * fade)
	end
	if ch_visible then
		gui.opacity(0.68*1 * fade)
		chDrawSprite( sprw + ch_x - camx - sprox, ch_y - camy - sproy, ch_spr, ch_dir >= 0)
		chDrawSprite(-sprw + ch_x - camx - sprox, ch_y - camy - sproy, ch_spr, ch_dir < 0)

		gui.opacity(1 * fade)
		gui.box(ch_x - camx - sprox, ch_y - camy - sproy, ch_x - camx - sprox + sprw - 1, ch_y - camy - sproy + sprh - 1, "clear", "#ff000080")
		-- gui.box(ch_hitx1 - camx, ch_hity1 - camy, ch_hitx2 - camx, ch_hity2 - camy, "clear", "green")
		gui.opacity(1 * fade)
	end

	if input_curr[screenshotKey] and not input_saved[screenshotKey] and not image_save_lock then
		image_save_lock = true

		local gdEmu = gd.createFromPngStr(gd.createFromGdStr(gui.gdscreenshot()):pngStr())
		--gdEmu:png(root.."screenshot.png")
		local gdBG = gd.createFromPng(root.."SpriteRipBG.png")
		local x, y = my_x - camx - sprox, my_y - camy - sproy + 192
		local gdDiff = gd.createDiff(gdEmu, gdBG, x, y, sprw, sprh)
		local xOfsDB, yOfsDB = (my_spr%0x10) * sprw, math.floor(my_spr/0x10) * sprh
		mygd:alphaBlending(false)
		mygd:copy(gdDiff, xOfsDB, yOfsDB, 0, 0, sprw, sprh)
		mygd:alphaBlending(true)
		mygd:png(root..mygdFilename)
		print(mygdFilename .. ": sprite #" .. my_spr .. " saved")

		-- update current display
		jogl = gdJoL:gdStr()

		image_save_lock = false
	end

	input_saved = input_curr
end)
