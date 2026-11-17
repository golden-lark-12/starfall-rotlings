--!strict
-- Starfall Rotlings: mutations.
-- A spawn-time roll that multiplies a Rotling's income and repaints it.
-- Starstruck is never rolled: a Rotling only earns it by surviving a
-- meteor hit during a storm (see StarfallService).

export type Mutation = {
	name: string,
	mult: number,
	chance: number, -- per-spawn roll chance; 0 means never rolled
	color: Color3,
	glow: Color3, -- PointLight colour on the creature
}

local MutationConfig = {}

MutationConfig.MUTATIONS = {
	{ name = "Gold", mult = 2, chance = 0.08, color = Color3.fromRGB(255, 215, 0), glow = Color3.fromRGB(255, 210, 60) },
	{ name = "Frozen", mult = 3, chance = 0.05, color = Color3.fromRGB(150, 220, 255), glow = Color3.fromRGB(120, 200, 255) },
	{ name = "Rainbow", mult = 5, chance = 0.02, color = Color3.fromRGB(255, 120, 220), glow = Color3.fromRGB(255, 100, 220) },
	{ name = "Starstruck", mult = 4, chance = 0, color = Color3.fromRGB(255, 240, 170), glow = Color3.fromRGB(255, 245, 200) },
} :: { Mutation }

function MutationConfig.mutationByName(name: string?): Mutation?
	if name == nil then
		return nil
	end
	for _, mutation in ipairs(MutationConfig.MUTATIONS) do
		if mutation.name == name then
			return mutation
		end
	end
	return nil
end

-- Roll one mutation at spawn. Most spawns come back plain.
function MutationConfig.rollMutation(): string?
	local roll = math.random()
	local running = 0
	for _, mutation in ipairs(MutationConfig.MUTATIONS) do
		running += mutation.chance
		if roll <= running then
			return mutation.name
		end
	end
	return nil
end

-- Income multiplier for a mutation name, 1 when there is none.
function MutationConfig.mutationMult(name: string?): number
	local mutation = MutationConfig.mutationByName(name)
	if mutation then
		return mutation.mult
	end
	return 1
end

return MutationConfig
