-- Starfall Rotlings: the crater spawner.
-- Rotlings wander into the central crater on a timer, up to ten free at
-- once. Rarity and mutation are rolled per spawn (see Config), and the
-- creature is picked from that rarity's pool (see RotlingData).

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local RotlingData = require(game:GetService("ReplicatedStorage").Shared.RotlingData)
local Bases = require(script.Parent.Bases)
local RotlingFactory = require(script.Parent.RotlingFactory)

local Spawner = {}

local running = false

function Spawner.countFree(): number
	local count = 0
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant:GetAttribute("State") == "free" then
			count += 1
		end
	end
	return count
end

-- Wire a Rotling's grab prompt to the server's grab logic.
function Spawner.connectPrompt(model: Model)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local prompt = body:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(player: Player)
		Bases.tryGrab(player, model)
	end)
end

function Spawner.spawnOne(): Model?
	local def = RotlingData.rollDef()
	local mutation = Config.rollMutation()
	local angle = math.random() * math.pi * 2
	local radius = math.random() * Config.CRATER_RADIUS * 0.8
	local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	local model = RotlingFactory.build(def.id, mutation, position)
	if not model then
		return nil
	end
	model.Parent = workspace
	Spawner.connectPrompt(model)
	return model
end

function Spawner.start()
	if running then
		return
	end
	running = true
	-- A few Rotlings are already waiting when the first player arrives.
	for _ = 1, 5 do
		Spawner.spawnOne()
	end
	task.spawn(function()
		while true do
			task.wait(Config.SPAWN_INTERVAL)
			if Spawner.countFree() < Config.CRATER_MAX_FREE then
				Spawner.spawnOne()
			end
		end
	end)
end

return Spawner
