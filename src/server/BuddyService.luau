--!strict
-- Starfall Rotlings: the Buddy Rotling.
-- A simple pet, not a pet system: your highest-income placed Rotling
-- (or the one you pick in the Index), shrunk to half size, floating and
-- bobbing beside you with a small tag ("Buddy: <name> · +5% cash"). It
-- follows smoothly, never blocks the camera (it rides beside you, not
-- in front), and shows up in all 4 photo shots. Swap the buddy from
-- the Index (SetBuddy remote). No eggs, inventory or trading for pets.
-- The buddy pays +5% cash (IncomeService.incomeMult).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RotlingCatalog = require(ReplicatedStorage.Shared.RotlingCatalog)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local RotlingFactory = require(script.Parent.RotlingFactory)
local State = require(script.Parent.State)

local BuddyService = {}

function BuddyService.hasBuddy(player: Player): boolean
	return State.buddies[player.UserId] ~= nil
end

function BuddyService.buddyName(player: Player): string?
	local model = State.buddies[player.UserId]
	if not model then
		return nil
	end
	local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
	return if def then def.name else nil
end

-- Which Rotling should follow this player: the Index pick if set and
-- found, otherwise the highest-income placed Rotling. Returns
-- (defId, mutation).
local function pickBuddyDef(player: Player): (string?, string?)
	local profile = DataService.getProfile(player)
	if profile and profile.buddyDefId then
		if profile.index[profile.buddyDefId] then
			return profile.buddyDefId, nil
		end
	end
	local best: Model? = nil
	local bestCps = -1
	for _, model in ipairs(BaseService.getPlacedForPlayer(player)) do
		local def = RotlingCatalog.getDef(model:GetAttribute("DefId") :: string)
		if def then
			local cps = RotlingCatalog.baseCps(def, model:GetAttribute("Mutation") :: string?)
			if cps > bestCps then
				bestCps = cps
				best = model
			end
		end
	end
	if best then
		return best:GetAttribute("DefId") :: string, best:GetAttribute("Mutation") :: string?
	end
	return nil, nil
end

function BuddyService.removeBuddy(player: Player)
	local model = State.buddies[player.UserId]
	if model then
		State.buddies[player.UserId] = nil
		model:Destroy()
	end
end

-- Attach (or re-attach) the buddy to a player's character: a half-size
-- clone of the Rotling, welded beside the player, bobbing gently.
function BuddyService.attachBuddy(player: Player)
	BuddyService.removeBuddy(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local defId, mutation = pickBuddyDef(player)
	if not defId then
		return
	end
	local def = RotlingCatalog.getDef(defId)
	if not def then
		return
	end
	local model = RotlingFactory.build(defId, mutation, root.Position + Vector3.new(3, 1, 0), Config.BUDDY_SCALE)
	if not model then
		return
	end
	-- A buddy is not a free Rotling: no grab prompt, no big name tag.
	local body = model.PrimaryPart
	if body then
		local prompt = body:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt:Destroy()
		end
		local label = body:FindFirstChild("RotlingLabel")
		if label then
			label:Destroy()
		end
		-- The small buddy tag: name + the +5% cash bonus.
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "BuddyTag"
		billboard.Size = UDim2.fromOffset(180, 36)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.2, 0)
		billboard.AlwaysOnTop = true
		billboard.LightInfluence = 0
		billboard.MaxDistance = 30
		billboard.Parent = body
		local tag = Instance.new("TextLabel")
		tag.Size = UDim2.new(1, 0, 1, 0)
		tag.BackgroundTransparency = 1
		tag.Text = "Buddy: " .. def.name .. " · +5% cash"
		tag.Font = Enum.Font.FredokaOne
		tag.TextScaled = true
		tag.TextColor3 = Color3.fromRGB(255, 230, 90)
		tag.TextStrokeTransparency = 0.3
		tag.Parent = billboard
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end
	local weld = Instance.new("Weld")
	weld.Name = "BuddyWeld"
	weld.Part0 = root
	weld.Part1 = body
	weld.C0 = CFrame.new(Config.BUDDY_OFFSET)
	weld.Parent = body
	model:SetAttribute("State", "buddy")
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = workspace
	State.buddies[player.UserId] = model
	-- Bob: the weld's offset breathes up and down, so the buddy floats
	-- instead of riding rigid. One loop per buddy, stops when it dies.
	task.spawn(function()
		local seed = math.random() * 10
		while model.Parent and State.buddies[player.UserId] == model do
			local bob = math.sin(time() * 1.8 + seed) * 0.15
			if weld.Parent then
				weld.C0 = CFrame.new(Config.BUDDY_OFFSET + Vector3.new(0, bob, 0))
			end
			task.wait(0.1)
		end
	end)
end

-- Rebuild the buddy when the best placed Rotling changes (place, sell,
-- pickup, rebirth) or the player picks a new one in the Index.
function BuddyService.refreshBuddy(player: Player)
	local defId, _ = pickBuddyDef(player)
	local current = State.buddies[player.UserId]
	local currentDef = if current then current:GetAttribute("DefId") :: string else nil
	if defId == currentDef then
		return
	end
	BuddyService.attachBuddy(player)
end

-- Set the buddy from the Index. Returns (ok, message).
function BuddyService.setBuddy(player: Player, defId: string): (boolean, string)
	local profile = DataService.getProfile(player)
	if not profile then
		return false, "Profile not loaded yet."
	end
	if not profile.index[defId] then
		return false, "Find that Brainrot first — then it can be your buddy."
	end
	local def = RotlingCatalog.getDef(defId)
	if not def then
		return false, "No such Brainrot."
	end
	profile.buddyDefId = defId
	DataService.saveProfile(player)
	BuddyService.attachBuddy(player)
	return true, "Buddy set: " .. def.name .. " (+5% cash)!"
end

function BuddyService.init()
	Remotes.setBuddyFunction().OnServerInvoke = function(player: Player, defId: string)
		local ok, message = BuddyService.setBuddy(player, defId)
		return ok, message
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		BuddyService.removeBuddy(player)
	end)
end

return BuddyService
