require "defines"
require "config"
require "util"

require "resourceconfigs.mainconfig"
require "libs.straight_world"

local starting_areas={}

local MB=require "libs/metaball"
local drand = require 'libs/drand'
local rng = drand.mwvc
if not deterministic then rng = drand.sys_rand end

local logger = require 'libs/logger'
local l = logger.new_logger()

-- math shortcuts
local floor = math.floor
local abs = math.abs
local cos = math.cos
local sin = math.sin
local pi = math.pi
local max = math.max


local function debug(str)
	if debug_enabled then
		l:log(str)
	end
end

-- constants
local CHUNK_SIZE = 32
local REGION_TILE_SIZE = CHUNK_SIZE*region_size
local MIN_BALL_DISTANCE = CHUNK_SIZE/6
local P_BALL_SIZE_FACTOR = 0.7
local N_BALL_SIZE_FACTOR = 0.95
local NEGATIVE_MODIFICATOR = 123456

local meta_shapes = nil

if use_donut_shapes then
	meta_shapes = {MB.MetaEllipse, MB.MetaSquare, MB.MetaDonut}
else
	meta_shapes = {MB.MetaEllipse, MB.MetaSquare}
end

-- local globals
local index_is_built = false
local max_allotment = 0
local rgen = nil
local distance = util.distance
local spawner_probability_edge = 0  -- below this value a biter spawner, above/equal this value a spitter spawner
local invalidResources = {}
local config = nil
local configIndexed = nil

--[[ HELPER METHODS ]]--

local function normalize(n) --keep numbers at (positive) 32 bits
	return floor(n) % 0x80000000
end

local function bearing(origin, dest)
	-- finds relative angle
	local xd = dest.x - origin.x
	local yd = dest.y - origin.y
	return math.atan2(xd, yd);
end

local function str2num(s)
	local num = 0
	for i=1,s:len() do
		num=num + (s:byte(i) - 33)*i
	end
	return num
end

local function mult_for_pos(pos)
	local num = 0
	local x = pos.x
	local y = pos.y

	if x == 0 then x = 0.5 end
	if y == 0 then y = 0.5 end
	if x < 0 then
		x = abs(x) + NEGATIVE_MODIFICATOR
	end
	if y < 0 then
		y = abs(y) + NEGATIVE_MODIFICATOR
	end

	return drand.lcg(y, 'mvc'):random(0)*drand.lcg(x, 'nr'):random(0)
end

local function rng_for_reg_pos(pos)
	local rgen = rng(normalize(global.seed*mult_for_pos(pos)))
	rgen:random()
	rgen:random()
	rgen:random()
	return rgen
end

local function rng_restricted_angle(restrictions)
	local rng = rgen:random()
	local x_scale, y_scale
	local deformX = rgen:random() * 2 - 1
	local deformY = rgen:random() * 2 - 1

	if restrictions=='xy' then
		y_scale=1.0 + deformY*0.5
		x_scale=1.0 + deformX*0.5
		angle = rng*pi*2
	elseif restrictions=='x' then
		y_scale=1.0 + deformY*0.6
		x_scale=1.0 + deformX*0.6
		angle = rng*pi/2 - pi/4
	elseif restrictions=='y' then
		y_scale=1.0 + deformY*0.6
		x_scale=1.0 + deformX*0.6
		angle = rng*pi/2 + pi/2
	else
		y_scale=1.0 + deformY*0.3
		x_scale=1.0 + deformX*0.3
		angle = rng*pi*2
	end

	return angle, x_scale, y_scale
end

local function vary_by_percentage(x, p)
	return x + (0.5 - rgen:random())*2*x*p
end


local function remove_trees(surface, x, y, x_size, y_size )
	local bb={{x - x_size, y - y_size}, {x + x_size, y + y_size}}
	for _, entity in ipairs(surface.find_entities_filtered{area = bb, type="tree"}) do
		if entity.valid then
			entity.destroy()
		end
	end
end

local function find_intersection(surface, x, y)
	-- try to get position in between of valid chunks by probing map
	-- this may breaks determinism of generation, but so far it returned on first if
	local gt = surface.get_tile
	local restriction = ''
	if gt(x + CHUNK_SIZE*2, y + CHUNK_SIZE*2).valid and gt(x - CHUNK_SIZE*2, y - CHUNK_SIZE*2).valid and gt(x + CHUNK_SIZE*2, y - CHUNK_SIZE*2).valid and gt(x - CHUNK_SIZE*2, y + CHUNK_SIZE*2).valid then
		restriction = 'xy'
	elseif gt(x + CHUNK_SIZE*2, y + CHUNK_SIZE*2).valid and gt(x + CHUNK_SIZE*2, y).valid and gt(x, y + CHUNK_SIZE*2).valid then
		x=x + CHUNK_SIZE/2
		y=y + CHUNK_SIZE/2
		restriction = 'xy'
	elseif gt(x + CHUNK_SIZE*2, y - CHUNK_SIZE*2).valid and gt(x + CHUNK_SIZE*2, y).valid and gt(x, y - CHUNK_SIZE*2).valid then
		x=x + CHUNK_SIZE/2
		y=y - CHUNK_SIZE/2
		restriction = 'xy'
	elseif gt(x - CHUNK_SIZE*2, y + CHUNK_SIZE*2).valid and gt(x - CHUNK_SIZE*2, y).valid and gt(x, y + CHUNK_SIZE*2).valid then
		x=x - CHUNK_SIZE/2
		y=y + CHUNK_SIZE/2
		restriction = 'xy'
	elseif gt(x - CHUNK_SIZE*2, y - CHUNK_SIZE*2).valid and gt(x - CHUNK_SIZE*2, y).valid and gt(x, y - CHUNK_SIZE*2).valid then
		x=x - CHUNK_SIZE/2
		y=y - CHUNK_SIZE/2
		restriction = 'xy'
	elseif gt(x + CHUNK_SIZE*2, y).valid then
		x=x + CHUNK_SIZE/2
		restriction = 'x'
	elseif gt(x - CHUNK_SIZE*2, y).valid then
		x=x - CHUNK_SIZE/2
		restriction = 'x'
	elseif gt(x, y + CHUNK_SIZE*2).valid then
		y=y + CHUNK_SIZE/2
		restriction = 'y'
	elseif gt(x, y - CHUNK_SIZE*2).valid then
		y=y - CHUNK_SIZE/2
		restriction = 'y'
	end
	return x, y, restriction
end

local function find_random_chunk(r_x, r_y)
	local offset_x=rgen:random(region_size)-1
	local offset_y=rgen:random(region_size)-1
	local c_x=r_x*REGION_TILE_SIZE + offset_x*CHUNK_SIZE
	local c_y=r_y*REGION_TILE_SIZE + offset_y*CHUNK_SIZE
	return c_x, c_y
end

local function is_same_region(c_x1, c_y1, c_x2, c_y2)
	if not floor(c_x1/REGION_TILE_SIZE) == floor(c_x2/REGION_TILE_SIZE) then
		return false
	end
	if not floor(c_y1/REGION_TILE_SIZE) == floor(c_y2/REGION_TILE_SIZE) then
		return false
	end
	return true
end

local function find_random_neighbour_chunk(ocx, ocy)
	-- somewhat bruteforce and unoptimized
	local x_dir = rgen:random(-1,1)
	local y_dir = rgen:random(-1,1)
	local ncx = ocx + x_dir*CHUNK_SIZE
	local ncy = ocy + y_dir*CHUNK_SIZE
	if is_same_region(ncx, ncy, ocx, ocy) then
		return ncx, ncy
	end

	ncx = ocx - x_dir*CHUNK_SIZE
	ncy = ocy - y_dir*CHUNK_SIZE
	if is_same_region(ncx, ncy, ocx, ocy) then
		return ncx, ncy
	end

	ncx = ocx - x_dir*CHUNK_SIZE
	if is_same_region(ncx, ocy, ocx, ocy) then
		return ncx, ocy
	end

	ncy = ocy - y_dir*CHUNK_SIZE
	if is_same_region(ocx, ncy, ocx, ocy) then
		return ocx, ncy
	end

	return ocx, ocy
end


local function spawn_distance(pos)
  local closest=100000000000
  for k,v in pairs(starting_areas) do
    closest=math.min(closest,distance(v.region,pos))
  end
  if closest>10 then
    game.players[1].print("closest to "..pos.x..","..pos.y.." is "..closest.."??")
    --[[
    if #starting_areas==0 then
      game.players[1].print("no starting areas generated yet, using '1'")
    else
      game.players[1].print("starting_areas[1].region="..starting_areas[1].region.x..","..starting_areas[1].region.y)
    end
    --]]
    closest=1
  end
  return closest
--  return distance({x=0,y=0},pos)
end


-- modifies the resource size - only used in endless_resource_mode
local function modify_resource_size(resourceName, resourceSize, startingArea)

	if not startingArea then
		resourceSize = math.ceil(resourceSize * global_size_mult)
	end

	resourceEntity = game.entity_prototypes[resourceName]
	if resourceEntity and resourceEntity.infinite_resource then

		newResourceSize = resourceSize * endless_resource_mode_sizeModifier

		-- make sure it's still an integer
		newResourceSize = math.ceil(newResourceSize)
		-- make sure it's not 0
		if newResourceSize == 0 then newResourceSize = 1 end
		return newResourceSize
	else
		return resourceSize
	end
end

--[[ SPAWN METHODS ]]--

--[[ entity-field ]]--
local function spawn_resource_ore(surface, rname, pos, size, richness, startingArea, restrictions)
	-- blob generator, centered at pos, size controls blob diameter
	restrictions = restrictions or ''
	debug("Entering spawn_resource_ore "..rname.." at:"..pos.x..","..pos.y.." size:"..size.." richness:"..richness.." isStart:"..tostring(startingArea).." restrictions:"..restrictions)

	size = modify_resource_size(rname, size, startingArea)
	local radius = size/2 -- to radius

	local p_balls={}
	local n_balls={}
	local MIN_BALL_DISTANCE = math.min(MIN_BALL_DISTANCE, radius/2)

	local outside = { xmin = 1e10, xmax = -1e10, ymin = 1e10, ymax = -1e10 }
	local inside = { xmin = 1e10, xmax = -1e10, ymin = 1e10, ymax = -1e10 }

	local function adjustRadius(radius, scaleX, scaleY, up)
		if scaleX < 1 then
			scaleX = 1
		end
		if scaleY < 1 then
			scaleY = 1
		end

		if up then
			return radius * math.max(scaleX, scaleY)
		else
			return radius / math.max(scaleX, scaleY)
		end
	end

	local function updateRect(rect, x, y, radius)
		rect.xmin = math.min(rect.xmin, x - radius)
		rect.xmax = math.max(rect.xmax, x + radius)
		rect.ymin = math.min(rect.ymin, y - radius)
		rect.ymax = math.max(rect.ymax, y + radius)
	end

	local function updateRects(x, y, radius, scaleX, scaleY)
		local adjustedRadius = adjustRadius(radius, scaleX, scaleY, true)
		local radiusMax = adjustedRadius * 3 -- arbitrary multiplier - needs to be big enough to not cut any metaballs
		updateRect(outside, x, y, radiusMax)
		updateRect(inside, x, y, adjustedRadius)
	end

	local function generate_p_ball()
		local angle, x_scale, y_scale, x, y, b_radius, shape
		angle, x_scale, y_scale=rng_restricted_angle(restrictions)
		local dev = rgen:random(radius/8, radius/2)--math.min(CHUNK_SIZE/3, radius*1.5)
		local dev_x, dev_y = pos.x, pos.y
		x = rgen:random(-dev, dev)+dev_x
		y = rgen:random(-dev, dev)+dev_y
		if p_balls[#p_balls] and distance(p_balls[#p_balls], {x=x, y=y}) < MIN_BALL_DISTANCE then
			local new_angle = bearing(p_balls[#p_balls], {x=x, y=y})
			debug("Move ball old xy @ "..x..","..y)
			x=(cos(new_angle)*MIN_BALL_DISTANCE) + x
			y=(sin(new_angle)*MIN_BALL_DISTANCE) + y
			debug("Move ball new xy @ "..x..","..y)
		end

		b_radius = (radius / 2 + rgen:random()* radius / 4) -- * (P_BALL_SIZE_FACTOR^#p_balls)

		if #p_balls > 0 then
			local tempRect = table.deepcopy(inside)
			updateRect(tempRect, x, y, adjustRadius(b_radius, x_scale, y_scale))
			local rectSize = math.max(tempRect.xmax - tempRect.xmin, tempRect.ymax - tempRect.ymin)
			local targetSize = size
			debug("Rect size "..rectSize.." targetSize "..targetSize)
			if rectSize > targetSize then
				local widthLeft = (targetSize - (inside.xmax - inside.xmin))
				local heightLeft = (targetSize - (inside.ymax - inside.ymin))
				local widthMod = math.min(x - inside.xmin, inside.xmax - x)
				local heightMod = math.min(y - inside.ymin, inside.ymax - y)
				local radiusBackup = b_radius
				b_radius = math.min(widthLeft + widthMod, heightLeft + heightMod)
				b_radius = adjustRadius(b_radius, x_scale, y_scale, false)
				debug("Reduced ball radius from "..radiusBackup.." to "..b_radius.." widthLeft:"..widthLeft.." heightLeft:"..heightLeft.." widthMod:"..widthMod.." heightMod:"..heightMod)
			end
		end

		if b_radius > 2 then
			shape = meta_shapes[rgen:random(1,#meta_shapes)]
			local radiusText = ""
			if shape.type == "MetaDonut" then
				local inRadius = b_radius / 4 + b_radius / 2 * rgen:random()
				radiusText = " inRadius:"..inRadius
				p_balls[#p_balls+1] = shape:new(x, y, b_radius, inRadius, angle, x_scale, y_scale, 1.1)
			else
				p_balls[#p_balls+1] = shape:new(x, y, b_radius, angle, x_scale, y_scale, 1.1)
			end
			updateRects(x, y, b_radius, x_scale, y_scale)

			debug("P+Ball "..shape.type.." @ "..x..","..y.." radius: "..b_radius..radiusText.." angle: "..math.deg(angle).." scale: "..x_scale..", "..y_scale)
		else
			debug("Resource size "..b_radius.." to low - spawn skipped")
		end
	end

	local function generate_n_ball(i)
		local angle, x_scale, y_scale, x, y, b_radius, shape
		angle, x_scale, y_scale=rng_restricted_angle('xy')
		if p_balls[i] then
			local new_angle = p_balls[i].angle + pi*rgen:random(0,1) + (rgen:random()-0.5)*pi/2
			local dist = p_balls[i].radius
			x=(cos(new_angle)*dist) + p_balls[i].x
			y=(sin(new_angle)*dist) + p_balls[i].y
			angle = p_balls[i].angle + pi/2 + (rgen:random()-0.5)*pi*2/3
		else
			x = rgen:random(-radius, radius)+pos.x
			y = rgen:random(-radius, radius)+pos.y
		end
		b_radius = (radius / 4 + rgen:random() * radius / 4) -- * (N_BALL_SIZE_FACTOR^#n_balls)

		shape = meta_shapes[rgen:random(1,#meta_shapes)]
		local radiusText = ""
		if shape.type == "MetaDonut" then
			local inRadius = b_radius / 4 + b_radius / 2 * rgen:random()
			radiusText = " inRadius:"..inRadius
			n_balls[#n_balls+1] = shape:new(x, y, b_radius, inRadius, angle, x_scale, y_scale, 1.2)
		else
			n_balls[#n_balls+1] = shape:new(x, y, b_radius, angle, x_scale, y_scale, 1.2)
		end
		-- updateRects(x, y, b_radius, x_scale, y_scale) -- should not be needed here - only positive ball can generate ore
		debug("N-Ball "..shape.type.." @ "..x..","..y.." radius: "..b_radius..radiusText.." angle: "..math.deg(angle).." scale: "..x_scale..", "..y_scale)
	end

	local function calculate_force(x,y)
		local p_force = 0
		local n_force = 0
		for _,ball in ipairs(p_balls) do
			p_force = p_force + ball:force(x,y)
		end
		for _,ball in ipairs(n_balls) do
			n_force = n_force + ball:force(x,y)
		end
		local totalForce = 0
		if p_force > n_force then
			totalForce = 1 - 1/(p_force - n_force)
		end
		--debug("Force at "..x..","..y.." p:"..p_force.." n:"..n_force.." result:"..totalForce)
		--return (1 - 1/p_force) - n_force
		return totalForce
	end

	local max_p_balls = 2
	local min_amount = config[rname].min_amount or min_amount
	if restrictions == 'xy' then
		-- we have full 4 chunks
		radius = math.min(radius*1.5, CHUNK_SIZE/2)
		richness = richness*2/3
		min_amount = min_amount / 3
		max_p_balls = 3
	end

	local force
	-- generate blobs
	for i=1,max_p_balls do
		generate_p_ball()
	end

	for i=1,rgen:random(1, #p_balls) do
		generate_n_ball(i)
	end

	local _a = {}
	local _total = 0
	local oreLocations = {}
	local forceTotal = 0

	-- fill the map
--	for y=pos.y-CHUNK_SIZE*2, pos.y+CHUNK_SIZE*2-1 do
	for y=outside.ymin, outside.ymax do
		local _b = {}
		_a[#_a+1] = _b
--		for x=pos.x-CHUNK_SIZE*2, pos.x+CHUNK_SIZE*2-1 do
		for x=outside.xmin, outside.xmax do
			if surface.get_tile(x,y).valid then
				force = calculate_force(x, y)
				if force > 0 then
					--debug("@ "..x..","..y.." force: "..force.." amount: "..amount)
					if not surface.get_tile(x,y).collides_with("water-tile") and surface.can_place_entity{name = rname, position = {x,y}} then
						_b[#_b+1] = '#'
						oreLocations[#oreLocations + 1] = {x = x, y = y, force = force}
						forceTotal = forceTotal + force
--					elseif not startingArea then -- we don't want to make ultra rich nodes in starting area - failing to make them will add second spawn in different location
--						entities = game.find_entities_filtered{area = {{x-2.75, y-2.75}, {x+2.75, y+2.75}}, name=rname}
--						if entities and #entities > 0 then
--							_b[#_b+1] = 'O'
--							_total = _total + amount
--							for k, ent in pairs(entities) do
--								ent.amount = ent.amount + floor(amount/#entities)
--							end
--						else
--							_b[#_b+1] = '.'
--						end
					else
						_b[#_b+1] = 'c'
					end
				else
					_b[#_b+1] = '<'
				end
			else
				_b[#_b+1] = 'x'
			end
		end
	end

	if #oreLocations > 0 then

		local minSize = richness * 10
		local maxSize = richness * 20
		local approxDepositSize = rgen:random(minSize, maxSize)

		local forceFactor = approxDepositSize / forceTotal

		-- don't create very dense resources in starting area - another field will be generated
		if startingArea and forceFactor > 4000 then
			forceFactor = rgen:random(3000, 4000)
		elseif forceFactor > 25000 then -- limit size of one resource pile
			forceFactor = rgen:random(20000, 25000)
		end

		debug( "Force total:"..forceTotal.." sizeMin:"..minSize.." sizeMax:"..maxSize.." factor:"..forceFactor.." location#:"..#oreLocations)

		for _,location in ipairs(oreLocations) do
	--		local amount=floor((richness*location.force*(0.8^#p_balls)) + min_amount)
			local amount=floor(forceFactor*location.force + min_amount)
			_total = _total + amount
			surface.create_entity{name = rname,
				position = {location.x,location.y},
				force = game.forces.neutral,
				amount = floor(amount*global_richness_mult)}
		end
	end

	if debug_enabled then
		debug("Total amount: ".._total)
		for _,v in pairs(_a) do
			--output a nice ASCII map
			--debug(table.concat(v))
		end
		debug("Leaving spawn_resource_ore")
	end
	return _total
end

--[[ entity-liquid ]]--
local function spawn_resource_liquid(surface, rname, pos, size, richness, startingArea, restrictions)
	restrictions = restrictions or ''
	debug("Entering spawn_resource_liquid "..rname.." "..pos.x..","..pos.y.." "..size.." "..richness.." "..tostring(startingArea).." "..restrictions)
	local _total = 0
	local max_radius = rgen:random()*CHUNK_SIZE/2 + CHUNK_SIZE
	--[[
		if restrictions == 'xy' then
		-- we have full 4 chunks
		max_radius = floor(max_radius*1.5)
		size = floor(size*1.2)
		end
	]]--
	-- don't reduce amount of liquids - they are already infinite
	--  size = modify_resource_size(size)

	richness = richness * size

	local total_share = 0
	local avg_share = 1/size
	local angle = rgen:random()*pi*2
	local saved = 0
	while total_share < 1 do
		local new_share = vary_by_percentage(avg_share, 0.25)
		if new_share + total_share > 1 then
			new_share = 1 - total_share
		end
		total_share = new_share + total_share
		if new_share < avg_share/10 then
			-- too small
			break
		end
		local amount = floor(richness*new_share) + saved
		--if amount >= game.entity_prototypes[rname].minimum then
		if amount >= config[rname].minimum_amount then
			saved = 0
			for try=1,5 do
				local dist = rgen:random()*(max_radius - max_radius*0.1)
				angle = angle + pi/4 + rgen:random()*pi/2
				local x, y = pos.x + cos(angle)*dist, pos.y + sin(angle)*dist
				if surface.can_place_entity{name = rname, position = {x,y}} then
					debug("@ "..x..","..y.." amount: "..amount.." new_share: "..new_share.." try: "..try)
					_total = _total + amount
					surface.create_entity{name = rname,
						position = {x,y},
						force = game.forces.neutral,
						amount = floor(amount*global_richness_mult),
					direction = rgen:random(4)}
					break
				elseif not startingArea then -- we don't want to make ultra rich nodes in starting area - failing to make them will add second spawn in different location
					entities = surface.find_entities_filtered{area = {{x-2.75, y-2.75}, {x+2.75, y+2.75}}, name=rname}
					if entities and #entities > 0 then
						_total = _total + amount
						for k, ent in pairs(entities) do
							ent.amount = ent.amount + floor(amount/#entities)
						end
						break
					end
				end
			end
		else
			saved = amount
		end
	end
	debug("Total amount: ".._total)
	debug("Leaving spawn_resource_liquid")
	return _total
end

local function spawn_entity(surface, ent, r_config, x, y)
	if disable_RSO_biter_spawning then return end
	local size=rgen:random(r_config.size.min, r_config.size.max)

	local _total = 0
	local r_distance = spawn_distance({x=x/REGION_TILE_SIZE,y=y/REGION_TILE_SIZE})

	if r_config.size_per_region_factor then
		size = size*math.min(r_config.size_per_region_factor^r_distance, 5)
	end

	size = size * enemy_base_size_multiplier

	debug("Entering spawn_entity "..ent.." "..x..","..y.." "..size)

	for i=1,size do
		local richness=r_config.richness*(richness_distance_factor^r_distance)
		local max_d = floor(CHUNK_SIZE*1.3)
		local s_x = x + rgen:random(0, floor(max_d - r_config.clear_range[1])) - max_d/2 + r_config.clear_range[1]
		local s_y = y + rgen:random(0, floor(max_d - r_config.clear_range[2])) - max_d/2 + r_config.clear_range[2]

		remove_trees(surface, s_x, s_y, r_config.clear_range[1], r_config.clear_range[2])

		if surface.get_tile(s_x, s_y).valid then

			local spawnerName = nil

			if spawner_probability_edge > 0 then

				bigSpawnerChance = rgen:random()

				if rgen:random() < spawner_probability_edge then
					if ( useBobEntity and bigSpawnerChance > 0.75 ) then
						spawnerName = "bob-biter-spawner"
					else
						spawnerName = "biter-spawner"
					end
				else
					if ( useBobEntity and bigSpawnerChance > 0.75 ) then
						spawnerName = "bob-spitter-spawner"
					else
						spawnerName = "spitter-spawner"
					end
				end
			end

			if spawnerName and game.entity_prototypes[spawnerName] then
				if surface.can_place_entity{name=spawnerName, position={s_x, s_y}} then
					_total = _total + richness
					debug(spawnerName.." @ "..s_x..","..s_y)

					surface.create_entity{name=spawnerName, position={s_x, s_y}, force=game.forces[r_config.force], amount=floor(richness)}--, direction=rgen:random(4)
					--			else
					--				game.players[1].print("Entity "..spawnerName.." spawn failed")
				end
			else
				game.players[1].print("Entity "..spawnerName.." doesn't exist")
			end
		end

		if r_config.sub_spawn_probability then
			local sub_spawn_prob = r_config.sub_spawn_probability*math.min(r_config.sub_spawn_max_distance_factor, r_config.sub_spawn_distance_factor^r_distance)
			if rgen:random() < sub_spawn_prob then
				for i=1,rgen:random(r_config.sub_spawn_size.min, r_config.sub_spawn_size.max) do
					local allotment_max = 0
					-- build table
					for k,v in pairs(r_config.sub_spawns) do
						if not v.min_distance or r_distance > v.min_distance then
							local allotment = v.allotment
							if v.allotment_distance_factor then
								allotment = allotment * (v.allotment_distance_factor^r_distance)
							end
							v.allotment_range ={min = allotment_max, max = allotment_max + allotment}
							allotment_max = allotment_max + allotment
						else
							v.allotment_range = nil
						end
					end
					local sub_type = rgen:random(0, allotment_max)
					for sub_spawn,v in pairs(r_config.sub_spawns) do
						if v.allotment_range and sub_type >= v.allotment_range.min and sub_type <= v.allotment_range.max then
							s_x = x + rgen:random(max_d) - max_d/2
							s_y = y + rgen:random(max_d) - max_d/2
							remove_trees(surface, s_x, s_y, v.clear_range[1], v.clear_range[2])
							if surface.get_tile(s_x, s_y).valid and surface.can_place_entity{name=sub_spawn, position={s_x, s_y}} then
								surface.create_entity{name=sub_spawn, position={s_x, s_y}, force=game.forces[r_config.force]}--, direction=rgen:random(4)
								debug("Rolled subspawn "..sub_spawn.." @ "..s_x..","..s_x)
							end
							break
						end
					end
				end
			end
		end
	end
	debug("Total amount: ".._total)
	debug("Leaving spawn_entity")
end

--[[ EVENT/INIT METHODS ]]--

local function spawn_starting_resources( surface, center )
  if global.start_resources_spawned or game.tick > 3600 then return end -- starting resources already there or game was started without mod
	rgen = rng_for_reg_pos(center)
	local status = true
	for index,v in ipairs(configIndexed) do
		if v.starting then
			local prob = rgen:random() -- probability that this resource is spawned
			debug("starting resource probability rolled "..prob)
			if v.starting.probability > 0 and prob <= v.starting.probability then
				local total = 0
				local radius = 25
				local min_threshold = 0

				if v.type == "resource-ore" then
					min_threshold = v.starting.richness * rgen:random(5, 10) -- lets make sure that there is at least 10-15 times starting richness ore at start
				elseif v.type == "resource-liquid" then
					min_threshold = v.starting.richness * 0.5 * v.starting.size
				end

				while (radius < 200) and (total < min_threshold) do
					local angle = rgen:random() * pi * 2
					local dist = rgen:random() * 30 + radius * 2
					local pos = { x = center.x+floor(cos(angle) * dist), y = center.y+floor(sin(angle) * dist)}
					if v.type == "resource-ore" then
						total = total + spawn_resource_ore(surface, v.name, pos, v.starting.size, v.starting.richness, true)
					elseif v.type == "resource-liquid" then
						total = total + spawn_resource_liquid(surface, v.name, pos, v.starting.size, v.starting.richness, true)
					end
					radius=radius + 10
				end
				if total < min_threshold then
					status = false
				end
			end
		end
	end
	--l:dump('logs/start_'..global.seed..'.log')
end

local function prebuild_config_data()
	if index_is_built then return false end

	configIndexed = {}
	-- build additional indexed array to the associative array
	for res_name, res_conf in pairs(config) do
		if res_conf.valid then -- only add valid resources
			res_conf.name = res_name
			configIndexed[#configIndexed + 1] = res_conf
			if res_conf.multi_resource then
				local new_list = {}
				for sub_res_name, allotment in pairs(res_conf.multi_resource) do
					new_list[#new_list+1] = {name = sub_res_name, allotment = allotment}
				end
				table.sort(new_list, function(a, b) return a.name < b.name end)
				res_conf.multi_resource = new_list
			end
		end
	end

	table.sort(configIndexed, function(a, b) return a.name < b.name end)

	local pr=0
	for index,v in pairs(config) do
		if v.along_resource_probability then
			v.along_resource_probability_range={min=pr, max=pr+v.along_resource_probability}
			pr=pr+v.along_resource_probability
		end
		if v.allotment and v.allotment > 0 then
			v.allotment_range={min=max_allotment, max=max_allotment+v.allotment}
			max_allotment=max_allotment+v.allotment
		end
	end

	index_is_built = true
end

local function generate_seed( surface )
	if global.seed then return end
	global.seed = 0
	local entities=surface.find_entities({{-CHUNK_SIZE,-CHUNK_SIZE},{CHUNK_SIZE,CHUNK_SIZE}})
	for _,ent in pairs(entities) do
		global.seed=normalize(global.seed + str2num(ent.name)*mult_for_pos(ent.position))
	end
	for x=-CHUNK_SIZE,CHUNK_SIZE do
		for y=-CHUNK_SIZE,CHUNK_SIZE do
			global.seed=normalize(global.seed + str2num(surface.get_tile(x, y).name)*mult_for_pos({x=x, y=y}))
		end
	end
	--game.player.print("Initial seed: "..global.seed)
	debug("Initial seed: "..global.seed)
end

-- set up the probabilty segments from which to roll between for biter and spitter spawners
local function calculate_spawner_ratio()
	if (biter_ratio_segment ~= 0 and spitter_ratio_segment ~= 0) and biter_ratio_segment >= 0 and spitter_ratio_segment >= 0 then
		spawner_probability_edge=biter_ratio_segment/(biter_ratio_segment+spitter_ratio_segment)  -- normalize to between 0 and 1
	end
end

local function checkConfigForInvalidResources()
	--make sure that every resource in the config is actually available.
	--call this function, before the auxiliary config is prebuilt!
	if index_is_built then return end

	for resourceName, resourceConfig in pairs(config) do
		if game.entity_prototypes[resourceName] then
			resourceConfig.valid = true
		else
			-- resource was in config, but it doesn't exist in game files anymore - mark it invalid
			resourceConfig.valid = false

			table.insert(invalidResources, "Resource not available: " .. resourceName)
			debug("Resource not available: " .. resourceName)
		end
	end
end

local function checkForBobEnemies()
	if game.entity_prototypes["bob-biter-spawner"] and game.entity_prototypes["bob-spitter-spawner"] then
		useBobEntity = true
	end
end

local function init()
	if not initDone then

		local surface = game.surfaces['nauvis']

		if not global.regions then
			global.regions = {}
		end

    if not global.starting_areas then
      global.starting_areas=starting_areas
    else
      starting_areas=global.starting_areas
    end

		if not config then
			config = loadResourceConfig()
			checkConfigForInvalidResources()
			prebuild_config_data()
		end

		generate_seed(surface)
		calculate_spawner_ratio()

    --default, in case someone's using this control without adding the config setting
    num_starting_areas=#starting_area_forces


		if num_starting_areas == 1 then
      starting_areas[starting_area_forces[1]]={
        position={x=0,y=0},
        center_chunk={x=0,y=0},
        region={x=0,y=0},
        generated=false,
        }

    else
      --distribute in a circle around 0,0
      local rgen = rng_for_reg_pos({x=0,y=0})
      local offset_distance=starting_area_size*REGION_TILE_SIZE
      local angle_step=pi*2/num_starting_areas
      local angle=rgen:random()*angle_step
      for i=1,num_starting_areas do
        local pos={ x=math.floor(cos(angle)*offset_distance), y=math.floor(sin(angle)*offset_distance),}
        starting_areas[starting_area_forces[i]]={
          position=pos,
          center_chunk={math.floor(pos.x/CHUNK_SIZE),math.floor(pos.y/CHUNK_SIZE),},
          region={x=floor(pos.x/REGION_TILE_SIZE),y=floor(pos.y/REGION_TILE_SIZE)},
          generated=false,
        }

        angle=angle+angle_step
      end
    end

    for i=1,#starting_area_forces do
      local force_name=starting_area_forces[i]
      if game.forces[force_name]==nil then
        game.create_force(force_name)
      end
      local pos=starting_areas[force_name].position
      --despite what wiki said, request_to_generate_chunks doesn't seem to require or use a radius arg
      --it just generates a 3x3 chunk area every whether the 2nd arg is 1, 10, nil, or "foo"
      for x=-3,3,3 do
        for y=-3,3,3 do
          game.surfaces.nauvis.request_to_generate_chunks({x=pos.x+x*32,y=pos.y+y*32},1)
        end
      end
      --l:log("request chunks = "..starting_areas[force_name].position.x..","..starting_areas[force_name].position.y.." for radius "..(starting_area_size*region_size/2+1))
    end

		checkForBobEnemies()

		initDone = true
	end

end


local function is_starting_area(c_x,c_y)
  for k,v in pairs(starting_areas) do
    if (abs((c_x-v.position.x)/REGION_TILE_SIZE)+abs((c_y-v.position.y)/REGION_TILE_SIZE))<=starting_area_size then
      return true
    end
  end
end



local function roll_region(surface, c_x, c_y)
	--in what region is this chunk?
	local r_x=floor(c_x/REGION_TILE_SIZE)
	local r_y=floor(c_y/REGION_TILE_SIZE)
	local r_data = nil
	--don't spawn stuff in starting area
  --TODO: fix starting area detection
	if is_starting_area(c_x,c_y) then
		return false
	end

	if global.regions[r_x] and global.regions[r_x][r_y] then
		r_data = global.regions[r_x][r_y]
	else
		--if this chunk is the first in its region to be generated
		if not global.regions[r_x] then global.regions[r_x] = {} end
		global.regions[r_x][r_y]={}
		r_data = global.regions[r_x][r_y]
		rgen = rng_for_reg_pos{x=r_x,y=r_y}

		local rollCount = math.ceil(#configIndexed / 10) - 1 -- 0 based counter is more convenient here
		rollCount = math.min(rollCount, 3)

		for rollNumber = 0,rollCount do

			local resourceChance = absolute_resource_chance - rollNumber * 0.1
			--absolute chance to spawn resource
			local abct = rgen:random()
			debug("Rolling resource "..abct.." against "..resourceChance.." roll "..rollNumber)
			if abct <= resourceChance then
				local res_type=rgen:random(1, max_allotment)
				for index,v in ipairs(configIndexed) do
					if v.allotment_range and ((res_type >= v.allotment_range.min) and (res_type <= v.allotment_range.max)) then
						debug("Rolled primary resource "..v.name.." with res_type="..res_type.." @ "..r_x..","..r_y)
						local num_spawns=rgen:random(v.spawns_per_region.min, v.spawns_per_region.max)
						local last_spawn_coords = {}
						local along_
						for i=1,num_spawns do
							local c_x, c_y = find_random_chunk(r_x, r_y)
							if not r_data[c_x] then r_data[c_x] = {} end
							if not r_data[c_x][c_y] then r_data[c_x][c_y] = {} end
							local c_data = r_data[c_x][c_y]
							c_data[#c_data+1]={v.name, 0}
							last_spawn_coords[#last_spawn_coords+1] = {c_x, c_y}
							debug("Rolled primary chunk "..v.name.." @ "..c_x.."."..c_y.." reg: "..r_x..","..r_y)
							-- Along resource spawn, only once
							if i == 1 then
								local am_roll = rgen:random()
								for index,vv in ipairs(configIndexed) do
									if vv.along_resource_probability_range and am_roll >= vv.along_resource_probability_range.min and am_roll <= vv.along_resource_probability_range.max then
										c_data = r_data[c_x][c_y]
										c_data[#c_data+1]={vv.name, rollNumber}
										debug("Rolled along "..vv.name.." @ "..c_x.."."..c_y.." reg: "..r_x..","..r_y)
									end
								end
							end
						end
						-- roll multiple resources in same region
						local deep=0
						while v.multi_resource_chance and rgen:random() <= v.multi_resource_chance*(multi_resource_chance_diminish^deep) do
							deep = deep + 1
							local max_allotment = 0
							for index,sub_res in pairs(v.multi_resource) do max_allotment=max_allotment+sub_res.allotment end

							local res_type=rgen:random(1, max_allotment)
							local min=0
							for _, sub_res in pairs(v.multi_resource) do
								if (res_type >= min) and (res_type <= sub_res.allotment + min) then
									local last_coords = last_spawn_coords[rgen:random(1, #last_spawn_coords)]
									local c_x, c_y = find_random_neighbour_chunk(last_coords[1], last_coords[2]) -- in same as primary resource chunk
									if not r_data[c_x] then r_data[c_x] = {} end
									if not r_data[c_x][c_y] then r_data[c_x][c_y] = {} end
									local c_data = r_data[c_x][c_y]
									c_data[#c_data+1]={sub_res.name, deep}
									debug("Rolled multiple "..sub_res.name..":"..deep.." with res_type="..res_type.." @ "..c_x.."."..c_y.." reg: "..r_x.."."..r_y)
									break
								else
									min = min + sub_res.allotment
								end
							end
						end
						break
					end
				end

			end
		end
		-- roll for absolute_probability - this rolls the enemies

		for index,v in ipairs(configIndexed) do
			if v.absolute_probability then
				local prob_factor = 1
				if v.probability_distance_factor then
					prob_factor = math.min(v.max_probability_distance_factor, v.probability_distance_factor^spawn_distance({x=r_x,y=r_y}))
				end
				local abs_roll = rgen:random()
				if abs_roll<v.absolute_probability*prob_factor then
					local num_spawns=rgen:random(v.spawns_per_region.min, v.spawns_per_region.max)
					for i=1,num_spawns do
						local c_x, c_y = find_random_chunk(r_x, r_y)
						if not r_data[c_x] then r_data[c_x] = {} end
						if not r_data[c_x][c_y] then r_data[c_x][c_y] = {} end
						c_data = r_data[c_x][c_y]
						c_data[#c_data+1] = {v.name, 1}
						debug("Rolled absolute "..v.name.." with rt="..abs_roll.." @ "..c_x..","..c_y.." reg: "..r_x..","..r_y)
					end
				end
			end
		end
	end
end

local function roll_chunk(surface, c_x, c_y)
	--handle spawn in chunks
	local r_x=floor(c_x/REGION_TILE_SIZE)
	local r_y=floor(c_y/REGION_TILE_SIZE)
	local r_data = nil
	--don't spawn stuff in starting area
  --TODO: fix starting area detection for multiples
  if is_starting_area(c_x,c_y) then
    return false
  end

	local c_center_x=c_x + CHUNK_SIZE/2
	local c_center_y=c_y + CHUNK_SIZE/2
	if not (global.regions[r_x] and global.regions[r_x][r_y]) then
		return
	end
	r_data = global.regions[r_x][r_y]
	if not (r_data[c_x] and r_data[c_x][c_y]) then
		return
	end
	if r_data[c_x] and r_data[c_x][c_y] then
		rgen = rng_for_reg_pos{x=c_center_x,y=c_center_y}

		debug("Stumbled upon "..c_x..","..c_y.." reg: "..r_x.."."..r_y)
		local resource_list = r_data[c_x][c_y]
		--for resource, deep in pairs(r_data[c_x][c_y]) do
		--  resource_list[#resource_list+1] = {resource, deep}
		--end
		table.sort(resource_list, function(res1, res2) return res1[2] < res2[2] end)

		for _, res_con in ipairs(resource_list) do
			local resource = res_con[1]
			local deep = res_con[2]
			local r_config = config[resource]
			if r_config then
				local dist = spawn_distance({x=r_x,y=r_y})
				if r_config.type=="resource-ore" then
					local size=rgen:random(r_config.size.min, r_config.size.max) * (multi_resource_size_factor^deep) * (size_distance_factor^dist)
					local richness = r_config.richness*(richness_distance_factor^dist) * (multi_resource_richness_factor^deep)
					local restriction = ''
					debug("Center @ "..c_center_x..","..c_center_y)
					c_center_x, c_center_y, restriction = find_intersection(surface, c_center_x, c_center_y)
					debug("New Center @ "..c_center_x..","..c_center_y)
					spawn_resource_ore(surface, resource, {x=c_center_x,y=c_center_y}, size, richness, false, restriction)
				elseif r_config.type=="resource-liquid" then
					local size=rgen:random(r_config.size.min, r_config.size.max)  * (multi_resource_size_factor^deep) * (size_distance_factor^dist)
					local richness=rgen:random(r_config.richness.min * size, r_config.richness.max * size) * (richness_distance_factor^dist) * (multi_resource_richness_factor^deep)
					local restriction = ''
					c_center_x, c_center_y, restriction = find_intersection(surface, c_center_x, c_center_y)
					spawn_resource_liquid(surface, resource, {x=c_center_x,y=c_center_y}, size, richness, false, restriction)
				elseif r_config.type=="entity" then
					spawn_entity(surface, resource, r_config, c_center_x, c_center_y)
				end
			else
				debug("Resource access failed for " .. resource)
				game.players[1].print("Resource access failed for " .. resource)
			end
		end
		r_data[c_x][c_y]=nil
		--l:dump()
	end
end

local function clear_chunk(surface, c_x, c_y)
	local ent_list = {}
	local _count = 0
	for _,v in ipairs(configIndexed) do
		ent_list[v.name] = 1
		if v.sub_spawns then
			for ent,vv in pairs(v.sub_spawns) do
				ent_list[ent] = 1
			end
		end
	end

	for ent, _ in pairs(ent_list) do
		for _, obj in ipairs(surface.find_entities_filtered{area = {{c_x - CHUNK_SIZE/2, c_y - CHUNK_SIZE/2}, {c_x + CHUNK_SIZE/2, c_y + CHUNK_SIZE/2}}, name=ent}) do
			if obj.valid then
				obj.destroy()
				_count = _count + 1
			end
		end
	end

	-- remove biters
	for _, obj in ipairs(surface.find_entities_filtered{area = {{c_x - CHUNK_SIZE/2, c_y - CHUNK_SIZE/2}, {c_x + CHUNK_SIZE/2, c_y + CHUNK_SIZE/2}}, type="unit"}) do
		if obj.valid  and obj.force.name == "enemy"  and (string.find(obj.name, "-biter", -6) or string.find(obj.name, "-spitter", -8)) then
			obj.destroy()
		end
	end

	if _count > 0 then debug("Destroyed - ".._count) end
end

local function regenerate_everything(surface)
	-- step 1: clear the map and mark chunks for in place generation
	global.regions = {}
	local valid_chunks = {}
	local i = 1
	local status = true
	local iter_y_start, iter_y_end, iter_y_step, iter_x_start, iter_x_end, iter_x_step
	local function set_iterators(case)
		if case == 1 then
			-- top_left -> bottom_left
			iter_y_start = i
			iter_y_end = -i + 1
			iter_y_step = -1
			iter_x_start = i
			iter_x_end = i
			iter_x_step = 1
		elseif case == 2 then
			-- bottom_left -> bottom_rigth
			iter_y_start = -i
			iter_y_end = -i
			iter_y_step = 1
			iter_x_start = i
			iter_x_end = -i + 1
			iter_x_step = -1
		elseif case == 3 then
			-- bottom_right -> top_right
			iter_y_start = -i
			iter_y_end = i - 1
			iter_y_step = 1
			iter_x_start = -i
			iter_x_end = -i
			iter_x_step = 1
		elseif case == 4 then
			-- top_right -> top_left
			iter_y_start = i
			iter_y_end = i
			iter_y_step = 1
			iter_x_start = -i
			iter_x_end = i - 1
			iter_x_step = 1
		end
	end

	while status do
		status = false
		for case=1,4 do
			set_iterators(case)
			for yi=iter_y_start, iter_y_end, iter_y_step  do
				for xi=iter_x_start, iter_x_end, iter_x_step  do
					local c_x = CHUNK_SIZE*xi
					local c_y = CHUNK_SIZE*yi
					if not is_starting_area(c_x,c_y) then -- don't touch safe zone
						local cen_x, cen_y = c_x + CHUNK_SIZE/2, c_y + CHUNK_SIZE/2
						local _x, _y, restriction = find_intersection(surface, cen_x, cen_y)
						if restriction == 'xy' and c_x + CHUNK_SIZE/2 == _x  and  c_y + CHUNK_SIZE/2 == _y then
							valid_chunks[c_x] = valid_chunks[c_x] or {}
							valid_chunks[c_x][c_y] = true
							clear_chunk(surface, cen_x, cen_y)
							debug("Added "..c_x..","..c_y.." center: "..cen_x..","..cen_y)
							status = true
						end
					else
						status = true
					end
				end
			end
		end
		i = i + 1
	end

	-- step 2: regenerate chunks again
	i = 1
	for k, v in pairs(config) do
		-- regenerate small patches
		surface.regenerate_entity(k)
	end
	-- regenerate RSO chunks
	status = true
	while status do
		status = false
		for case=1,4 do
			set_iterators(case)
			for yi=iter_y_start, iter_y_end, iter_y_step  do
				for xi=iter_x_start, iter_x_end, iter_x_step  do
					local c_x = CHUNK_SIZE*xi
					local c_y = CHUNK_SIZE*yi
					if is_starting_area(c_x,c_y) then
						status = true
					end
					if valid_chunks[c_x] and valid_chunks[c_x][c_y] then
						roll_region(surface, c_x, c_y)
						roll_chunk(surface, c_x, c_y)

						if useStraightWorldMod then
							straightWorld(surface, {x = c_x, y = c_y}, {x = c_x + CHUNK_SIZE, y = c_y + CHUNK_SIZE})
						end

						status = true
					end
				end
			end
		end
		i = i + 1
	end
	--l:dump("logs/"..global.seed..'regenerated.log')
	game.player.print('Done')
end

local function extendRect(leftTop, bottomRight)
	leftTop.x = leftTop.x - CHUNK_SIZE / 2
	leftTop.y = leftTop.y - CHUNK_SIZE / 2
	bottomRight.x = bottomRight.x + CHUNK_SIZE
	bottomRight.x = bottomRight.x + CHUNK_SIZE

	return leftTop, bottomRight
end

local function printResourceProbability(player)
	-- prints the probability of each resource - how likely it is to be spawned in percent
	-- this ignores the multi resource chance
	player.print("Max allotment"..string.format("%.1f",max_allotment))
	debug("Max allotment"..string.format("%.1f",max_allotment))
	local sanityCheckAllotment = 0
	for index,v in ipairs(configIndexed) do
		if v.type ~= "entity" then		-- ignore enemies - they don't have allotment set
			if v.allotment then
				local resProbability = (v.allotment/max_allotment) * 100
				sanityCheckAllotment = sanityCheckAllotment + v.allotment
				player.print("Resource: "..v.name.." Prob: "..string.format("%.1f",resProbability))
				debug("Resource: "..v.name.." Prob: "..string.format("%.1f",resProbability))
			else
				player.print("Resource: "..v.name.." Allotment not set")
				debug("Resource: "..v.name.." Allotment not set")
			end
		end
	end

	player.print("SanityCheck Allotment: "..string.format("%.1f", sanityCheckAllotment))
	debug("SanityCheck Allotment: "..string.format("%.1f", sanityCheckAllotment))
end

local function IsIgnoreResource(ResourcePrototype)
	if ignoreConfig[ResourcePrototype.name] then
		return true
	end
	if string.find( ResourcePrototype.name, "underground-" ) ~= nil then
		return true
	end
	return false
end

local function checkForUnusedResources(player)
	-- find all resources and check if we have it in our config
	-- if not, tell the user that this resource won't be spawned (with RSO)
	for prototypeName, prototype in pairs(game.entity_prototypes) do
		if prototype.type == "resource" then
			if not config[prototypeName] then
				if IsIgnoreResource(prototype) then	-- ignore resources which are not autoplace
					debug("Resource not configured but ignored (non-autoplace): "..prototypeName)
				else
					player.print("The resource "..prototypeName.." is not configured in RSO. It won't be spawned!")
					debug("Resource not configured: "..prototypeName)
				end
			else
				-- these are the configured ones
				if IsIgnoreResource(prototype) then
					debug("Configured resource (but it is in ignore list - will be used!): " .. prototypeName)
				else
					debug("Configured resource: " .. prototypeName)
				end
			end
		end
	end
end

local function printInvalidResources(player)
	-- prints all invalid resources which were found when the config was processed.
	for _, message in pairs(invalidResources) do
		player.print(message)
	end
end

game.on_init(init)
game.on_load(init)
game.on_save(function ()
    l:dump()
end)

local function echo(msg)
  for k,v in pairs(game.players) do
    v.print(msg)
  end
end

game.on_event(defines.events.on_chunk_generated, function(event)
	local c_x = event.area.left_top.x
	local c_y = event.area.left_top.y
  --echo("generated "..(c_x/32)..","..(c_y/32))

	roll_region(event.surface, c_x, c_y)
	roll_chunk(event.surface, c_x, c_y)

	if useStraightWorldMod then
		straightWorld(event.surface, event.area.left_top, event.area.right_bottom)
	end


  local starting_areas_pending=false
  if not global.start_resources_spawned then
    for k,v in pairs(starting_areas) do
      if not v.generated then
        --echo("chunk generated @"..c_x..","..c_y.." is in a starting area for "..k..", checking...")
        local incomplete=false
        --echo("checking chunks in area {"..(v.position.x-3)..","..(v.position.x+3).."},{"..(v.position.y-3)..","..(v.position.y+3).."}")

        for y=-3,3 do
          for x=-3,3 do
            if not event.surface.is_chunk_generated{v.center_chunk[1]+x,v.center_chunk[2]+y} then
              --echo("incomplete - chunk at "..(v.position.x+x)..","..(v.position.y+y).." not generated?")
              incomplete=true
              break
            end
          end
          if incomplete then
            break
          end
        end
        if incomplete then
          starting_areas_pending=true
        else
          echo("generating starting resources for "..k..", region = "..v.region.x..","..v.region.y)
          spawn_starting_resources(event.surface,v.position)
          v.generated=true
        end
      end
    end
    if not starting_areas_pending then
      global.start_resources_spawned = true
    end
  end
end)

game.on_event(defines.events.on_player_created, function(event)

	local player = game.get_player(event.player_index)

	checkForUnusedResources(player)
	printInvalidResources(player)

	if debug_enabled then

		printResourceProbability(player)

		if useBobEntity then
			player.print("RSO: BobEnemies found")
		end

		if debug_items_enabled then
			player.character.insert{name = "coal", count = 1000}
			player.character.insert{name = "raw-wood", count = 100}
			player.character.insert{name = "car", count = 1}
			player.character.insert{name = "car", count = 1}
			player.character.insert{name = "car", count = 1}
--			player.character.insert{name = "resource-monitor", count = 1}
		end
	end


	l:dump()
end)

remote.add_interface("RSO", {
	-- remote.call("RSO", "regenerate", true/false)
	regenerate = function(new_seed)
		if new_seed then global.seed = math.random(0x80000000) end
		regenerate_everything()
	end,
  get_forces = function()
    return starting_area_forces
  end,
  get_force_spawn = function(force)
    if type(force)=="userdata" then
      force=force.name
    end
    if starting_areas[force] then
      return starting_areas[force].position
    end
  end,
})


