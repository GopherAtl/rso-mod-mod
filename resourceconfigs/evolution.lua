function fillEvolutionConfig()
	
	config["alien-artifacts"] =
	{
		type = "resource-ore",
		allotment = 40,
		spawns_per_region = {min=1, max=2},
		richness = 1000,
		size = {min=10, max=14},
		min_size = 50,
		
		starting={richness=500, size=10, probability=1},
	
		multi_resource_chance=0.50, -- absolute value
		multi_resource={
			["iron-ore"] = 2, -- ["resource_name"] = allotment
			["coal"] = 4,
			["stone"] = 4,
		}
	}
	
	if config["iron-ore"] and config["iron-ore"].multi_resource then
		config["iron-ore"].multi_resource["alien-artifacts"] = 2
	end
	if config["coal"] and config["coal"].multi_resource then
		config["coal"].multi_resource["alien-artifacts"] = 3
	end
	if config["stone"] and config["stone"].multi_resource then
		config["stone"].multi_resource["alien-artifacts"] = 3
	end
	
end