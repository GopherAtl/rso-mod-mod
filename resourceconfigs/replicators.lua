function fillReplicatorsConfig()
	
	config["creatine"] = {
		type="resource-liquid",
		minimum_amount=5000,
		allotment=40,
		spawns_per_region={min=1, max=1},
		richness={min=5000, max=20000}, 
		size={min=1, max=3},
		
		starting={richness=20000, size=2, probability=1},
		
		multi_resource_chance=0.50,
		multi_resource={
			["crude-oil"] = 2,
			["iron-ore"] = 2,
			['copper-ore'] = 2,
			["coal"] = 2,
			["stone"] = 2,
		}
	}
	
	if config["crude-oil"] and config["crude-oil"].multi_resource then
		config["crude-oil"].multi_resource["creatine"] = 2
	end
	
	config["rare-earth"] = {
		type="resource-ore",
		
		allotment=40,
		
		spawns_per_region={min=1, max=1},
		size={min=10, max=16},
		richness=3000,
		
		starting={richness=1000, size=10, probability=1},
		
		multi_resource_chance=0.30,
		multi_resource={
			["iron-ore"] = 2,
			['copper-ore'] = 2,
			["coal"] = 3,
			["stone"] = 1,
			["creatine"] = 2,
		}
	}
	
	config["iron-ore"].multi_resource["rare-earth"] = 2
	config["copper-ore"].multi_resource["rare-earth"] = 2
	config["coal"].multi_resource["rare-earth"] = 2
	config["stone"].multi_resource["rare-earth"] = 2
	
end