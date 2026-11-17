--!strict
-- Starfall Rotlings: shared client GUI kit.
-- The small builders every controller uses (labels, buttons, panels) and
-- the helpers for finding the one ScreenGui and closing other panels.
-- Pure construction: no game logic lives here.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local GuiKit = {}

-- One palette for the whole HUD, so every button and panel matches:
-- dark purple panels, gold coins, green income, red lock, blue shop,
-- purple index, pink rebirth.
GuiKit.COLORS = {
	Panel = Color3.fromRGB(30, 25, 55),
	PanelLight = Color3.fromRGB(50, 45, 90),
	Gold = Color3.fromRGB(255, 225, 90),
	Green = Color3.fromRGB(160, 255, 170),
	Red = Color3.fromRGB(255, 90, 90),
	Blue = Color3.fromRGB(90, 160, 255),
	Purple = Color3.fromRGB(180, 110, 255),
	Pink = Color3.fromRGB(255, 110, 180),
	Close = Color3.fromRGB(200, 60, 60),
	Buy = Color3.fromRGB(80, 200, 100),
	White = Color3.fromRGB(255, 255, 255),
}

function GuiKit.getGui(): ScreenGui
	local player = Players.LocalPlayer
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("StarfallGui", 10) :: ScreenGui
	return gui
end

function GuiKit.makeLabel(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.FredokaOne
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 0.5
	stroke.Color = Color3.fromRGB(20, 10, 40)
	stroke.Parent = label
	label.Parent = parent
	return label
end

function GuiKit.makeButton(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Text = text
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 20
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextStrokeTransparency = 0.3
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 0.5
	stroke.Color = Color3.fromRGB(20, 10, 40)
	stroke.Parent = button
	-- Bouncy press: shrink a touch on press, spring back on release.
	local originalSize = size
	local function pressedSize(): UDim2
		return UDim2.new(size.X.Scale, math.floor(size.X.Offset * 0.94), size.Y.Scale, math.floor(size.Y.Offset * 0.94))
	end
	button.MouseButton1Down:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = pressedSize(),
		}):Play()
	end)
	local function release()
		TweenService:Create(button, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = originalSize,
		}):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	button.Parent = parent
	return button
end

function GuiKit.makePanel(parent: Instance, name: string, size: UDim2, position: UDim2): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Size = size
	panel.Position = position
	panel.BackgroundColor3 = Color3.fromRGB(30, 25, 55)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.7
	stroke.Thickness = 2
	stroke.Parent = panel
	panel.Parent = parent
	return panel
end

-- Hide every open panel except the one named, so only one is up at once.
function GuiKit.closeOtherPanels(gui: ScreenGui, exceptName: string?)
	for _, child in ipairs(gui:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= exceptName and (child.Name == "ShopPanel" or child.Name == "IndexPanel" or child.Name == "RebirthPanel") then
			child.Visible = false
		end
	end
end

-- The shared "open the shop" signal: the HUD's Upgrade button fires it
-- and the ShopController answers it (LocalScripts cannot require each
-- other, so a BindableEvent in the ScreenGui is the wire).
function GuiKit.openShopEvent(gui: ScreenGui): BindableEvent
	local existing = gui:FindFirstChild("OpenShop")
	if existing and existing:IsA("BindableEvent") then
		return existing
	end
	local event = Instance.new("BindableEvent")
	event.Name = "OpenShop"
	event.Parent = gui
	return event
end

local bannerToken = 0

-- Show the shared centre banner line for a few seconds.
function GuiKit.showBanner(gui: ScreenGui, text: string, duration: number)
	local banner = gui:FindFirstChild("Banner")
	if not banner or not banner:IsA("TextLabel") then
		return
	end
	bannerToken += 1
	local token = bannerToken
	banner.Text = text
	banner.Visible = true
	task.delay(duration, function()
		if token == bannerToken then
			banner.Visible = false
		end
	end)
end

return GuiKit
