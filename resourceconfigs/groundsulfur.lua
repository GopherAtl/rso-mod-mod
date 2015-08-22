function fillGroundSulfurConfig()
	
	config["sulfur"] = {
		type = "resource-ore",
		allotment = 40,
		spawns_per_region = {min=1, max=2},
		richness = 1000,
		size = {min=10, max=14},
	}
	
	if config["iron-ore"] and config["iron-ore"].multi_resource then
		config["iron-ore"].multi_resource["sulfur"] = 1
	end
	if config["copper-ore"] and config["copper-ore"].multi_resource then
		config["copper-ore"].multi_resource["sulfur"] = 1
	end
	if config["coal"] and config["coal"].multi_resource then
		config["coal"].multi_resource["sulfur"] = 4
	end
	if config["crude-oil"] and config["crude-oil"].multi_resource then
		config["crude-oil"].multi_resource["sulfur"] = 2
	end
	
end