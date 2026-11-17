--!strict
-- Starfall Rotlings: the client/server wire.
-- The one typed way to reach ReplicatedStorage.StarfallRemotes, whose
-- members are declared in default.project.json. The client never sends a
-- number the server trusts: buys, rebirths, locks and placements are all
-- validated on the server before anything changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type HudData = {
	coins: number,
	stardust: number,
	xp: number,
	level: number,
	xpProgress: number, -- 0..1 toward the next level
	cps: number,
	rebirths: number,
	rebirthCost: number,
	rebirthProgress: number, -- 0..1 toward the next rebirth
	speedTier: number,
	carryTier: number,
	incomeTier: number,
	padsTier: number,
	lockTier: number,
	carried: number,
	carrySlots: number,
	lockRemaining: number,
	lockCooldown: number,
	stormPhase: string,
	stormSeconds: number,
	danger: number, -- 0..1 "Meteor Danger" meter: fills as the next storm approaches
	index: { [string]: boolean },
	indexCount: number,
	indexTotal: number,
	top3: { { name: string, coins: number } },
	firstTime: boolean,
	missionText: string,
	missionProgress: number,
	missionTarget: number,
	missionReward: number,
	dailyReady: boolean,
	boosts: { { kind: string, seconds: number } },
	belt: { { name: string, cps: number } },
	eventName: string,
	eventSeconds: number,
	buddyName: string?,
}

local Remotes = {}

local folder: Folder? = nil

function Remotes.getFolder(): Folder
	if folder == nil then
		folder = ReplicatedStorage:WaitForChild("StarfallRemotes", 10) :: Folder
	end
	return folder :: Folder
end

function Remotes.placeEvent(): RemoteEvent
	return Remotes.getFolder():WaitForChild("PlaceRotling") :: RemoteEvent
end

function Remotes.sellEvent(): RemoteEvent
	return Remotes.getFolder():WaitForChild("SellRotling") :: RemoteEvent
end

function Remotes.dailyFunction(): RemoteFunction
	return Remotes.getFolder():WaitForChild("ClaimDaily") :: RemoteFunction
end

function Remotes.lockEvent(): RemoteEvent
	return Remotes.getFolder():WaitForChild("ToggleLock") :: RemoteEvent
end

function Remotes.buyFunction(): RemoteFunction
	return Remotes.getFolder():WaitForChild("BuyItem") :: RemoteFunction
end

function Remotes.rebirthFunction(): RemoteFunction
	return Remotes.getFolder():WaitForChild("DoRebirth") :: RemoteFunction
end

function Remotes.bannerEvent(): RemoteEvent
	return Remotes.getFolder():WaitForChild("ShowBanner") :: RemoteEvent
end

function Remotes.hudEvent(): RemoteEvent
	return Remotes.getFolder():WaitForChild("UpdateHud") :: RemoteEvent
end

function Remotes.rarityPopupEvent(): RemoteEvent
	return Remotes.getFolder():WaitForChild("RarityPopup") :: RemoteEvent
end

function Remotes.meteorImpactEvent(): RemoteEvent
	return Remotes.getFolder():WaitForChild("MeteorImpact") :: RemoteEvent
end

function Remotes.slapEvent(): RemoteEvent
	return Remotes.getFolder():WaitForChild("SlapSwing") :: RemoteEvent
end

function Remotes.slapEffectEvent(): RemoteEvent
	return Remotes.getFolder():WaitForChild("SlapEffect") :: RemoteEvent
end

function Remotes.openShopEvent(): RemoteEvent
	return Remotes.getFolder():WaitForChild("OpenShop") :: RemoteEvent
end

function Remotes.openRebirthEvent(): RemoteEvent
	return Remotes.getFolder():WaitForChild("OpenRebirth") :: RemoteEvent
end

function Remotes.setBuddyFunction(): RemoteFunction
	return Remotes.getFolder():WaitForChild("SetBuddy") :: RemoteFunction
end

function Remotes.buyBoostFunction(): RemoteFunction
	return Remotes.getFolder():WaitForChild("BuyBoost") :: RemoteFunction
end

function Remotes.rerollFunction(): RemoteFunction
	return Remotes.getFolder():WaitForChild("RerollMutation") :: RemoteFunction
end

return Remotes
