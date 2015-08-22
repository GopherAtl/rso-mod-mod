require("config")
require("prototypes.prototype_utils")

if override_normal_spawn then
	
	for _, resource in pairs(data.raw.resource) do
		add_peak(resource,{influence=-1000})
	end

	for _, spawner in pairs(data.raw["unit-spawner"]) do
		add_peak(spawner,{influence=-1000})
	end

	for _, turret in pairs(data.raw.turret) do
		if turret.subgroup == "enemies" then
			add_peak(turret,{influence=-1000})
		end
	end
end

data.raw["map-settings"]["map-settings"].enemy_expansion.enabled = not disableEnemyExpansion

if debug_items_enabled then
	data.raw["car"]["car"].max_health = 0x8000000
	data.raw["ammo"]["basic-bullet-magazine"].magazine_size = 1000
	data.raw["ammo"]["basic-bullet-magazine"].ammo_type.action[1].action_delivery[1].target_effects[2].damage.amount = 5000
end