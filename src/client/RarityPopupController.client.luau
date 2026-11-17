--!strict
-- Starfall Rotlings: rarity popup controller.
-- When the server says you grabbed something Epic or better, a big
-- rarity banner fills the middle of the screen: the creature's name in
-- its rarity colour, its mutation, and its coins-per-second. It fades
-- on its own after a few seconds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formatting = require(ReplicatedStorage.Shared.Formatting)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local gui = GuiKit.getGui()

local popup = GuiKit.makeLabel(gui, "RarityPopup", "", UDim2.new(0, 640, 0, 130), UDim2.new(0.5, -320, 0, 210), 44, Color3.fromRGB(255, 255, 255))
popup.Visible = false
popup.TextWrapped = true

local popupToken = 0

Remotes.rarityPopupEvent().OnClientEvent:Connect(function(name: string, rarity: string, mutation: string?, cps: number)
	local rarityConfig = RarityConfig.rarityByName(rarity)
	local title = rarity:upper() .. "!"
	if mutation then
		title ..= " " .. mutation:upper()
	end
	popup.Text = "🌟 " .. title .. " 🌟\n" .. name .. " — " .. Formatting.formatMoney(cps) .. "/s"
	popup.TextColor3 = rarityConfig.color
	popup.Visible = true
	popupToken += 1
	local token = popupToken
	task.delay(3, function()
		if token == popupToken then
			popup.Visible = false
		end
	end)
end)

print("Starfall Rotlings rarity popup ready.")
