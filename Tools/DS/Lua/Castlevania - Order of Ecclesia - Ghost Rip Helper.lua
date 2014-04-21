
require("gd")
if not bit then require("bit") end

root = ""
sprw, sprh, sprox, sproy = 128, 128, 64, 100
chgf = "shanoadb.png"

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
	im:copy(imsrc, 0, 0, 0, 0, im:sizeX(), im:sizeY())
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

chgl = gd.createFromPng(root..chgf):gdStr()
chgr = gd.flipHorizontal(gd.createFromPng(root..chgf)):gdStr()

function chDrawSprite(x, y, n, reverse)
	local xi, yi = (n % 0x10), math.floor(n / 0x10)
	if not reverse then
		gui.gdoverlay(x, y, chgl, xi * sprw, yi * sprh, sprw, sprh)
	else
		gui.gdoverlay(x, y, chgr, (15 - xi) * sprw, yi * sprh, sprw, sprh)
	end
end

gui.register(function()
	room_x = memory.readbyte(0x020ffcac)
	room_y = memory.readbyte(0x020ffcae)
	area = memory.readbyte(0x020ffcb9)
	camx = math.floor(memory.readdwordsigned(0x021000bc) / 0x1000)
	camy = math.floor(memory.readdwordsigned(0x021000c0) / 0x1000)
	ch_x = math.floor(memory.readdword(0x02109850) / 0x1000)
	ch_y = math.floor(memory.readdword(0x02109854) / 0x1000)
	ch_dir = ((memory.readbytesigned(0x02109894)<0) and -1 or 0)
	ch_spr = memory.readword(0x021098a4)
	ch_spr_timer = memory.readbyte(0x021098a2)
	ch_hitx1 = memory.readwordsigned(0x02128c2e)
	ch_hity1 = memory.readwordsigned(0x02128c30)
	ch_hitx2 = memory.readwordsigned(0x02128c32)
	ch_hity2 = memory.readwordsigned(0x02128c34)
	-- fade_in = memory.readwordsigned(0x02100ab2) > 0
	fade = math.floor(math.abs(memory.readdwordsigned(0x02100b00)/0x1000))
	if fade > 16 then fade = 16 end
	fade = (16 - fade) / 16.0
	if memory.readbyte(0x020d88d0) ~= 0 then
		return
	end
	gui.opacity(0.5 * fade + 0.5)
	gui.text(164, 0, string.format("cams: %d %d", camx, camy))
	gui.text(164, 10, string.format("area: %d %d %d", area, room_x, room_y))
	gui.text(164, 20, string.format("SP: %d %04X", ch_spr_timer, ch_spr))
	gui.text(164, 30, string.format("DB: %d, %d", (ch_spr%0x10)*sprw, math.floor(ch_spr/0x10)*sprh))

	gui.opacity(0.68*1 * fade)
	chDrawSprite( sprw + ch_x - camx - sprox, ch_y - camy - sproy, ch_spr, ch_dir >= 0)
	chDrawSprite(-sprw + ch_x - camx - sprox, ch_y - camy - sproy, ch_spr, ch_dir < 0)

	gui.opacity(1 * fade)
	gui.box(ch_x - camx - sprox, ch_y - camy - sproy, ch_x - camx - sprox + sprw - 1, ch_y - camy - sproy + sprh - 1, "clear", "#ff000080")
	-- gui.box(ch_hitx1 - camx, ch_hity1 - camy, ch_hitx2 - camx, ch_hity2 - camy, "clear", "green")
	gui.opacity(1 * fade)
end)
