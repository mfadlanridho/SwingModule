--!strict
--[[
    CustomPendulum.luau (SwingModule)
    Zero-dependency circular pendulum kinematics and physics solver.
    Calculates tangential forces, centripetal acceleration, dynamic gravity torque,
    and spring-damper rope length error correction.
--]]

local PhysicsUtility = require(script.Parent.PhysicsUtility)
local Constants = require(script.Parent.Constants)
local Types = require(script.Parent.Types)

export type PendulumConfig = Types.PendulumConfig
export type SwingProjection = Types.SwingProjection
export type PendulumContext = Types.PendulumContext

local CustomPendulum = {}
CustomPendulum.currentAngle = 0

local EPSILON = 1e-4

local function getDirectionalInput(context: PendulumContext): Vector3
	if context.moveDirection ~= nil then
		return context.moveDirection
	end
	if context.humanoid ~= nil then
		return context.humanoid.MoveDirection
	end
	return Vector3.zero
end

--- Calculates acceleration magnitude from gravity acting along the pendulum arc: a = g * sin(theta)
function CustomPendulum.calculateAccelerationFromGravity(gravity: number, angleDegrees: number): number
	local angleRadians = math.rad(angleDegrees)
	return gravity * math.sin(angleRadians)
end

--- Determines whether the character is moving forward towards or past the anchor point
local function isMovingForward(
	currentPosition: Vector3,
	forwardVector: Vector3,
	targetPoint: Vector3,
	xzOnly: boolean
): boolean
	local directionToTarget = targetPoint - currentPosition
	local forward = forwardVector

	if xzOnly then
		directionToTarget = PhysicsUtility.getXZ(directionToTarget)
		forward = PhysicsUtility.getXZ(forward)
	end

	if forward.Magnitude <= EPSILON or directionToTarget.Magnitude <= EPSILON then
		return true
	end

	local forwardDot = forward.Unit:Dot(directionToTarget.Unit)
	return forwardDot > 0
end

--- Projects input force to be strictly perpendicular to the radial rope vector
local function getPerpendicularForce(
	position: Vector3,
	pendulumCenter: Vector3,
	input: Vector3,
	angle: number
): Vector3
	if input.Magnitude <= EPSILON then
		return Vector3.zero
	end

	local normal = pendulumCenter - position
	if normal.Magnitude <= EPSILON then
		return Vector3.zero
	end

	local b = normal.Y

	-- Prevent division by zero or infinite forces near horizontal alignment
	if angle >= 89 then
		return Vector3.zero
	end

	-- Preserves X and Z horizontal components while solving for the required Y to stay on the sphere plane
	local newY = -(normal.X * input.X + normal.Z * input.Z) / b
	return Vector3.new(input.X, newY, input.Z)
end

--- Applies spring-damper correction to keep character locked to the rope radius without stretching or sagging
function CustomPendulum.applyRopeLengthCorrection(
	currentPosition: Vector3,
	currentVelocity: Vector3,
	anchorPosition: Vector3,
	desiredRadius: number?,
	targetVelocity: Vector3,
	errorGain: number?,
	dampingGain: number?
): Vector3
	if desiredRadius == nil or desiredRadius <= EPSILON then
		return targetVelocity
	end

	local rope = currentPosition - anchorPosition
	local currentRadius = rope.Magnitude
	if currentRadius <= EPSILON then
		return targetVelocity
	end

	local ropeDir = rope.Unit
	local radiusError = currentRadius - desiredRadius
	local outwardRadialVelocity = math.max(currentVelocity:Dot(ropeDir), 0)

	if radiusError <= EPSILON and outwardRadialVelocity <= EPSILON then
		return targetVelocity
	end

	local kError = errorGain or Constants.Pendulum.RopeLengthErrorGain
	local kDamping = dampingGain or Constants.Pendulum.RopeLengthDampingGain

	local inwardCorrectionMagnitude =
		math.max(radiusError, 0) * kError
		+ (outwardRadialVelocity * kDamping)

	return targetVelocity - (ropeDir * inwardCorrectionMagnitude)
end

--- Steps the pendulum simulation for one frame and returns the resulting velocity and projection data
function CustomPendulum.step(
	context: PendulumContext,
	anchorPosition: Vector3,
	desiredRadius: number?,
	configOverride: PendulumConfig?
): SwingProjection
	local cfg = configOverride or Constants.Pendulum
	local rootPart = context.rootPart
	local deltaTime = context.deltaTime or (1 / 60)

	local rawInput = getDirectionalInput(context)
	local currentVelocity = rootPart.AssemblyLinearVelocity
	local currentXZVelocity = PhysicsUtility.getXZ(currentVelocity)
	local hasDirectionalInput = rawInput.Magnitude > EPSILON

	-- 1. Steer horizontal input towards desired movement direction
	local steeredInput: Vector3
	if hasDirectionalInput or currentXZVelocity.Magnitude > EPSILON then
		local targetDirection = if hasDirectionalInput then rawInput else currentXZVelocity
		steeredInput = PhysicsUtility.smoothChangeXZOnlyByRotating(
			currentXZVelocity,
			targetDirection,
			cfg.SwingRotationSpeed,
			deltaTime
		)
	else
		steeredInput = PhysicsUtility.getXZ(rootPart.CFrame.LookVector)
	end

	local currentPosition = rootPart.Position
	local signedAngle = PhysicsUtility.getAngleFromVertical(currentPosition, anchorPosition, steeredInput)
	local angle = math.abs(signedAngle)
	CustomPendulum.currentAngle = angle

	-- 2. Compute perpendicular tangential force
	local forcePerpendicular = getPerpendicularForce(currentPosition, anchorPosition, steeredInput, angle)
	if forcePerpendicular == Vector3.zero then
		forcePerpendicular = currentVelocity
	end

	-- Remove any radial component pointing directly toward anchor
	local normal = anchorPosition - currentPosition
	if normal.Magnitude > EPSILON then
		local normalUnit = normal.Unit
		local radialComponent = forcePerpendicular:Dot(normalUnit)
		local tangentForce = forcePerpendicular - (normalUnit * radialComponent)

		if tangentForce.Magnitude > EPSILON then
			forcePerpendicular = tangentForce
		else
			local facingDir = PhysicsUtility.getXZ(rootPart.CFrame.LookVector)
			if facingDir.Magnitude <= EPSILON then
				facingDir = Vector3.new(0, 0, -1)
			end
			tangentForce = facingDir.Unit - (normalUnit * facingDir.Unit:Dot(normalUnit))
			if tangentForce.Magnitude > EPSILON then
				forcePerpendicular = tangentForce.Unit * math.max(currentVelocity.Magnitude, cfg.InitXZSpeed)
			end
		end
	end

	-- 3. Dynamic Gravity Torque & Acceleration
	local accelerationMag = CustomPendulum.calculateAccelerationFromGravity(cfg.SwingGravity, angle)
	if not isMovingForward(currentPosition, rootPart.CFrame.LookVector, anchorPosition, true) then
		accelerationMag = 0
	end

	-- Scale planar speed according to acceleration and clamp to MaxSwingSpeed
	local xzMag = math.max(cfg.InitXZSpeed, currentXZVelocity.Magnitude) + (accelerationMag * deltaTime)
	xzMag = math.min(xzMag, cfg.MaxSwingSpeed)
	forcePerpendicular = PhysicsUtility.modifyXZMagnitude(forcePerpendicular, xzMag)

	-- 4. Apply Spring-Damper Rope Length Correction
	local effectiveRadius = desiredRadius or (anchorPosition - currentPosition).Magnitude
	local targetVelocity = CustomPendulum.applyRopeLengthCorrection(
		currentPosition,
		currentVelocity,
		anchorPosition,
		effectiveRadius,
		forcePerpendicular,
		cfg.RopeLengthErrorGain,
		cfg.RopeLengthDampingGain
	)

	-- Smooth exponential velocity blend
	local blendAlpha = 1 - math.exp(-cfg.VelocityBlendSpeed * deltaTime)
	local blendedVelocity = currentVelocity:Lerp(targetVelocity, blendAlpha)

	return {
		rawInput = rawInput,
		steeredInput = steeredInput,
		currentVelocity = currentVelocity,
		targetVelocity = blendedVelocity,
		forcePerpendicular = forcePerpendicular,
		currentAngle = angle,
		signedAngle = signedAngle,
		accelerationMag = accelerationMag,
	}
end

return CustomPendulum
