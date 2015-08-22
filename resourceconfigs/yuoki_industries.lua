function fillYuokiConfig()
	
	config["y-res1"] = {
		type="resource-ore",
		allotment=50,
		spawns_per_region={min=1, max=3},
		richness=8000,
		size={min=10, max=16},
		min_size=150,
		
		starting={richness=2000, size=12, probability=1},
	}
	
	config["y-res2"] = {
		type="resource-ore",
		allotment=50,
		spawns_per_region={min=1, max=3},
		richness=7000,
		size={min=10, max=15},
		min_size=150,
		
		starting={richness=2000, size=12, probability=1},
	}
end