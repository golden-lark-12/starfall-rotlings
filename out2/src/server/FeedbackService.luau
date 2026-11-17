--!strict
-- Starfall Rotlings: action feedback.
-- One place for the feel of every action: a sound, a particle burst
-- and a floating cash pop-up. Every sound is the one built-in ping the
-- game already uses (rbxasset://sounds/electronicpingshort.wav), only
-- pitched and volumed differently per action — no new asset IDs to
-- verify. Bursts and pop-ups are built from Parts at runtime, so
-- nothing needs a pre-placed emitter.
--
-- Every action in the loop calls this: grab, place, buy, rebirth,
-- sell, mission complete, daily claim. A silent action is a bug.

local FeedbackService = {}

local PING_SOUND = "rbxasset://sounds/electronicpingshort.wav"

-- Play the ping on the player's character, pitched per action.
function FeedbackService.playSound(player: Player, pitch: number, volume: number?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = PING_SOUND
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = pitch
	sound.Parent = root
	sound:Play()
	task.delay(1, function()
		sound:Destroy()
	end)
end

-- A gold sparkle burst on a model (its PrimaryPart) or a bare part.
function FeedbackService.burst(target: Instance, color: Color3?)
	local part: BasePart? = nil
	if target:IsA("BasePart") then
		part = target
	elseif target:IsA("Model") then
		local primary = (target :: Model).PrimaryPart
		if primary and primary:IsA("BasePart") then
			part = primary
		end
	end
	if not part then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "FeedbackBurst"
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(255, 225, 90))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = part
	emitter:Emit(24)
	task.delay(1.5, function()
		emitter:Destroy()
	end)
end

-- A floating "+$N" (or any short text) above a model, rising and fading.
function FeedbackService.cashPopup(target: Model, text: string, color: Color3?)
	local body = target.PrimaryPart
	if not body then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CashPopup"
	billboard.Size = UDim2.fromOffset(160, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.fromRGB(255, 230, 90)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
	local TweenService = game:GetService("TweenService")
	TweenService:Create(billboard, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, 8, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.3, function()
		billboard:Destroy()
	end)
end

-- The full celebration: bright ping + gold burst on the player. Used
-- by buys, rebirths, mission completions and daily claims.
function FeedbackService.celebrate(player: Player)
	FeedbackService.playSound(player, 1.6, 0.7)
	local character = player.Character
	if character then
		FeedbackService.burst(character, Color3.fromRGB(255, 225, 90))
	end
end

return FeedbackService
