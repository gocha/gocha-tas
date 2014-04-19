-- script for semi-automated sprite ripping

require("gd")

root = ""
outdir = root
sprw, sprh, sprox, sproy = 128, 128, 64, 100
targetAniIndex = 0x01

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
		for y = 0, math.floor(im:sizeY()/2) do
			local ct, cb = im:getPixel(x, y), im:getPixel(x, im:sizeY()-1-y)
			im:setPixel(x, y, cb)
			im:setPixel(im:sizeX()-1-x, y, ct)
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
		for x = 0, math.floor(im:sizeX()/2) do
			local cl, cr = im:getPixel(x, y), im:getPixel(im:sizeX()-1-x, y)
			im:setPixel(x, y, cr)
			im:setPixel(im:sizeX()-1-x, y, cl)
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

gdback = gd.createFromPng(root.."back.png")
sprDBw, sprDBh = 2048, 3328
gdlarge = gd.createTrueColorBlank(sprDBw, sprDBh)
gdlarge:saveAlpha(true)
gdlarge:alphaBlending(true)
function exitFunc()
	if gdlarge ~= nil then
		gdlarge:png(outdir.."spritedb.png")
		print("Saved sprite database")
	end
end
emu.registerexit(exitFunc)

SPRITE_ANIINDEX_ADDR = 0x0210989c
SPRITE_ANICOUNT_ADDR = 0x0210989e
SPRITE_INDEX_ADDR = 0x021098a4
SPRITE_TIMER_ADDR = 0x021098a2
CAMERA_POS_X_ADDR = 0x021000bc
CAMERA_POS_Y_ADDR = 0x021000c0
PLAYER_POS_X_ADDR = 0x02109850
PLAYER_POS_Y_ADDR = 0x02109854

memory.writeword(SPRITE_ANIINDEX_ADDR, targetAniIndex)
memory.writeword(SPRITE_ANICOUNT_ADDR, 0xffff)
memory.writebyte(SPRITE_TIMER_ADDR, 1)

delayLevel = 2
mem = {}
for i = 1, delayLevel + 1 do
	mem[i] = {}
end
function stmem()
	for i = 1, delayLevel do
		mem[i+1] = copytable(mem[i])
	end
	mem[1].aniIndex = memory.readword(SPRITE_ANIINDEX_ADDR)
	mem[1].aniCount = memory.readwordsigned(SPRITE_ANICOUNT_ADDR)
	mem[1].sprIndex = memory.readword(SPRITE_INDEX_ADDR)
	mem[1].aniTimer = memory.readword(SPRITE_TIMER_ADDR)
	mem[1].camerax = math.floor(memory.readdwordsigned(CAMERA_POS_X_ADDR) / 0x1000)
	mem[1].cameray = math.floor(memory.readdwordsigned(CAMERA_POS_Y_ADDR) / 0x1000)
	mem[1].playerx = math.floor(memory.readdword(PLAYER_POS_X_ADDR) / 0x1000)
	mem[1].playery = math.floor(memory.readdword(PLAYER_POS_Y_ADDR) / 0x1000)
	for i = 2, delayLevel + 1 do
		if mem[i] == nil then
			mem[i] = copytable(mem[1])
		end
	end
end
emu.frameadvance()
stmem()
while mem[1].aniIndex == targetAniIndex do
	if mem[1].sprIndex ~= mem[2].sprIndex then
		direction = memory.readbytesigned(0x02109894)
		if direction >= 0 then
			error("Face left, please.")
		end

		local loopy = 4
		memory.writebyte(SPRITE_TIMER_ADDR, loopy + 2)
		for i = 1, loopy do
			emu.frameadvance()
		end

		spriteDBx = (mem[1].sprIndex % 0x10)
		spriteDBy = math.floor(mem[1].sprIndex / 0x10)
		pngfname = string.format("%04x(%d,%d).png", mem[1].sprIndex,
			spriteDBx * sprw, spriteDBy * sprh)
		trimrect = {
			left   = mem[1].playerx - mem[1].camerax - sprox,
			top    = 192 + mem[1].playery - mem[1].cameray - sproy,
			right  = mem[1].playerx - mem[1].camerax - sprox + sprw - 1,
			bottom = 192 + mem[1].playery - mem[1].cameray - sproy + sprh - 1
		}
		if trimrect.left < 0 or trimrect.right >= 256 or
			trimrect.top < 0 or trimrect.bottom >= 384 then
			error("Illegal trimming rectangle")
		end

		gdtarget = gd.createFromGdStr(gui.gdscreenshot())
		local fillcolor = gdtarget:colorAllocateAlpha(255, 255, 255, 127)
		for y = trimrect.top, trimrect.bottom do
			for x = trimrect.left, trimrect.right do
				local bc = gdback:getPixel(x, y)
				local tc = gdtarget:getPixel(x, y)
				local br, bg, bb = gdback:red(bc), gdback:green(bc), gdback:blue(bc)
				local tr, tg, tb = gdtarget:red(tc), gdtarget:green(tc), gdtarget:blue(tc)
				if br == tr and bg == tg and bb == tb then
					-- transparent
					gdtarget:setPixel(x, y, fillcolor)
				else
					-- pixel: reset alpha
					local c = gdtarget:colorAllocateAlpha(tr, tg, tb, 0)
					gdtarget:setPixel(x, y, c)
				end
			end
		end
		gdout = gd.createTrueColorBlank(sprw, sprh)
		gdout:saveAlpha(true)
		gdout:alphaBlending(true)
		gdout:copy(gdtarget, 0, 0, trimrect.left, trimrect.top, sprw, sprh)
		if gdlarge ~= nil then
			if (spriteDBx * sprw + sprw) > sprDBw or (spriteDBy * sprh + sprh) > sprDBh then
				error("Expand sprite database width/height, please?")
			end
			gdlarge:copy(gdout, spriteDBx * sprw, spriteDBy * sprh,
				0, 0, sprw, sprh)
		else
			gdout:png(outdir..pngfname)
		end
		print(string.format("Output sprite $%04x", mem[1].sprIndex))

		-- memory.writebyte(SPRITE_TIMER_ADDR, 1)
	end

	emu.frameadvance()
	stmem()
end
exitFunc()
emu.registerexit(nil)
