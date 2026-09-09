--!strict
--[[
    SwingPoseController.luau (SwingModule)
    Zero-dependency procedural avatar kinematics controller for Roblox swinging.
    Dynamically banks and tilts character joints (RootJoint & Waist) into the swing arc,
    providing realistic physical body lean and momentum visualization.
--]]

local Types = require(script.Parent.Types)
local Constants = require(script.Parent.Constants)

export type Hand = Types.Hand
export type PoseConfig = Types.PoseConfig

local EPSILON = 1e-4
local DEBUG_LOGS = false

local function debugLog(...)
	if DEBUG_LOGS then
		print("[SwingPoseController]", ...)
	end
end

type JointRig = {
	rootPart: BasePart,
	rootJoint: Instance?,
	waist: Instance?,
}

local SwingPoseController = {}
SwingPoseController.__index = SwingPoseController

export type SwingPoseControllerInstance = typeof(setmetatable({} :: {
	_character: Model?,
	_rig: JointRig?,
	_config: PoseConfig,
	_active: boolean,
	_currentPitch: number,
	_currentYaw: number,
	_currentRoll: number,
	_targetPitch: number,
	_targetYaw: number,
	_targetRoll: number,
}, SwingPoseController))

local function normalizeAngle(angle: number): number
	return math.atan2(math.sin(angle), math.cos(angle))
end

local function clamp(value: number, minVal: number, maxVal: number): number
	return math.max(minVal, math.min(maxVal, value))
end

local function resolveJointRig(character: Model?): JointRig?
	if not character then
		debugLog("resolveJointRig: character is nil")
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		debugLog("resolveJointRig: HumanoidRootPart is nil in character", character.Name)
		return nil
	end

	local rootJoint: Instance? = nil
	local waist: Instance? = nil

	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("Motor6D") or desc:IsA("AnimationConstraint") then
			if not waist and desc.Name == "Waist" then
				waist = desc
			end
			if not rootJoint then
				if desc.Name == "Root" or desc.Name == "RootJoint" then
					rootJoint = desc
				elseif desc:IsA("Motor6D") and (desc.Part0 == rootPart or desc.Part1 == rootPart) then
					rootJoint = desc
				end
			end
		end
	end

	debugLog(string.format("resolveJointRig: character=%s | rootJoint=%s (%s) | waist=%s (%s)",
		character.Name,
		rootJoint and rootJoint.Name or "NIL",
		rootJoint and rootJoint.ClassName or "NIL",
		waist and waist.Name or "NIL",
		waist and waist.ClassName or "NIL"
	))

	if not rootJoint and not waist then
		return nil
	end

	return {
		rootPart = rootPart,
		rootJoint = rootJoint,
		waist = waist,
	}
end

function SwingPoseController.new(character: Model?, configOverride: PoseConfig?): SwingPoseControllerInstance
	local self = setmetatable({
		_character = character,
		_rig = resolveJointRig(character),
		_config = configOverride or Constants.Pose,
		_active = false,
		_currentPitch = 0,
		_currentYaw = 0,
		_currentRoll = 0,
		_targetPitch = 0,
		_targetYaw = 0,
		_targetRoll = 0,
	}, SwingPoseController)

	return (self :: any) :: SwingPoseControllerInstance
end

function SwingPoseController:setCharacter(character: Model?)
	self:resetTransforms()
	self._character = character
	self._rig = resolveJointRig(character)
	self._active = false
	self._currentPitch = 0
	self._currentYaw = 0
	self._currentRoll = 0
	self._targetPitch = 0
	self._targetYaw = 0
	self._targetRoll = 0
end

--- Solves the dynamic banking angles given swing anchor position and velocity
function SwingPoseController:computeAngles(anchorPosition: Vector3, tangentVelocity: Vector3): (number, number, number)
	local rig = self._rig
	if not rig or tangentVelocity.Magnitude <= EPSILON then
		return 0, 0, 0
	end

	local rope = anchorPosition - rig.rootPart.Position
	if rope.Magnitude <= EPSILON then
		return 0, 0, 0
	end

	local ropeDir = rope.Unit
	local bodyUp = ropeDir
	local tangent = tangentVelocity.Unit - bodyUp * tangentVelocity.Unit:Dot(bodyUp)
	if tangent.Magnitude <= EPSILON then
		return 0, 0, 0
	end

	local forwardDir = tangent.Unit
	local rightDir = forwardDir:Cross(bodyUp)
	if rightDir.Magnitude <= EPSILON then
		return 0, 0, 0
	end

	rightDir = rightDir.Unit
	forwardDir = bodyUp:Cross(rightDir)
	if forwardDir.Magnitude <= EPSILON then
		return 0, 0, 0
	end
	forwardDir = forwardDir.Unit

	local targetFrame = CFrame.fromMatrix(rig.rootPart.Position, rightDir, bodyUp, -forwardDir)
	local delta = rig.rootPart.CFrame:ToObjectSpace(targetFrame)
	local pitch, yaw, roll = delta:ToOrientation()

	pitch = normalizeAngle(pitch)
	yaw = normalizeAngle(yaw)
	roll = normalizeAngle(roll)

	local speed = tangentVelocity.Magnitude
	local speedAlpha = clamp(speed / self._config.FullTiltSpeed, 0, 1)

	pitch = clamp(
		pitch * speedAlpha,
		-math.rad(self._config.MaxPitchDegrees),
		math.rad(self._config.MaxPitchDegrees)
	)
	yaw = clamp(
		yaw * speedAlpha,
		-math.rad(self._config.MaxYawDegrees),
		math.rad(self._config.MaxYawDegrees)
	)
	roll = clamp(
		roll * speedAlpha,
		-math.rad(self._config.MaxRollDegrees),
		math.rad(self._config.MaxRollDegrees)
	)

	return pitch, yaw, roll
end

local lastPosePrint = 0

--- Sets the active target pose state
function SwingPoseController:setPose(anchorPosition: Vector3, tangentVelocity: Vector3)
	if not self._rig then
		return
	end

	if tangentVelocity.Magnitude <= EPSILON then
		self:clearPose()
		return
	end

	self._active = true
	local targetP, targetY, targetR = self:computeAngles(anchorPosition, tangentVelocity)
	self._targetPitch = targetP
	self._targetYaw = targetY
	self._targetRoll = targetR

	if DEBUG_LOGS and os.clock() - lastPosePrint >= 0.5 then
		lastPosePrint = os.clock()
		debugLog(string.format("Target: Pitch=%.1f°, Yaw=%.1f°, Roll=%.1f° | Current: Pitch=%.1f°, Yaw=%.1f°, Roll=%.1f°",
			math.deg(self._targetPitch), math.deg(self._targetYaw), math.deg(self._targetRoll),
			math.deg(self._currentPitch), math.deg(self._currentYaw), math.deg(self._currentRoll)
		))
	end
end

--- Clears the active pose and initiates smooth return to neutral
function SwingPoseController:clearPose()
	self._active = false
	self._targetPitch = 0
	self._targetYaw = 0
	self._targetRoll = 0
end

--- Steps procedural smoothing and writes joint transforms
function SwingPoseController:update(deltaTime: number)
	local rig = self._rig
	if not rig or not rig.rootPart.Parent then
		return
	end

	-- If not swinging and already at neutral, do not touch transforms so animations play freely
	if not self._active
		and math.abs(self._currentPitch) < 1e-3
		and math.abs(self._currentYaw) < 1e-3
		and math.abs(self._currentRoll) < 1e-3
	then
		return
	end

	local alpha = 1 - math.exp(-self._config.SmoothingSpeed * deltaTime)
	self._currentPitch += (self._targetPitch - self._currentPitch) * alpha
	self._currentYaw += (self._targetYaw - self._currentYaw) * alpha
	self._currentRoll += (self._targetRoll - self._currentRoll) * alpha

	local rootWeights = self._config.RootWeights
	local waistWeights = self._config.WaistWeights

	local rootPitch = self._currentPitch * rootWeights.pitch
	local rootYaw = self._currentYaw * rootWeights.yaw
	local rootRoll = self._currentRoll * rootWeights.roll

	local waistPitch = self._currentPitch * waistWeights.pitch
	local waistYaw = self._currentYaw * waistWeights.yaw
	local waistRoll = self._currentRoll * waistWeights.roll

	if rig.rootJoint then
		(rig.rootJoint :: any).Transform = CFrame.Angles(rootPitch, rootYaw, rootRoll)
	end

	if rig.waist then
		(rig.waist :: any).Transform = CFrame.Angles(waistPitch, waistYaw, waistRoll)
	end

	-- Check if idle and close enough to neutral to zero out
	if not self._active
		and math.abs(self._currentPitch) < 1e-3
		and math.abs(self._currentYaw) < 1e-3
		and math.abs(self._currentRoll) < 1e-3
	then
		self:resetTransforms()
	end
end

function SwingPoseController:resetTransforms()
	local rig = self._rig
	if rig then
		if rig.rootJoint then
			(rig.rootJoint :: any).Transform = CFrame.identity
		end
		if rig.waist then
			(rig.waist :: any).Transform = CFrame.identity
		end
	end
end

function SwingPoseController:destroy()
	self:resetTransforms()
	self._rig = nil
	self._character = nil
end

return SwingPoseController
