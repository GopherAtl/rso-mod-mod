function fillPeaceConfig()
	
	config["alien-ore"] = {
		type="resource-ore",
		allotment=30,
		spawns_per_region={min=1, max=2},
		richness=2000,
		size={min=10, max=14},
		min_amount=20,
		
		multi_resource_chance=0.4,
		multi_resource={
			['copper-ore'] = 1,
			['iron-ore'] = 1,
		}
	}
	
end