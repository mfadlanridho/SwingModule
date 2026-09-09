--!strict
--[[
    TetherRenderer.luau (SwingModule)
    Zero-dependency, standalone visual rope / tether generator for Roblox swinging.
    Creates and updates an anchored invisible part and a dynamic Beam connecting
    the character's hand to the physical swing anchor.
--]]

local Workspace = game:GetService("Workspace")

local Types = require(script.Parent.Types)
local Constants = require(script.Parent.Constants)

export type Hand = Types.Hand
export type TetherVisualConfig = Types.TetherVisualConfig

local TetherRenderer = {}
TetherRenderer.__index = TetherRenderer

export type TetherRendererInstance = typeof(setmetatable({} :: {
	_character: Model?,
	_hand: Hand?,
	_active: boolean,
	_beam: Beam?,
	_handAttachment: Attachment?,
	_worldAttachment: Attachment?,
	_anchorPart: BasePart?,
	_config: TetherVisualConfig,
}, TetherRenderer))

local function getHandPart(character: Model, hand: Hand): BasePart?
	local handName = if hand == "Left" then "LeftHand" else "RightHand"
	local armName = if hand == "Left" then "Left Arm" else "Right Arm"
	local part = character:FindFirstChild(handName) or character:FindFirstChild(armName)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

function TetherRenderer.new(defaultConfig: TetherVisualConfig?): TetherRendererInstance
	local self = setmetatable({
		_character = nil,
		_hand = nil,
		_active = false,
		_beam = nil,
		_handAttachment = nil,
		_worldAttachment = nil,
		_anchorPart = nil,
		_config = defaultConfig or Constants.Tether,
	}, TetherRenderer)

	return (self :: any) :: TetherRendererInstance
end

function TetherRenderer:isActive(): boolean
	return self._active
end

function TetherRenderer:getHand(): Hand?
	return self._hand
end

function TetherRenderer:shoot(character: Model, hand: Hand, targetPosition: Vector3, configOverride: TetherVisualConfig?)
	if self._active then
		self:release()
	end

	local handPart = getHandPart(character, hand)
	if not handPart then
		warn("[TetherRenderer] Hand part not found for hand:", hand)
		return
	end

	local cfg = configOverride or self._config or Constants.Tether

	self._character = character
	self._hand = hand
	self._active = true

	-- 1. Hand Attachment
	local handAttachment = Instance.new("Attachment")
	handAttachment.Name = "Swing" .. hand .. "HandAttachment"
	handAttachment.Parent = handPart
	self._handAttachment = handAttachment

	-- 2. Anchor Part in Workspace
	local anchorPart = Instance.new("Part")
	anchorPart.Name = "Swing" .. hand .. "AnchorPart"
	anchorPart.Size = Vector3.new(0.1, 0.1, 0.1)
	anchorPart.Transparency = 1
	anchorPart.CanCollide = false
	anchorPart.CanQuery = false
	anchorPart.CanTouch = false
	anchorPart.Anchored = true
	anchorPart.CFrame = CFrame.new(targetPosition)
	anchorPart.Parent = Workspace
	self._anchorPart = anchorPart

	-- 3. World Attachment
	local worldAttachment = Instance.new("Attachment")
	worldAttachment.Name = "Swing" .. hand .. "WorldAttachment"
	worldAttachment.Position = Vector3.zero
	worldAttachment.Parent = anchorPart
	self._worldAttachment = worldAttachment

	-- 4. Beam Visual
	local beam = Instance.new("Beam")
	beam.Name = "Swing" .. hand .. "Beam"
	beam.Attachment0 = handAttachment
	beam.Attachment1 = worldAttachment
	beam.Width0 = cfg.width0 or 0.15
	beam.Width1 = cfg.width1 or 0.1
	beam.FaceCamera = true
	beam.Segments = 10
	beam.Transparency = NumberSequence.new(cfg.transparency or 0.1)
	beam.LightEmission = cfg.lightEmission or 0.8

	if cfg.color then
		if typeof(cfg.color) == "ColorSequence" then
			beam.Color = cfg.color
		elseif typeof(cfg.color) == "Color3" then
			beam.Color = ColorSequence.new(cfg.color)
		end
	else
		-- Stylish neon gradient: Bright cyan to electric teal
		local c1 = if hand == "Left" then Color3.fromRGB(0, 200, 255) else Color3.fromRGB(50, 255, 180)
		local c2 = Color3.fromRGB(240, 255, 255)
		beam.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c1),
			ColorSequenceKeypoint.new(1, c2),
		})
	end

	if cfg.texture then
		beam.Texture = cfg.texture
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureSpeed = cfg.textureSpeed or 1
		beam.TextureLength = cfg.textureLength or 1
	end

	beam.Parent = handPart
	self._beam = beam
end

function TetherRenderer:update(targetPosition: Vector3)
	if not self._active or not self._anchorPart then
		return
	end
	self._anchorPart.CFrame = CFrame.new(targetPosition)
end

function TetherRenderer:release()
	self._active = false
	self._hand = nil
	self._character = nil

	if self._beam then
		self._beam:Destroy()
		self._beam = nil
	end
	if self._handAttachment then
		self._handAttachment:Destroy()
		self._handAttachment = nil
	end
	if self._worldAttachment then
		self._worldAttachment:Destroy()
		self._worldAttachment = nil
	end
	if self._anchorPart then
		self._anchorPart:Destroy()
		self._anchorPart = nil
	end
end

function TetherRenderer:destroy()
	self:release()
end

return TetherRenderer
