function fillEnemies()
	
	config["biter-spawner"] = {
		type="entity",
		force="enemy",
		clear_range = {6, 6},
		
		spawns_per_region={min=2,max=4},
		size={min=2,max=4},
		size_per_region_factor=1.10,
		richness=1,
		
		absolute_probability=absolute_enemy_chance, -- chance to spawn in region
		probability_distance_factor=1.05, -- relative increase per region
		max_probability_distance_factor=3.0, -- absolute value
		
		along_resource_probability=0.10, -- chance to spawn in resource chunk anyway, absolute value. Can happen once per resource.
		
		sub_spawn_probability=0.3,     -- chance for this entity to spawn anything from sub_spawns table, absolute value
		sub_spawn_size={min=1, max=2}, -- in same chunk
		sub_spawn_distance_factor=1.04,
		sub_spawn_max_distance_factor=3,
		sub_spawns={
			["small-worm-turret"]={
				min_distance=3,
				allotment=2000,
				allotment_distance_factor=0.9,
				clear_range = {1, 1},
			},
			["medium-worm-turret"]={
				min_distance=6,
				allotment=1000,
				allotment_distance_factor=1.05,
				clear_range = {1, 1},
			},
			["big-worm-turret"]={
				min_distance=9,
				allotment=1000,
				allotment_distance_factor=1.15,
				clear_range = {1, 1},
			}
		}
	}
	
end