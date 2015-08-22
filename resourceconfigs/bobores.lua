function fillBoboresConfig()
	
	-- BobOres
	-- up the stone at start
	config["stone"].allotment = 80
	config["stone"].starting.richness = 10000
	
	config["gold-ore"] = {
		type="resource-ore",
		
		allotment=40,
		spawns_per_region={min=1, max=3},
		richness=10000,
		size={min=10, max=18},
		min_amount = 150,
		
		multi_resource_chance=0.50,
		multi_resource={
			["lead-ore"] = 3,
			["silver-ore"] = 3,
			["tin-ore"] = 3,
			["tungsten-ore"] = 3,
			["zinc-ore"] = 3,
			["bauxite-ore"] = 3,
		}
	}
	config["silver-ore"] = {
		type="resource-ore",
		
		allotment=40,
		spawns_per_region={min=1, max=3},
		richness=10000,
		size={min=10, max=18},
		min_amount = 150,
		
		multi_resource_chance=0.50,
		multi_resource={
			["lead-ore"] = 3,
			["gold-ore"] = 3,
			["tin-ore"] = 3,
			["tungsten-ore"] = 3,
			["zinc-ore"] = 3,
			["bauxite-ore"] = 3,
		}
	}
	
	config["lead-ore"] = {
		type="resource-ore",
		
		allotment=40,
		spawns_per_region={min=1, max=3},
		richness=10000,
		size={min=10, max=18},
		min_amount = 300,
		
		starting={richness=3000, size=10, probability=1},
		
		multi_resource_chance=0.50,
		multi_resource={
			["silver-ore"] = 3,
			["gold-ore"] = 3,
			["tin-ore"] = 3,
			["tungsten-ore"] = 3,
			["zinc-ore"] = 3,
			["bauxite-ore"] = 3,
		}
	}
	
	config["tin-ore"] = {
		type="resource-ore",
		
		allotment=40,
		spawns_per_region={min=1, max=3},
		richness=10000,
		size={min=10, max=18},
		min_amount = 300,
		
		starting={richness=3000, size=10, probability=1},
		
		multi_resource_chance=0.50,
		multi_resource={
			["lead-ore"] = 3,
			["silver-ore"] = 3,
			["gold-ore"] = 3,
			["tungsten-ore"] = 3,
			["zinc-ore"] = 3,
			["copper-ore"] = 2,
			["bauxite-ore"] = 3,
		}
	}
	
	config["tungsten-ore"] = {
		type="resource-ore",
		
		allotment=30,
		spawns_per_region={min=1, max=3},
		richness=8000,
		size={min=10, max=18},
		min_amount = 200,
		
		multi_resource_chance=0.50,
		multi_resource={
			["lead-ore"] = 3,
			["silver-ore"] = 3,
			["gold-ore"] = 3,
			["tin-ore"] = 3,
			["zinc-ore"] = 3,
			["bauxite-ore"] = 3,
			["rutile-ore"] = 3,
		}
	}
	
	config["zinc-ore"] = {
		type="resource-ore",
		
		allotment=40,
		spawns_per_region={min=1, max=3},
		richness=8000,
		size={min=10, max=16},
		min_amount = 250,

		starting={richness=3000, size=10, probability=1},

		multi_resource_chance=0.50,
		multi_resource={
			["lead-ore"] = 3,
			["silver-ore"] = 3,
			["gold-ore"] = 3,
			["tin-ore"] = 3,
			["tungsten-ore"] = 3,
			["bauxite-ore"] = 3,
		}
	}
	
	config["bauxite-ore"] = {
		type="resource-ore",
		
		allotment=40,
		spawns_per_region={min=1, max=3},
		richness=9000,
		size={min=10, max=18},
		min_amount = 200,
		
		multi_resource_chance=0.50,
		multi_resource={
			["lead-ore"] = 3,
			["silver-ore"] = 3,
			["gold-ore"] = 3,
			["tin-ore"] = 3,
			["zinc-ore"] = 3,
		}
	}
	
	config["rutile-ore"] = {
		type="resource-ore",
		
		allotment=40,
		spawns_per_region={min=1, max=3},
		richness=9000,
		size={min=10, max=14},
		min_amount = 200,
		
		multi_resource_chance=0.50,
		multi_resource={
			["lead-ore"] = 3,
			["silver-ore"] = 3,
			["gold-ore"] = 3,
			["tin-ore"] = 3,
			["zinc-ore"] = 3,
			["tungsten-ore"] = 3,
		}
	}
	
	config["quartz"] = {
		type="resource-ore",
		
		allotment=40,
		spawns_per_region={min=1, max=3},
		richness=10000,
		size={min=10, max=16},
		min_amount = 250,
		
		starting={richness=2000, size=10, probability=1},
		
		multi_resource_chance=0.50,
		multi_resource={
			["lead-ore"] = 3,
			["silver-ore"] = 3,
			["gold-ore"] = 3,
			["tin-ore"] = 3,
			["zinc-ore"] = 3,
		}
	}
	
	-- check if Nickel, Cobalt, Sulfur or GemOre is added by bobs ores
	if game.entity_prototypes["cobalt-ore"] then
		config["cobalt-ore"] = {
			type="resource-ore",
			
			allotment=30,
			spawns_per_region={min=1, max=3},
			richness=8000,
			size={min=10, max=16},
			min_amount = 150,
			
			multi_resource_chance=0.50,
			multi_resource={
				["lead-ore"] = 3,
				["tungsten-ore"] = 3,
				["gold-ore"] = 3,
				["quartz"] = 3,
			}
		}
	end
	
	if game.entity_prototypes["nickel-ore"] then
		config["nickel-ore"] = {
			type="resource-ore",
			
			allotment=40,
			spawns_per_region={min=1, max=3},
			richness=8000,
			size={min=10, max=16},
			min_amount = 200,
			
			starting={richness=3000, size=10, probability=1},
			
			multi_resource_chance=0.50,
			multi_resource={
				["tungsten-ore"] = 3,
				["rutile-ore"] = 3,
				["lead-ore"] = 3,
				["quartz"] = 3,
			}
		}
		
	end
	
	if game.entity_prototypes["sulfur"] then
		config["sulfur"] = {
			type="resource-ore",
			
			allotment=40,
			spawns_per_region={min=1, max=3},
			richness=8000,
			size={min=10, max=15},
			min_amount = 250,
			
			multi_resource_chance=0.50,
			multi_resource={
				["lead-ore"] = 3,
				["tin-ore"] = 3,
				["tungsten-ore"] = 3,
				["rutile-ore"] = 3,
			}
		}
	end
	
	if game.entity_prototypes["gem-ore"] then
		config["gem-ore"] = {
			type="resource-ore",
			
			allotment=30,
			spawns_per_region={min=1, max=3},
			richness=6000,
			size={min=10, max=14},
			min_amount = 250,
			
			multi_resource_chance=0.50,
			multi_resource={
				["silver-ore"] = 3,
				["gold-ore"] = 3,
				["tungsten-ore"] = 3,
				["rutile-ore"] = 3,
			}
		}
	end
	
	if game.entity_prototypes["cobalt-ore"] and game.entity_prototypes["nickel-ore"] then
		config["cobalt-ore"].multi_resource["nickel-ore"] = 3
		config["nickel-ore"].multi_resource["cobalt-ore"] = 3
	end
	
	if game.entity_prototypes["gem-ore"] and game.entity_prototypes["nickel-ore"] then
		config["gem-ore"].multi_resource["nickel-ore"] = 3
		config["nickel-ore"].multi_resource["gem-ore"] = 3
	end
	
	if game.entity_prototypes["gem-ore"] and game.entity_prototypes["cobalt-ore"] then
		config["gem-ore"].multi_resource["cobalt-ore"] = 3
		config["cobalt-ore"].multi_resource["gem-ore"] = 3
	end
	
end