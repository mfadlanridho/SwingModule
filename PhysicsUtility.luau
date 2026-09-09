--!strict
--[[
    PhysicsUtility.luau (SwingModule)
    Zero-dependency 3D vector, kinematics, and rotational math utilities for pendulum swinging.
--]]

export type ClampVelocityOptions = {
	yRange: {
		min: number?,
		max: number?,
	}?,
	xzMaxSpeed: number?,
	xzMinSpeed: number?,
}

local PhysicsUtility = {}

local EPSILON = 1e-4
local DEFAULT_ROTATION_SPEED = 10

local function rotateXZDegrees(vector: Vector3, angleDegrees: number): Vector3
	local radians = math.rad(angleDegrees)
	local cosTheta = math.cos(radians)
	local sinTheta = math.sin(radians)

	return Vector3.new(
		vector.X * cosTheta - vector.Z * sinTheta,
		vector.Y,
		vector.X * sinTheta + vector.Z * cosTheta
	)
end

local function getSignedAngleDegreesXZ(fromDirection: Vector3, toDirection: Vector3): number
	local fromXZ = Vector2.new(fromDirection.X, fromDirection.Z)
	local toXZ = Vector2.new(toDirection.X, toDirection.Z)

	if fromXZ.Magnitude <= EPSILON or toXZ.Magnitude <= EPSILON then
		return 0
	end

	local fromUnit = fromXZ.Unit
	local toUnit = toXZ.Unit
	local determinant = fromUnit.X * toUnit.Y - fromUnit.Y * toUnit.X
	local dot = math.clamp(fromUnit:Dot(toUnit), -1, 1)

	return math.deg(math.atan2(determinant, dot))
end

--- Returns vector flattened to the horizontal XZ plane (Y = 0)
function PhysicsUtility.getXZ(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

--- Calculates the angle (in degrees) between the vector from anchor to position and the downward vertical (-Y).
--- If forwardDirection is provided, returns negative degrees when behind the anchor and positive when in front.
function PhysicsUtility.getAngleFromVertical(
	position: Vector3,
	anchorPosition: Vector3,
	forwardDirection: Vector3?
): number
	local dir = position - anchorPosition
	if dir.Magnitude <= EPSILON then
		return 0
	end

	local dot = math.clamp(dir.Unit:Dot(-Vector3.yAxis), -1, 1)
	local angle = math.deg(math.acos(dot))

	if forwardDirection then
		local fwdXZ = PhysicsUtility.getXZ(forwardDirection)
		local dirXZ = PhysicsUtility.getXZ(dir)
		if fwdXZ.Magnitude > EPSILON and dirXZ:Dot(fwdXZ) < 0 then
			return -angle
		end
	end

	return angle
end

--- Adjusts horizontal XZ magnitude while scaling Y proportionally to preserve vertical trajectory ratio
function PhysicsUtility.modifyXZMagnitude(vector: Vector3, targetMagnitude: number): Vector3
	local xzMagnitude = PhysicsUtility.getXZ(vector).Magnitude
	if xzMagnitude <= EPSILON then
		return vector
	end

	local scale = targetMagnitude / xzMagnitude
	local yRatio = vector.Y / xzMagnitude
	local newY = targetMagnitude * yRatio

	return Vector3.new(vector.X * scale, newY, vector.Z * scale)
end

--- Clamps 3D velocity within specified Y range and XZ min/max bounds
function PhysicsUtility.clampVelocity(velocity: Vector3, options: ClampVelocityOptions?): Vector3
	if options == nil then
		return velocity
	end

	local clampedY = velocity.Y
	local yRange = options.yRange
	if yRange ~= nil then
		if yRange.min ~= nil then
			clampedY = math.max(clampedY, yRange.min)
		end
		if yRange.max ~= nil then
			clampedY = math.min(clampedY, yRange.max)
		end
	end

	local xz = Vector3.new(velocity.X, 0, velocity.Z)
	local xzMagnitude = xz.Magnitude
	local clampedXZ = xz

	local xzMaxSpeed = options.xzMaxSpeed
	if xzMaxSpeed ~= nil and xzMagnitude > xzMaxSpeed and xzMagnitude > EPSILON then
		clampedXZ = xz.Unit * xzMaxSpeed
		xzMagnitude = xzMaxSpeed
	end

	local xzMinSpeed = options.xzMinSpeed
	if xzMinSpeed ~= nil and xzMagnitude < xzMinSpeed and xzMagnitude > EPSILON then
		clampedXZ = xz.Unit * xzMinSpeed
	end

	return Vector3.new(clampedXZ.X, clampedY, clampedXZ.Z)
end

--- Smoothly rotates horizontal velocity towards target direction using signed angular interpolation
function PhysicsUtility.smoothChangeXZOnlyByRotating(
	currentVelocity: Vector3,
	targetDirection: Vector3,
	rotationSpeed: number?,
	deltaTime: number?
): Vector3
	local currentXZ = PhysicsUtility.getXZ(currentVelocity)
	local targetXZ = PhysicsUtility.getXZ(targetDirection)

	if currentXZ.Magnitude <= EPSILON or targetXZ.Magnitude <= EPSILON then
		return currentVelocity
	end

	local angleDegrees = getSignedAngleDegreesXZ(currentXZ, targetXZ)
	local normalizedAngle = math.clamp(angleDegrees / 90, -1, 1)
	local frameScale = if deltaTime ~= nil then deltaTime * 60 else 1
	local appliedDegrees = (rotationSpeed or DEFAULT_ROTATION_SPEED) * normalizedAngle * frameScale

	local rotatedXZ = rotateXZDegrees(currentXZ, appliedDegrees)
	return Vector3.new(rotatedXZ.X, currentVelocity.Y, rotatedXZ.Z)
end

return PhysicsUtility
