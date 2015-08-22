function fillUraniumpowerConfig()
	
	config["uraninite"] = {
		type="resource-ore",
		
		allotment=30,
		spawns_per_region={min=1, max=3},
		richness=6000,
		size={min=10, max=15},
		min_amount = 150,
		
		multi_resource_chance=0.50,
		multi_resource={
			["copper-ore"] = 2,
			["iron-ore"] = 2,
			["coal"] = 4,
			["stone"] = 4,
			["fluorite"] = 8,
		}
	}
	
	config["fluorite"] = {
		type="resource-ore",
		
		allotment=30,
		spawns_per_region={min=1, max=3},
		richness=8000,
		size={min=10, max=15},
		min_amount = 150,
		
		multi_resource_chance=0.50,
		multi_resource={
			["copper-ore"] = 2,
			["iron-ore"] = 2,
			["coal"] = 4,
			["stone"] = 4,
			["uraninite"] = 8,
		}
	}
	
	if config["coal"] and config["coal"].multi_resource then
		config["coal"].multi_resource["fluorite"] = 4
		config["coal"].multi_resource["uraninite"] = 4
	end
end