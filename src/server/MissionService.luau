--!strict
-- Starfall Rotlings: contracts (the Contract Board).
-- Three contracts at a time from Config.CONTRACTS, dealt in pool
-- order. Progress is counted on the server only (grabs, places,
-- coins earned, Rare+ grabs); finishing one marks it READY, and the
-- player CLAIMS the reward at the Contract Board (the world board by
-- the plaza, or the Contracts button) — or the server AUTO-CLAIMS it
-- 10s later (fix round 9, item 8), so a finished contract never sits
-- at 1/1 waiting. Claiming (manual or auto) deals a fresh contract
-- from the pool, and a fresh grab/rare contract fires a hook banner.
-- The HUD feed carries all three contracts for the board panel, and
-- the first unclaimed one doubles as the quest pill
-- (currentMission / progress keep the old single-mission shape, so
-- the HUD never changes shape).
-- Nothing here trusts the client: it only ever reports progress the
-- server itself observed, and claiming is validated here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local FeedbackService = require(script.Parent.FeedbackService)
local State = require(script.Parent.State)
-- BaseService does NOT require MissionService, so a top-level require
-- here is safe (no circular require). It is only needed for the live
-- placed count in syncPlaceMission.
local BaseService = require(script.Parent.BaseService)

local MissionService = {}

export type Mission = {
	id: string,
	text: string,
	target: number,
	reward: number,
}

export type ContractState = {
	id: string,
	progress: number,
	done: boolean,
	claimed: boolean,
	advanceAt: number?, -- when the auto-advance timer fires (set by markReady, fix round 9, item 8)
}

-- The pool definition for a contract id, or nil.
local function contractDef(id: string): { id: string, kind: string, text: string, target: number, reward: number }?
	for _, def in ipairs(Config.CONTRACTS) do
		if def.id == id then
			return def
		end
	end
	return nil
end

-- Deal contracts until the player holds CONTRACTS_AT_ONCE: the next
-- pool contracts (in pool order) that are not already active. A
-- claimed slot is replaced by claimContract, never here, so this only
-- ever fills an empty board (first join, or an old save).
function MissionService.dealContracts(player: Player)
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	if typeof(profile.contracts) ~= "table" then
		profile.contracts = {}
	end
	local active: { [string]: boolean } = {}
	for _, slot in ipairs(profile.contracts) do
		active[slot.id] = true
	end
	for _, def in ipairs(Config.CONTRACTS) do
		if #profile.contracts >= Config.CONTRACTS_AT_ONCE then
			break
		end
		if not active[def.id] then
			table.insert(profile.contracts, { id = def.id, progress = 0, done = false, claimed = false })
			active[def.id] = true
		end
	end
end

-- All active contracts with their pool text and reward, for the HUD
-- feed (the board panel reads this). Deals first if the board is empty.
-- advanceIn is the seconds left on the auto-advance timer for a done
-- contract (nil otherwise) — the board + quest pill show the countdown
-- (fix round 9, item 8).
function MissionService.activeContracts(player: Player): { { id: string, text: string, target: number, reward: number, progress: number, done: boolean, claimed: boolean, advanceIn: number? } }
	MissionService.dealContracts(player)
	local profile = DataService.getProfile(player)
	local out: { { id: string, text: string, target: number, reward: number, progress: number, done: boolean, claimed: boolean, advanceIn: number? } } = {}
	if not profile then
		return out
	end
	for _, slot in ipairs(profile.contracts) do
		local def = contractDef(slot.id)
		if def then
			table.insert(out, {
				id = slot.id,
				text = def.text,
				target = def.target,
				reward = def.reward,
				progress = slot.progress,
				done = slot.done,
				claimed = slot.claimed,
				advanceIn = if slot.done and not slot.claimed and slot.advanceAt
					then math.max(0, math.ceil(slot.advanceAt - time()))
					else nil,
			})
		end
	end
	return out
end

-- Seconds left on the auto-advance timer for the first unclaimed
-- contract (the quest pill's contract), or nil. The pill shows
-- "✅ Complete! Next contract in Ns…" instead of a stuck 1/1.
function MissionService.currentAdvanceIn(player: Player): number?
	local profile = DataService.getProfile(player)
	if not profile then
		return nil
	end
	for _, slot in ipairs(profile.contracts) do
		if not slot.claimed then
			if slot.done and slot.advanceAt then
				return math.max(0, math.ceil(slot.advanceAt - time()))
			end
			return nil
		end
	end
	return nil
end

-- The first unclaimed contract, as the quest pill's single mission.
-- The pill shows one contract at a time ("Grab 3 Brainrots 1/3");
-- the board shows all three.
function MissionService.currentMission(player: Player): Mission
	MissionService.dealContracts(player)
	local profile = DataService.getProfile(player)
	if profile then
		for _, slot in ipairs(profile.contracts) do
			if not slot.claimed then
				local def = contractDef(slot.id)
				if def then
					return { id = def.id, text = def.text, target = def.target, reward = def.reward }
				end
			end
		end
	end
	local first = Config.CONTRACTS[1]
	return { id = first.id, text = first.text, target = first.target, reward = first.reward }
end

function MissionService.progress(player: Player): number
	MissionService.dealContracts(player)
	local profile = DataService.getProfile(player)
	if not profile then
		return 0
	end
	for _, slot in ipairs(profile.contracts) do
		if not slot.claimed then
			return slot.progress
		end
	end
	return 0
end

-- Mark one contract ready: banner + sound, but NO payout — the
-- player claims the reward at the board. Shared by addProgress and
-- syncPlaceMission so the two paths cannot drift. The auto-advance
-- timer starts here: 10s after a contract is done, the server
-- auto-claims it (pays the reward, deals the next one) — a finished
-- contract never sits at 1/1 waiting (fix round 9, item 8).
local function markReady(player: Player, slot: ContractState)
	local def = contractDef(slot.id)
	if not def then
		return
	end
	slot.done = true
	slot.progress = def.target
	slot.advanceAt = time() + 10
	FeedbackService.playSound(player, 1.8, 0.9)
	Remotes.bannerEvent():FireClient(player, "📋 Contract ready: " .. def.text .. " — claim " .. Formatting.formatMoney(def.reward) .. " at the Contract Board!", 5)
	print("[Contract] " .. player.Name .. " finished " .. slot.id .. " (" .. def.text .. ") — ready to claim " .. Formatting.formatMoney(def.reward) .. " (auto-claim in 10s)")
end

-- Report server-observed progress toward every active contract of
-- the matching kind. Only the matching kind counts; anything else is
-- ignored. Progress caps at the target; completion marks the contract
-- ready (claim it at the board).
function MissionService.addProgress(player: Player, kind: string, amount: number)
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	MissionService.dealContracts(player)
	for _, slot in ipairs(profile.contracts) do
		if not slot.claimed and not slot.done then
			local def = contractDef(slot.id)
			if def and def.kind == kind then
				slot.progress = math.min(slot.progress + amount, def.target)
				if slot.progress >= def.target then
					markReady(player, slot)
				end
			end
		end
	end
end

-- Sync the "place" contracts to the live placed count (fix round 4,
-- item 3, carried over from the old single mission): a player who
-- already has enough placed when a "place" contract is dealt
-- completes it on join instead of staring at 0/3. Called on
-- join/restore (CarryService.restorePlaced) and after every claim
-- (claimContract deals a fresh contract that might already be
-- satisfied).
function MissionService.syncPlaceMission(player: Player)
	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	MissionService.dealContracts(player)
	local placed = #BaseService.getPlacedForPlayer(player)
	for _, slot in ipairs(profile.contracts) do
		if not slot.claimed and not slot.done then
			local def = contractDef(slot.id)
			if def and def.kind == "place" and placed > slot.progress then
				slot.progress = placed
				if placed >= def.target then
					markReady(player, slot)
				end
			end
		end
	end
end

-- Deal the replacement into a claimed slot: the next pool contract
-- (in pool order, wrapping) that is not already active. Shared by
-- claimContract and the auto-advance loop, so a manual claim and an
-- auto-claim deal identically. HOOK (fix round 9, item 8): when the
-- fresh contract is a grab or a rare grab, the player gets a banner +
-- sound that hooks them into fetching — the contract is the next
-- thing to do, not a line on a board.
local function dealReplacement(player: Player, profile: State.Profile, slotIndex: number, contractId: string)
	local active: { [string]: boolean } = {}
	for _, other in ipairs(profile.contracts) do
		active[other.id] = true
	end
	active[contractId] = nil -- the claimed one leaves the board
	local startAt = 1
	for i, poolDef in ipairs(Config.CONTRACTS) do
		if poolDef.id == contractId then
			startAt = i + 1
			break
		end
	end
	for offset = 0, #Config.CONTRACTS - 1 do
		local candidate = Config.CONTRACTS[((startAt - 1 + offset) % #Config.CONTRACTS) + 1]
		if not active[candidate.id] then
			profile.contracts[slotIndex] = { id = candidate.id, progress = 0, done = false, claimed = false, advanceAt = nil }
			if candidate.kind == "grab" or candidate.kind == "rare" then
				FeedbackService.playSound(player, 1.8, 0.9)
				Remotes.bannerEvent():FireClient(player, "🎯 NEW CONTRACT: " .. candidate.text .. " — go fetch!", 5)
				print("[Contract] " .. player.Name .. " dealt " .. candidate.id .. " (" .. candidate.text .. ") — hook banner fired")
			end
			break
		end
	end
end

-- Claim a finished contract: pay the reward, mark the slot claimed,
-- and deal a fresh contract from the pool into its place. Returns
-- (ok, message) for the ClaimContract remote.
function MissionService.claimContract(player: Player, contractId: string): (boolean, string)
	local profile = DataService.getProfile(player)
	if not profile then
		return false, "Profile not loaded yet."
	end
	MissionService.dealContracts(player)
	local slotIndex: number? = nil
	local slot: ContractState? = nil
	for i, candidate in ipairs(profile.contracts) do
		if candidate.id == contractId then
			slotIndex = i
			slot = candidate
			break
		end
	end
	if not slot then
		return false, "That contract is not on your board."
	end
	if slot.claimed then
		return false, "Already claimed."
	end
	if not slot.done then
		local def = contractDef(contractId)
		local target = if def then def.target else 0
		return false, "Not finished yet — " .. tostring(slot.progress) .. "/" .. tostring(target) .. "."
	end
	local def = contractDef(contractId)
	if not def then
		return false, "Unknown contract."
	end
	profile.coins += def.reward
	slot.claimed = true
	slot.advanceAt = nil
	dealReplacement(player, profile, slotIndex :: number, contractId)
	DataService.saveProfile(player)
	FeedbackService.celebrate(player)
	MissionService.syncPlaceMission(player)
	print("[Contract] " .. player.Name .. " claimed " .. contractId .. " (+" .. Formatting.formatMoney(def.reward) .. ")")
	return true, "Contract complete! +" .. Formatting.formatMoney(def.reward) .. " — a new contract is on the board."
end

-- Auto-advance loop (fix round 9, item 8): every 1s, any done
-- contract whose 10s timer expired is auto-claimed — reward paid,
-- replacement dealt, no trip to the board needed. A contract that
-- shows 1/1 never sits there waiting.
function MissionService.start()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataService.getProfile(player)
				if profile then
					for i, slot in ipairs(profile.contracts) do
						if slot.done and not slot.claimed and slot.advanceAt and time() >= slot.advanceAt then
							local def = contractDef(slot.id)
							if def then
								profile.coins += def.reward
								slot.claimed = true
								slot.advanceAt = nil
								dealReplacement(player, profile, i, slot.id)
								DataService.saveProfile(player)
								FeedbackService.celebrate(player)
								MissionService.syncPlaceMission(player)
								print("[Contract] " .. player.Name .. " auto-claimed " .. slot.id .. " (+" .. Formatting.formatMoney(def.reward) .. ") — next contract dealt")
							end
						end
					end
				end
			end
		end
	end)
end

-- Wire the ClaimContract remote and the world board's prompt: pressing
-- E on the Contract Board opens the board panel for that player.
function MissionService.init()
	Remotes.claimContractFunction().OnServerInvoke = function(player: Player, contractId: string)
		local ok, message = MissionService.claimContract(player, contractId)
		return ok, message
	end
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and descendant.Name == "ContractBoardPrompt" then
			descendant.Triggered:Connect(function(player: Player)
				Remotes.openContractsEvent():FireClient(player)
			end)
		end
	end
end

return MissionService
