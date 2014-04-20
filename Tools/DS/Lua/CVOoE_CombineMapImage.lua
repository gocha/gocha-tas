gd = require("gd")

--[[
local roomId = "M0200"
local roomSegments = {
	{ x = 1, y = 2 },
	{ x = 3, y = 2 },
	{ x = 5, y = 2 },
	{ x = 6, y = 3 },
	{ x = 7, y = 1 },
	{ x = 8, y = 1 },
	{ x = 8, y = 2 }
}
local mapImageSize = { x = 9, y = 3 }
local roomId = "M1200"
local roomSegments = {
	{ x = 1, y = 5 },
	{ x = 10, y = 10 },
	{ x = 10, y = 4 },
	{ x = 10, y = 7 },
	{ x = 12, y = 10 },
	{ x = 12, y = 5 },
	{ x = 14, y = 2 },
	{ x = 15, y = 2 },
	{ x = 3, y = 10 },
	{ x = 3, y = 4 },
	{ x = 4, y = 10 },
	{ x = 4, y = 7 },
	{ x = 5, y = 1 },
	{ x = 5, y = 10 },
	{ x = 5, y = 2 },
	{ x = 5, y = 4 },
	{ x = 6, y = 1 },
	{ x = 6, y = 5 },
	{ x = 6, y = 7 },
	{ x = 7, y = 1 },
	{ x = 7, y = 2 },
	{ x = 8, y = 1 },
	{ x = 8, y = 4 },
	{ x = 9, y = 7 }
}
local mapImageSize = { x = 15, y = 10 }
]]
local roomId = "M0400"
local roomSegments = {
	{ x = 1, y = 1 },
	{ x = 2, y = 1 },
	{ x = 10, y = 1 },
	{ x = 18, y = 1 },
	{ x = 26, y = 1 }
}
local mapImageSize = { x = 26, y = 1 }

local roomSize = { x = 256, y = 192 }

-- create a blank truecolor image
gd.createTrueColorBlank = function(x, y)
	local gdImage = gd.createTrueColor(x, y)
	if gdImage == nil then return nil end

	local colorTrans = gdImage:colorAllocateAlpha(255, 255, 255, 127)
	gdImage:alphaBlending(false)
	gdImage:filledRectangle(0, 0, gdImage:sizeX() - 1, gdImage:sizeY() - 1, colorTrans)
	gdImage:alphaBlending(true)
	gdImage:colorDeallocate(colorTrans)
	return gdImage
end

local gdMap = gd.createTrueColorBlank(mapImageSize.x * roomSize.x, mapImageSize.y * roomSize.y)
gdMap:saveAlpha(true)

for roomSegmentIndex, roomSegment in ipairs(roomSegments) do
	local imageFilename = string.format("%s-%d-%d.png", roomId, roomSegment.x, roomSegment.y)
	print(imageFilename)

	local gdMapPart = gd.createFromPng(imageFilename)
	gdMap:alphaBlending(false)
	gdMap:copyResized(gdMapPart,
		(roomSegment.x - 1) * roomSize.x,
		(roomSegment.y - 1) * roomSize.y,
		0, 0,
		gdMapPart:sizeX(),
		gdMapPart:sizeY(),
		gdMapPart:sizeX(),
		gdMapPart:sizeY()
	)
end

gdMap:png(roomId .. ".png")
