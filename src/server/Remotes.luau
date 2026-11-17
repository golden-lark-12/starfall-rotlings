-- Starfall Rotlings: the client/server wire.
-- RemoteEvents and RemoteFunctions live in ReplicatedStorage.StarfallRemotes
-- (defined in default.project.json). The client never sends a number the
-- server trusts: buys, rebirths, locks and placements are all validated
-- on the server before anything changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bases = require(script.Parent.Bases)
local Economy = require(script.Parent.Economy)
local Storm = require(script.Parent.Storm)
local State = require(script.Parent.State)

local Remotes = {}

local remotes: Folder

function Remotes.init()
	remotes = ReplicatedStorage:WaitForChild("StarfallRemotes")

	remotes.PlaceRotling.OnServerEvent:Connect(function(player: Player)
		Bases.tryPlace(player)
	end)

	remotes.ToggleLock.OnServerEvent:Connect(function(player: Player)
		local ok, message = Bases.lockBase(player)
		Remotes.fireBanner(player, message, 3)
		if ok then
			Remotes.broadcastHud()
		end
	end)

	remotes.BuyItem.OnServerInvoke = function(player: Player, itemName: string)
		local ok, message = Economy.buyItem(player, itemName)
		return ok, message
	end

	remotes.DoRebirth.OnServerInvoke = function(player: Player)
		local ok, message = Economy.doRebirth(player)
		return ok, message
	end
end

function Remotes.fireBanner(player: Player, text: string, duration: number)
	remotes.ShowBanner:FireClient(player, text, duration or 3)
end

function Remotes.fireBannerAll(text: string, duration: number)
	remotes.ShowBanner:FireAllClients(text, duration or 3)
end

-- Send every player their current HUD numbers.
function Remotes.broadcastHud()
	local storm = Storm.getStatus()
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = State.profiles[player.UserId]
		if profile then
			local baseId = Bases.getPlayerBase(player.UserId)
			remotes.UpdateHud:FireClient(player, {
				coins = profile.coins,
				cps = Economy.coinsPerSecond(player),
				rebirths = profile.rebirths,
				speedTier = profile.speedTier,
				carryTier = profile.carryTier,
				incomeTier = profile.incomeTier,
				carried = #Bases.getCarried(player),
				carrySlots = Bases.getCarrySlots(player),
				lockRemaining = if baseId then Bases.lockRemaining(baseId) else 0,
				lockCooldown = if baseId then Bases.lockCooldownRemaining(baseId) else 0,
				stormPhase = storm.phase,
				stormSeconds = storm.secondsLeft,
				index = profile.index,
			})
		end
	end
end

return Remotes
