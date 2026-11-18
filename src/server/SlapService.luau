--!strict
-- Starfall Rotlings: the slap bat.
-- No guns — a bat. Swing (F key or the SLAP button) and anything in
-- front of you within 9 studs gets knocked back and drops what it
-- carries: a rival, a raider, or another player. Cooldown 2s, fun
-- sound + stars effect on the victim. Rival bots swing back when a
-- player crowds them. A Shield boost makes you immune.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BoostService = require(script.Parent.BoostService)
local CarryService = require(script.Parent.CarryService)
local RivalService = require(script.Parent.RivalService)
local State = require(script.Parent.State)

local SlapService = {}

local readyAt: { [number]: number } = {}

local function knockback(root: Part, from: Vector3)
	local flat = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
	local away = if flat.Magnitude > 0.5 then flat.Unit else Vector3.new(0, 0, 1)
	root.AssemblyLinearVelocity = away * Config.SLAP_KNOCKBACK + Vector3.new(0, 16, 0)
end

-- The slap's HIT effect: a shockwave ring + "BONK!" burst at the
-- impact point, shown to every client. (fix round 7, item 3) The old
-- effect was a yellow Neon ball + gold particles — a glowing sun
-- that appeared at the click point even when the slap hit nothing,
-- because the server fired the same event for hits and whiffs and
-- the client could not tell them apart. Now the event carries a hit
-- flag: a real hit shows the impact to everyone; a whiff shows only
-- a faint swoosh to the slapper (slapMissAt), never a sun.
local function slapHitAt(position: Vector3)
	Remotes.slapEffectEvent():FireAllClients(position, true)
end

local function slapMissAt(player: Player, position: Vector3)
	Remotes.slapEffectEvent():FireClient(player, position, false)
end

-- Slap a rival model: it drops its catch and flees.
function SlapService.slapRival(rival: State.Rival, byPlayer: Player?)
	local model = rival.model
	local root = model:FindFirstChild("HumanoidRootPart")
	local character = if byPlayer then byPlayer.Character else nil
	local from = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and from then
		knockback(root, from.Position)
	end
	if root then
		slapHitAt(root.Position)
	end
	RivalService.dropCarried(rival)
	rival.phase = "flee"
	rival.targetUserId = nil
	if byPlayer then
		Remotes.bannerEvent():FireClient(byPlayer, "👋 SLAP! " .. rival.name .. " dropped the Brainrot and ran!", 3)
	end
end

-- Slap another player: they drop everything they carry.
function SlapService.slapPlayer(victim: Player, byPlayer: Player)
	if BoostService.hasBoost(victim, "shield") then
		Remotes.bannerEvent():FireClient(byPlayer, "🛡️ " .. victim.DisplayName .. " is shielded — the slap bounced off!", 3)
		return
	end
	local character = victim.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local swinger = byPlayer.Character
	local from = swinger and swinger:FindFirstChild("HumanoidRootPart")
	if root and from then
		knockback(root, from.Position)
		slapHitAt(root.Position)
	end
	CarryService.dropAllCarried(victim)
	local MeteorEggService = require(script.Parent.MeteorEggService)
	MeteorEggService.dropEgg(victim)
	Remotes.bannerEvent():FireClient(victim, "👋 " .. byPlayer.DisplayName .. " slapped you — you dropped your Brainrots!", 3)
end

-- A rival slaps a player back (no cooldown on the victim's side).
function SlapService.applySlapFromRival(rival: State.Rival, victim: Player)
	if BoostService.hasBoost(victim, "shield") then
		return
	end
	local character = victim.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local rivalRoot = rival.model:FindFirstChild("HumanoidRootPart")
	if root and rivalRoot then
		knockback(root, rivalRoot.Position)
		slapHitAt(root.Position)
	end
	CarryService.dropAllCarried(victim)
	local MeteorEggService = require(script.Parent.MeteorEggService)
	MeteorEggService.dropEgg(victim)
	Remotes.bannerEvent():FireClient(victim, "👋 " .. rival.name .. " slapped you back — you dropped your Brainrots!", 3)
end

-- The swing: find rivals and players in front of the swinger, in range.
function SlapService.trySlap(player: Player)
	if time() < (readyAt[player.UserId] or 0) then
		return
	end
	readyAt[player.UserId] = time() + Config.SLAP_COOLDOWN
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local forward = root.CFrame.LookVector
	local hitAnyone = false
	-- Rivals first.
	for model, rival in pairs(State.rivals) do
		local rivalRoot = model:FindFirstChild("HumanoidRootPart")
		if rivalRoot then
			local to = rivalRoot.Position - root.Position
			local dist = to.Magnitude
			if dist <= Config.SLAP_RANGE and dist > 0.5 and to.Unit:Dot(Vector3.new(forward.X, 0, forward.Z).Unit) > 0.3 then
				SlapService.slapRival(rival, player)
				hitAnyone = true
			end
		end
	end
	-- Then other players.
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local otherChar = other.Character
			local otherRoot = otherChar and otherChar:FindFirstChild("HumanoidRootPart")
			if otherRoot then
				local to = otherRoot.Position - root.Position
				local dist = to.Magnitude
				if dist <= Config.SLAP_RANGE and dist > 0.5 and to.Unit:Dot(Vector3.new(forward.X, 0, forward.Z).Unit) > 0.3 then
					SlapService.slapPlayer(other, player)
					hitAnyone = true
				end
			end
		end
	end
	-- Raiders too (a bonk by bat).
	for raiderModel in pairs(State.raiders) do
		local raiderRoot = raiderModel:FindFirstChild("HumanoidRootPart")
		if raiderRoot then
			local to = raiderRoot.Position - root.Position
			local dist = to.Magnitude
			if dist <= Config.SLAP_RANGE and dist > 0.5 and to.Unit:Dot(Vector3.new(forward.X, 0, forward.Z).Unit) > 0.3 then
				local RaiderService = require(script.Parent.RaiderService)
				RaiderService.bonkRaider(raiderModel, player)
				-- bonkRaider scatters the loot and flees but fires no
				-- effect itself — the impact shows here, at the
				-- raider, so the bonk reads as a hit.
				slapHitAt(raiderRoot.Position)
				hitAnyone = true
			end
		end
	end
	if not hitAnyone then
		-- A whiff: only a faint swoosh for the slapper — never a
		-- sun, never a "BONK!". The bat still swings (the client
		-- shows it), but nothing appears at the click point.
		slapMissAt(player, root.Position + forward * 4)
	end
end

function SlapService.init()
	Remotes.slapEvent().OnServerEvent:Connect(function(player: Player)
		SlapService.trySlap(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		readyAt[player.UserId] = nil
	end)
end

return SlapService
