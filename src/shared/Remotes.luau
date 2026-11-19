--!strict
-- Starfall Rotlings: the client/server wire.
-- The one typed way to reach ReplicatedStorage.StarfallRemotes, whose
-- members are declared in default.project.json. The client never sends a
-- number the server trusts: buys, rebirths, locks and placements are all
-- validated on the server before anything changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type HudData = {
	coins: number, -- TOTAL wealth: wallet + uncollected base cash (fix 3). The big HUD number. Income banks at the base, so the wallet alone is not what the player has.
	banked: number, -- cash sitting at the base, waiting to be collected
	stardust: number,
	xp: number,
	level: number,
	xpProgress: number, -- 0..1 toward the next level
	cps: number,
	stormBoost: boolean, -- inside your own Safe Dome during the storm: income x2
	baseCps: number, -- income/s WITHOUT the storm boost (the normal rate, shown next to the boosted one)
	rebirths: number,
	rebirthCost: number,
	rebirthProgress: number, -- 0..1 toward the next rebirth
	speedTier: number,
	carryTier: number,
	incomeTier: number,
	padsTier: number,
	lockTier: number,
	staminaTier: number, -- Endurance Training tier (fix round 8, item 6)
	eggTier: number, -- Egg Warmer tier (fix round 8, item 6)
	slapTier: number, -- Power Slap tier (fix round 8, item 6)
	carried: number,
	carrySlots: number,
	carriedName: string?, -- name of the Rotling being carried (for the CARRYING banner)
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
	missionAdvanceIn: number?, -- seconds left on the auto-advance timer for the pill's contract (nil unless done — fix round 9, item 8)
	contracts: { { id: string, text: string, target: number, reward: number, progress: number, done: boolean, claimed: boolean, advanceIn: number? } }, -- the Contract Board: three active contracts with their progress (+ auto-advance countdown)
	mutations: { [string]: boolean }, -- mutations this player has collected (index row)
	dailyReady: boolean,
	boosts: { { kind: string, seconds: number } },
	belt: { { name: string, cps: number } },
	eventName: string,
	eventSeconds: number,
	buddyName: string?,
	eggCarried: boolean, -- carrying a meteor egg (walk slower)
	guardianActive: boolean, -- a Crater Guardian is chasing this player (THE CHASE)
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

function Remotes.dropEggEvent(): RemoteEvent
	return Remotes.getFolder():WaitForChild("DropEgg") :: RemoteEvent
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

function Remotes.offlineEvent(): RemoteEvent
	return Remotes.getFolder():WaitForChild("OfflineEarnings") :: RemoteEvent
end

function Remotes.collectBankFunction(): RemoteFunction
	return Remotes.getFolder():WaitForChild("CollectBank") :: RemoteFunction
end

function Remotes.claimContractFunction(): RemoteFunction
	return Remotes.getFolder():WaitForChild("ClaimContract") :: RemoteFunction
end

function Remotes.openContractsEvent(): RemoteEvent
	return Remotes.getFolder():WaitForChild("OpenContracts") :: RemoteEvent
end

return Remotes
