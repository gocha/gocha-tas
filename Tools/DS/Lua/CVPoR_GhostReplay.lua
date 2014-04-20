-- Castlevania - Portrait of Ruin
-- Ghost replay script, some parts come from amaurea's script.

-- Directory prefix
root_dir = ""

-- Ghost definitions
ghost_dumps  = { "[1437M].ghost", "[1293M].ghost" }

-- Timing options
sync_mode    = "ingame"
display_mode = "ingame" -- NYI
offset_mode  = "room"

show_delays = true

-- Graphics options
own_color = "white"
ghost_color = { "red", "blue" }
ghost_opacity = 0.75

-- These require gd
ghost_gfx = 1 -- nil to turn off. Array to specify individually
pose_info = { { "jonadb.png", "chardb.png", 128, 128, 64, 120 } }

-- Draw log dump for AviUtl
drawlog = nil--io.open(root_dir .. "aviutl_guidraw.lua", "w") -- nil to turn off. File handle to dump.

-- Main parameters end here
if ghost_gfx then require "gd" end

-- gui.gdoverlay with screen clipping
gui.gdoverlayclip = function(...)
	local arg = {...}
	local index = 1
	local x, y = 0, 0
	local screentype = "bottom"

	if type(arg[index]) == "string" and (arg[index] == "top" or arg[index] == "bottom" or arg[index] == "both") then
		screentype = arg[index]
		index = index + 1
	end
	if type(arg[index]) == "number" then
		x, y = arg[index], arg[index+1]
		index = index + 2
	end
	local gdStr = arg[index]
	index = index + 1
	local hasSrcRect = ((#arg - index + 1) > 1)
	local sx, sy, sw, sh = 0, 0, 65535, 65535
	if hasSrcRect then
		sx, sy, sw, sh = arg[index], arg[index+1], arg[index+2], arg[index+3]
		index = index + 4
	end
	local opacity = ((arg[index] ~= nil) and arg[index] or 1.0)

	-- screen clip
	if screentype == "top" then
		if y+sh > 0 then sh = -y end
	elseif screentype == "bottom" then
		if y < 0 then sy, sh, y = sy - y, sh + y, 0 end
	end

	gui.gdoverlay(x, y, gdStr, sx, sy, sw, sh, opacity)
end

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

-- Variables that must be saved in savestates
last_igframe = 0 -- Used to find out if this frame should be skipped
last_room    = 0
last_transition = { 0, 0, 0 } -- Used for room sync: room, frame, igframe
fcount = 1 -- Frames since script start. Used in place of emu.framecount

emudata = {}

-- Frames: For both real frames and ingame frames, the first frame of
-- is number 1. All frames before this are labeled 0.

-- The main function. It is run every frame.
function main()
	frame = framecount()
	room = get_room()
	updateEmuFrameState()

	fcount = fcount + 1
	last_igframe = igframe()
	if room ~= last_room then
		last_transition = { last_room, frame, igframe() }
	end
	last_room = room

	if drawlog then
		update_screen(true)
		drawlog:write("\n")
	end
end

function update_screen(logonly)
	room = get_room()
	-- for index, ghost in ipairs(ghosts) do repeat
	for index = #ghosts, 1, -1 do ghost = ghosts[index] repeat
		local sframe  = syncframe()
		local gframe  = sync2frame(sframe, ghost)
		local osframe = offset(sframe, ghost)
		local ogframe = osframe and sync2frame(osframe, ghost)

		if(ogframe and room == ghost.data[ogframe].room) then
			if ghost.gfx then draw_ghost_gfx(ghost, ogframe, index, logonly) end
		end
		if show_delays and osframe then draw_delay(ghost,osframe-sframe, index) end
	until true end
end

function getFrameState()
	local e = {}
	e.rframe = emu.framecount()
	e.lagcount = emu.lagcount()
	e.lagged = (emu.lagged() and 1 or 0)
	e.igframe = memory.readdword(0x021119e0)
	e.mode = memory.readbyte(0x020f6284)
	e.fade = memory.readbytesigned(0x020f61fc)
	e.region = memory.readbyte(0x02111785)
	e.roomx, e.roomy = memory.readbyte(0x02111778), memory.readbyte(0x0211177a)
	e.scrollx, e.scrolly = memory.readdwordsigned(0x021119fc), memory.readdwordsigned(0x02111a00)
	e.jonathan = {
		posx = memory.readdwordsigned(0x020fcab0),
		posy = memory.readdwordsigned(0x020fcab4),
		hitx1 = memory.readwordsigned(0x0213296e),
		hity1 = memory.readwordsigned(0x02132970),
		hitx2 = memory.readwordsigned(0x02132972),
		hity2 = memory.readwordsigned(0x02132974),
		dir = memory.readbytesigned(0x020ff174),
		pose = memory.readword(0x020fcb04),
		blink = memory.readbyte(0x020fca9f),
		visual = memory.readbyte(0x020fcaf5)
	}
	e.charlotte = {
		posx = memory.readdwordsigned(0x020fcc10),
		posy = memory.readdwordsigned(0x020fcc14),
		hitx1 = memory.readwordsigned(0x02132982),
		hity1 = memory.readwordsigned(0x02132984),
		hitx2 = memory.readwordsigned(0x02132986),
		hity2 = memory.readwordsigned(0x02132988),
		dir = memory.readbytesigned(0x020ffdd4),
		pose = memory.readword(0x020fcc64),
		blink = memory.readbyte(0x020fcbff),
		visual = memory.readbyte(0x020fcc55)
	}
	adjustFrameState(e)
	return e
end

function getFrameStateFromFile(file)
	local tmp = file:read("*n")
	if tmp == nil then
		return nil
	end

	local e = {}
	e.rframe = tmp
	e.lagcount = file:read("*n")
	e.lagged = file:read("*n")
	e.igframe = file:read("*n")
	e.mode = file:read("*n")
	e.fade = file:read("*n")
	e.region = file:read("*n")
	e.roomx, e.roomy = file:read("*n"), file:read("*n")
	e.scrollx, e.scrolly = file:read("*n"), file:read("*n")
	e.jonathan = {
		posx = file:read("*n"),
		posy = file:read("*n"),
		hitx1 = file:read("*n"),
		hity1 = file:read("*n"),
		hitx2 = file:read("*n"),
		hity2 = file:read("*n"),
		dir = file:read("*n"),
		pose = file:read("*n"),
		blink = file:read("*n"),
		visual = file:read("*n")
	}
	e.charlotte = {
		posx = file:read("*n"),
		posy = file:read("*n"),
		hitx1 = file:read("*n"),
		hity1 = file:read("*n"),
		hitx2 = file:read("*n"),
		hity2 = file:read("*n"),
		dir = file:read("*n"),
		pose = file:read("*n"),
		blink = file:read("*n"),
		visual = file:read("*n")
	}
	adjustFrameState(e)
	return e
end

function adjustFrameState(e)
	if not e then return e end
	e.lagged = boolnum(e.lagged)
	e.room = join_room(e.region, e.roomx, e.roomy)
	local players = { e.jonathan, e.charlotte }
	for i, player in ipairs(players) do
		player.blink = boolnum(player.blink)
		player.visible = ((math.floor(player.visual / 0x80) % 2) == 0)

		local x, y
		x = math.floor((player.posx - e.scrollx) / 0x1000) - 32
		y = math.floor((player.posy - e.scrolly) / 0x1000) - 32
		player.offscreen = (x <= -64 or y <= -64 or x >= 256 or y >= 192)
	end
	return e
end

function updateEmuFrameState()
	local data = getFrameState()
	if emudata[1] == nil then
		-- setup
		for i = 1, 4 do
			emudata[i] = data
		end
	else
		if data.igframe ~= emudata[1].igframe then
			for i = 4, 2, -1 do
				emudata[i] = emudata[i-1]
			end
		end
		emudata[1] = data
	end
end

-- Main data table. An array of tables for each ghost.
-- Each ghost has the following entries:
-- Offset: scalar, number of sync frames to shift by
-- Framenums: array, translates from sync frames to real frames
-- Transitions: dictionary of { from, to } -> array of real frames,
--              from and two might have to be encoded as strings or
--              put into one number (need 5 bytes, and double should
--              provide enough
-- Data: frame -> x, y, region, roomx, roomy, pose
-- Gfx: Scalar. Which of the gfx sets this ghost uses
ghosts = {}
pose_data = {}

function init()
	set_sync(sync_mode)
	set_display(display_mode)
	set_offset(offset_mode)
	for i,filename in ipairs(ghost_dumps) do
		local ghost = readghost(root_dir .. filename)
		ghost.gfx = tabnum(ghost_gfx, i)
		ghost.color = tabnum(ghost_color, i)
		ghost.opacity = tabnum(ghost_opacity, i)
		table.insert(ghosts, ghost)
	end
	if ghost_gfx then for i,info in ipairs(pose_info) do
		table.insert(pose_data, read_pose(info))
	end end
	updateEmuFrameState()
	-- Set up saves
	-- savestate.registersave(function() return last_igframe, last_room, last_transition[1], last_transition[2], last_transition[3], fcount end)
	-- savestate.registerload(function(_,a,b,c,d,e,f) last_igframe, last_room, last_transition[1], last_transition[2], last_transition[3], fcount = a, b, c, d, e, f end)
	-- Register main callbacks
	emu.registerafter(main)
	gui.register(update_screen)
end

function readghost(filename)
	local ghost = {}
	local file = io.open(filename, "r")
	if file == nil then
		error('file not found "' .. tostring(filename) .. '"')
	end
	ghost.offset = 0
	ghost.data = {}
	local e = getFrameStateFromFile(file)
	while e do
		table.insert(ghost.data,e)
		e = getFrameStateFromFile(file)
	end
	-- Fix the broken first part
	fix_data(ghost.data)
	-- Now extract the information we want
	ghost.syncframes = build_sync(ghost)
	ghost.transitions = build_transitions(ghost)
	return ghost
end

function boolnum(v)
	return v and (v ~= 0)
end

function tabnum(something, index)
	if type(something) == "table" then
		return something[index]
	else
		return something
	end
end

function make_frame2sync(key)
	if key == "real" or key == "realtime" then
		return function(rframe, ghost) return rframe end
	elseif key == "game" or key == "ingame" then
		return function(rframe, ghost) return ghost.data[rframe].igframe end
	end
end
function make_sync2frame(key)
	return function(frame, ghost) return ghost.syncframes[frame] end
end

function framecount()
	return emu.framecount()
end
function igframe()
	return emudata[1].igframe
end
function make_syncframe(key)
	if key == "real" or key == "realtime" then
		return framecount
	elseif key == "game" or key == "ingame" then
		return igframe
	end
end
function make_display(key)
	if key == "real" or key == "realtime" then
		return function() return true end
	elseif key == "game" or key == "ingame" then
		return function() return igframe() ~= last_igframe end
	end
end
function make_offset(key)
	if key == "none" then
		return function(sframe, ghost) return sframe end
	elseif key == "room" then
		return function(sframe, ghost)
			local last_room, last_frame = get_last_trans()
			local t = find_transition(ghost, last_room, room, last_frame)
			return t and sframe - last_frame + t
		end
	end
end
function make_last_trans(key)
	if key == "real" or key == "realtime" then
		return function() return last_transition[1], last_transition[2] end
	elseif key == "game" or key == "ingame" then
		return function() return last_transition[1], last_transition[3] end
	end
end

function nsync(ghost) return #ghost.syncframes end
function nframe(ghost) return #ghost.data end

function set_sync(mode)
	frame2sync = make_frame2sync(mode)
	sync2frame = make_sync2frame(mode)
	syncframe  = make_syncframe(mode)
	get_last_trans = make_last_trans(mode)
end

function set_display(mode)
	display    = make_display(mode)
end

function set_offset(mode)
	offset     = make_offset(mode)
end

function fix_data(data)
	return -- Probably it's not needed
end

-- This assumes that igframe changes by a step of +1 only
function build_sync(ghost)
	local res = {}
	local last = 0
	local lastframe = 1
	for i = 1, nframe(ghost) do
		-- HACK: actually, igframe sometimes decreased by reset,
		-- and sometimes increased by 2 due to mysterious lags.
		-- so we do something weird here to prevent desyncs :P
		local diff = frame2sync(i, ghost) - last
		if diff > 0 then
			if diff < 4 then -- if differences are small enough
				-- duplicate the nearest frame
				for j = 1, diff - 1 do
					table.insert(res,lastframe)
				end
				table.insert(res,i)
			else
				table.insert(res,i)
			end
			last = frame2sync(i,ghost)
			lastframe = i
		end
	end
	return res
end

function get_room()
	return join_room(emudata[1].region, emudata[1].roomx, emudata[1].roomy)
end
function join_room(region, x, y)
	return bit.bor(bit.lshift(region, 16), bit.lshift(x, 8), y)
end
function split_room(room)
	return bit.rshift(room, 16), bit.band(bit.rshift(room, 8), 0xff), bit.band(room, 0xff)
end

function appendtrans(trans, from, to, frame)
	if not trans[from] then trans[from] = {} end
	if not trans[from][to] then trans[from][to] = {} end
	table.insert(trans[from][to], frame)
end

function gettrans(trans, from, to)
	return trans[from] and trans[from][to]
end

function build_transitions(ghost)
	local res = {}
	local last = 0
	for i = 1, nframe(ghost) do
		local new = ghost.data[i].room
		if last ~= new then
			appendtrans(res,last,new,i)
			last = new
		end
	end
	return res
end

-- Find the transition closest to sync frame "near_sync"
-- May return nil
function find_transition(ghost, from, to, near_sync)
	if near_sync < 1 then return 0 end -- handle last frame
	local t = gettrans(ghost.transitions, from, to)
	local ns = math.min(near_sync,nsync(ghost))
	local near_frame = sync2frame(ns, ghost)
	if not t or not near_frame then return end
	local bi, bv = nil
	for i, f in ipairs(t) do
		local diff = math.abs(f-near_frame)
		if not bv or bv > diff then
			bv = diff
			bi = i
		end
	end
	return frame2sync(t[bi], ghost)
end

function read_pose(info)
	local im1 = gd.convertToTrueColor(gd.createFromPng(root_dir .. info[1]))
	local im2 = gd.convertToTrueColor(gd.createFromPng(root_dir .. info[2]))

	if im1 == nil then error("Cannot load image: " .. info[1]) end
	if im2 == nil then error("Cannot load image: " .. info[2]) end

	local im1rev = gd.convertToTrueColor(gd.createFromPng(root_dir .. info[1]))
	local im2rev = gd.convertToTrueColor(gd.createFromPng(root_dir .. info[2]))
	gd.flipHorizontal(im1rev)
	gd.flipHorizontal(im2rev)

	return { im1:gdStr(), im1rev:gdStr(), im2:gdStr(), im2rev:gdStr() }
end

function draw_ghost_gfx(ghost,frame,index,logonly)
	if not ghost_gfx then return end

	local displayDelay = 2
	local frameAdjusted = frame - displayDelay
	local adjusted = false
	while frameAdjusted >= 1 and (frame - frameAdjusted < displayDelay * 4) do
		if ghost.data[frameAdjusted].igframe + displayDelay == ghost.data[frame].igframe then
			adjusted = true
			break
		end
		frameAdjusted = frameAdjusted - 1
	end
	if not adjusted then
		return
	end

	local data = ghost.data[frameAdjusted]
	if not data then return end

	if emudata[1].mode ~= 2 then return end

	local scrollx, scrolly = emudata[3].scrollx, emudata[3].scrolly
	local dx, dy = pose_info[ghost.gfx][3], pose_info[ghost.gfx][4]
	local ox, oy = pose_info[ghost.gfx][5], pose_info[ghost.gfx][6]
	local players = { data.jonathan, data.charlotte }
	for i, player in ipairs(players) do
		local put = function(x, y)
			if player.visible then
				local xi, yi = player.pose % 0x10, math.floor(player.pose / 0x10)
				local reverse = (player.dir >= 0)
				local gi = 1 + ((i - 1) * 2) + (reverse and 1 or 0)
				local opacity = ghost.opacity * math.min(1.0, 1.0 - math.abs(emudata[3].fade/16.0)) * (player.blink and 0.5 or 1.0)
				if not reverse then
					if logonly then
						drawlog:write("IMGB("..tostring(x-ox)..","..tostring(y-oy)..",pose_data["..tostring(ghost.gfx).."]["..tostring(gi).."],"..tostring(xi*dx)..","..tostring(yi*dy)..","..tostring(dx)..","..tostring(dy)..","..tostring(opacity)..") ")
					else
						gui.gdoverlayclip("bottom", x-ox, y-oy, pose_data[ghost.gfx][gi], xi*dx, yi*dy, dx, dy, opacity)
					end
				else
					if logonly then
						drawlog:write("IMGB("..tostring(x-ox)..","..tostring(y-oy)..",pose_data["..tostring(ghost.gfx).."]["..tostring(gi).."],"..tostring((15-xi)*dx)..","..tostring(yi*dy)..","..tostring(dx)..","..tostring(dy)..","..tostring(opacity)..") ")
					else
						gui.gdoverlayclip("bottom", x-ox, y-oy, pose_data[ghost.gfx][gi], (15-xi)*dx, yi*dy, dx, dy, opacity)
					end
				end
			end
		end

		local x, y = math.floor((player.posx - scrollx) / 0x1000), math.floor((player.posy - scrolly) / 0x1000)
		if player.offscreen then
			-- TODO: add extra display code here
		else
			put(x, y)
		end
	end
end

function draw_delay(ghost,delay, index)
	local ybase = -192
	gui.text((index-1)*6*7+1,ybase,string.format("%d", delay))
	gui.line((index-1)*6*7,8+ybase,index*6*7-1,8+ybase,ghost.color)
	gui.line(index*6*7-1,8+ybase,index*6*7-1,ybase,ghost.color)
end

-- End of definitions. Start running.

emu.registerexit(function()
	if drawlog ~= nil then drawlog:close() end
end)

init()
