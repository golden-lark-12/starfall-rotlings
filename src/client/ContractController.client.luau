--!strict
-- Starfall Rotlings: Contract Board controller.
-- The visible board where the player picks up contracts and claims
-- rewards. Three contracts at a time from the server (MissionService):
-- the board panel lists each with its progress bar and a Claim button.
-- Finishing a contract marks it ready; the player claims it here (or
-- at the world board in the plaza, which fires the OpenContracts
-- remote) — or the server AUTO-CLAIMS it 10s later (fix round 9, item
-- 8), so a finished contract never sits at 1/1 waiting. Claiming
-- deals a fresh contract from the pool. Opens from the Contracts
-- button (top-left row), the world board's prompt, or the quest pill's
-- board hint. The client only ever shows what the HUD feed sends;
-- claiming is validated server-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formatting = require(ReplicatedStorage.Shared.Formatting)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GuiKit = require(script.Parent:WaitForChild("GuiKit"))

local player = Players.LocalPlayer
local gui = GuiKit.getGui()

-- Contracts button, top-left row next to Daily: always visible, so
-- the board is one tap away even when the player is far from the
-- plaza board.
local contractsButton = GuiKit.makeButton(gui, "ContractsButton", "📋 Contracts", UDim2.new(0, 120, 0, 44), UDim2.new(0, 396, 0, 60), GuiKit.COLORS.Gold)

-- Panel: 480x400 centred (one list, 52px rows), Close top-right.
local contractPanel = GuiKit.makePanel(gui, "ContractPanel", UDim2.new(0, 480, 0, 400), UDim2.new(0.5, -240, 0.5, -200))
contractPanel.Visible = false
GuiKit.makeLabel(contractPanel, "Title", "📋 CONTRACT BOARD", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 8), 30, GuiKit.COLORS.White)
local contractClose = GuiKit.makeButton(contractPanel, "Close", "X", UDim2.new(0, 40, 0, 40), UDim2.new(1, -48, 0, 8), GuiKit.COLORS.Close)
local contractHint = GuiKit.makeLabel(contractPanel, "Hint", "Finish a contract, then claim it here — claiming deals a new one.", UDim2.new(1, -20, 0, 20), UDim2.new(0, 10, 0, 52), 14, Color3.fromRGB(200, 200, 220))

type ContractRow = {
	id: string,
	text: string,
	target: number,
	reward: number,
	progress: number,
	done: boolean,
	claimed: boolean,
	advanceIn: number?, -- seconds left on the auto-advance timer (nil unless done — fix round 9, item 8)
}

local contracts: { ContractRow } = {}
local refreshContracts: () -> ()
local rows: { { frame: Frame, textLabel: TextLabel, fill: Frame, progressLabel: TextLabel, claimButton: TextButton } } = {}

do
	for i = 1, 3 do
		local rowFrame = Instance.new("Frame")
		rowFrame.Name = "ContractRow" .. tostring(i)
		rowFrame.Size = UDim2.new(1, -20, 0, 88)
		rowFrame.Position = UDim2.new(0, 10, 0, 80 + (i - 1) * 96)
		rowFrame.BackgroundColor3 = Color3.fromRGB(50, 45, 90)
		rowFrame.BackgroundTransparency = 0.1
		rowFrame.BorderSizePixel = 0
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 10)
		rowCorner.Parent = rowFrame
		rowFrame.Parent = contractPanel

		local textLabel = GuiKit.makeLabel(rowFrame, "Text", "", UDim2.new(1, -130, 0, 22), UDim2.new(0, 10, 0, 8), 17, GuiKit.COLORS.White)
		textLabel.TextXAlignment = Enum.TextXAlignment.Left
		textLabel.TextTruncate = Enum.TextTruncate.AtEnd

		-- Progress bar: fills as the contract advances.
		local barBg = Instance.new("Frame")
		barBg.Name = "ProgressBg"
		barBg.Size = UDim2.new(1, -130, 0, 10)
		barBg.Position = UDim2.new(0, 10, 0, 36)
		barBg.BackgroundColor3 = Color3.fromRGB(25, 20, 45)
		barBg.BorderSizePixel = 0
		barBg.Parent = rowFrame
		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(0, 5)
		barCorner.Parent = barBg
		local fill = Instance.new("Frame")
		fill.Name = "ProgressFill"
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
		fill.BorderSizePixel = 0
		fill.Parent = barBg
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 5)
		fillCorner.Parent = fill

		-- Progress + reward line under the bar.
		local progressLabel = GuiKit.makeLabel(rowFrame, "Progress", "", UDim2.new(1, -130, 0, 20), UDim2.new(0, 10, 0, 54), 15, Color3.fromRGB(255, 230, 90))
		progressLabel.TextXAlignment = Enum.TextXAlignment.Left

		-- Claim button: green + reward when ready, grey with the
		-- count while in progress, ticked when claimed.
		local claimButton = GuiKit.makeButton(rowFrame, "Claim", "Claim", UDim2.new(0, 104, 0, 44), UDim2.new(1, -114, 0, 22), GuiKit.COLORS.Buy)
		claimButton.TextSize = 16
		claimButton.MouseButton1Click:Connect(function()
			local contract = contracts[i]
			if not contract then
				return
			end
			local ok, message = Remotes.claimContractFunction():InvokeServer(contract.id)
			GuiKit.showBanner(gui, message, 4)
			if ok then
				-- The next HUD feed (within a second) refreshes the
				-- rows with the fresh contract; mark it claimed now
				-- so the button cannot double-fire meanwhile.
				contract.claimed = true
				refreshContracts()
			end
		end)
		table.insert(rows, { frame = rowFrame, textLabel = textLabel, fill = fill, progressLabel = progressLabel, claimButton = claimButton })
	end
end

function refreshContracts()
	for i, row in ipairs(rows) do
		local contract = contracts[i]
		if not contract then
			row.frame.Visible = false
		else
			row.frame.Visible = true
			row.textLabel.Text = contract.text
			local target = math.max(1, contract.target)
			row.fill.Size = UDim2.new(math.clamp(contract.progress / target, 0, 1), 0, 1, 0)
			row.progressLabel.Text = tostring(math.min(contract.progress, target)) .. "/" .. tostring(target) .. "  •  Reward " .. Formatting.formatMoney(contract.reward)
			if contract.claimed then
				row.claimButton.Text = "✓ Claimed"
				row.claimButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
			elseif contract.done then
				row.claimButton.Text = "Claim " .. Formatting.formatMoney(contract.reward)
				row.claimButton.BackgroundColor3 = GuiKit.COLORS.Buy
				-- (fix round 9, item 8) the auto-advance countdown:
				-- the row never sits at a silent 1/1.
				if contract.advanceIn then
					row.progressLabel.Text = "✅ Complete! Next contract in " .. tostring(contract.advanceIn) .. "s  •  Reward " .. Formatting.formatMoney(contract.reward)
					row.claimButton.Text = "Claim " .. Formatting.formatMoney(contract.reward) .. " (" .. tostring(contract.advanceIn) .. "s)"
				end
			else
				row.claimButton.Text = tostring(math.min(contract.progress, target)) .. "/" .. tostring(target)
				row.claimButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
			end
		end
	end
end

local function toggleContracts()
	local wasOpen = contractPanel.Visible
	GuiKit.closeOtherPanels(gui, "ContractPanel")
	contractPanel.Visible = not wasOpen
	if contractPanel.Visible then
		refreshContracts()
	end
end

contractsButton.MouseButton1Click:Connect(toggleContracts)
contractClose.MouseButton1Click:Connect(function()
	contractPanel.Visible = false
end)

-- The world board's prompt (MissionService fires this at the player
-- who pressed E on the plaza board).
task.spawn(function()
	while true do
		local ok, event = pcall(function()
			return Remotes.openContractsEvent()
		end)
		if ok and event then
			event.OnClientEvent:Connect(function()
				if not contractPanel.Visible then
					toggleContracts()
				end
			end)
			break
		end
		task.wait(1)
	end
end)

Remotes.hudEvent().OnClientEvent:Connect(function(data: Remotes.HudData)
	contracts = data.contracts or {}
	if contractPanel.Visible then
		refreshContracts()
	end
end)

print("Starfall Brainrots contracts ready.")
