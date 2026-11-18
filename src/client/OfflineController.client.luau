--!strict
-- Starfall Rotlings: offline earnings popup.
-- On join, the server pays the away-time earnings and fires the
-- OfflineEarnings remote with the amount. This controller shows the
-- "While you were away, your Rotlings earned $X" panel in the middle
-- of the screen, with a Nice! button and a 10-second auto-dismiss.
-- It sits below the title screen (ZIndex 40 vs 50), so a player who
-- has not pressed PLAY yet sees it right after they do.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local gui = GuiKit.getGui()

local popup = GuiKit.makePanel(gui, "OfflinePopup", UDim2.new(0, 480, 0, 220), UDim2.new(0.5, -240, 0.5, -110))
popup.Visible = false
popup.ZIndex = 40
GuiKit.makeLabel(popup, "OfflineTitle", "💰 WHILE YOU WERE AWAY...", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 12), 26, GuiKit.COLORS.Gold).ZIndex = 41
local amountLabel = GuiKit.makeLabel(popup, "OfflineAmount", "", UDim2.new(1, -32, 0, 44), UDim2.new(0, 16, 0, 60), 24, GuiKit.COLORS.White)
amountLabel.ZIndex = 41
local subLabel = GuiKit.makeLabel(popup, "OfflineSub", "Your Rotlings keep earning while you're away (up to 8 hours).", UDim2.new(1, -32, 0, 30), UDim2.new(0, 16, 0, 112), 16, GuiKit.COLORS.White)
subLabel.ZIndex = 41
local dismissButton = GuiKit.makeButton(popup, "OfflineDismiss", "Nice!", UDim2.new(0, 200, 0, 48), UDim2.new(0.5, -100, 0, 152), GuiKit.COLORS.Buy)
dismissButton.ZIndex = 41
dismissButton.MouseButton1Click:Connect(function()
	popup.Visible = false
end)

-- The remote lookup is retried in a loop so a slow ReplicatedStorage
-- replication can never silently kill the popup (same pattern as the
-- HUD feed).
task.spawn(function()
	while true do
		local ok, offlineEvent = pcall(function()
			return Remotes.offlineEvent()
		end)
		if ok and offlineEvent then
			offlineEvent.OnClientEvent:Connect(function(amount: number)
				amountLabel.Text = "Your Rotlings earned " .. Formatting.formatMoney(amount) .. "!"
				popup.Visible = true
				task.delay(10, function()
					popup.Visible = false
				end)
			end)
			print("[Offline] connected to OfflineEarnings")
			break
		end
		task.wait(1)
	end
end)

print("Starfall Rotlings offline earnings ready.")
