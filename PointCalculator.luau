--!strict
--[[
    PointCalculator.luau (SwingModule)
    Pure mathematical calculations for pendulum swing trajectory:
    - Player-to-Ground (P2G) clearance measurement
    - Speed-to-Distance curve sampling
    - Lowest-point arc clearance enforcement
    - Ideal floating pendulum anchor point generation
--]]

local Workspace = game:GetService("Workspace")

local Constants = require(script.Parent.Constants)
local Types = require(script.Parent.Types)

local PointCalculator = {}

local EPSILON = 1e-4

--- Evaluates the speed-to-distance curve via linear interpolation
function PointCalculator.evaluateSpeedCurve(speed: number, customCurve: { Types.PointCurveKeyframe }?): number
	local curve = customCurve or Constants.OptimalPoint.SpeedToDistanceCurve
	if #curve == 0 then
		return 40
	end

	if speed <= curve[1].Speed then
		return curve[1].Distance
	end
	if speed >= curve[#curve].Speed then
		return curve[#curve].Distance
	end

	for i = 1, #curve - 1 do
		local p1 = curve[i]
		local p2 = curve[i + 1]
		if speed >= p1.Speed and speed <= p2.Speed then
			local t = (speed - p1.Speed) / (p2.Speed - p1.Speed)
			return p1.Distance + (p2.Distance - p1.Distance) * t
		end
	end

	return 40
end

--- Raycasts downward from position to calculate distance to the nearest ground/floor
function PointCalculator.calculateP2G(position: Vector3, filterInstances: { Instance }?): (number, boolean)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	if filterInstances then
		raycastParams.FilterDescendantsInstances = filterInstances
	end

	local result = Workspace:Raycast(position, Vector3.new(0, -1000, 0), raycastParams)
	if result then
		return position.Y - result.Position.Y, true
	end
	return 500, false
end

--- Calculates the maximum allowable swing angle that avoids grounding
function PointCalculator.getMaxAngle(dist: number, p2g: number): (boolean, number)
	if dist * dist + p2g * p2g <= EPSILON then
		return false, 0
	end

	local a = dist / math.sqrt(dist * dist + p2g * p2g)
	local arcSin = math.asin(math.clamp(a, -1, 1))
	local arcTan = math.atan2(p2g, dist)
	local finalAngleRad = arcSin - arcTan

	local maxAngle = 90 - math.deg(finalAngleRad)
	local isValid = maxAngle > 0.1 and maxAngle < 89.9
	return isValid, maxAngle
end

--- Calculates max forward distance for a given angle and P2G
function PointCalculator.calculateMaxDistance(angleDegrees: number, p2g: number): number
	local currentAngle = 90 - angleDegrees
	local angleRad = math.rad(currentAngle)
	local sinGamma = math.sin(angleRad)
	local cosGamma = math.cos(angleRad)

	if math.abs(1 - sinGamma) <= EPSILON then
		return math.huge
	end

	local d = (p2g * cosGamma) / (1 - sinGamma)
	return math.abs(d)
end

--- Computes the 3D position of an anchor point relative to a root CFrame, angle, and distance
function PointCalculator.calculatePoint(
	transformCFrame: CFrame,
	angleDegrees: number,
	dist: number,
	minHeight: number?
): Vector3
	local currentAngle = 90 - angleDegrees
	local angleRad = math.rad(currentAngle)
	local lineDist = dist / math.cos(angleRad)
	local h2p = lineDist * math.sin(angleRad)

	local requiredMinHeight = (minHeight or Constants.OptimalPoint.MinimumSwingHeight) + 0.1
	if requiredMinHeight > h2p then
		h2p = requiredMinHeight
	end

	local fwdXZ = Vector3.new(transformCFrame.LookVector.X, 0, transformCFrame.LookVector.Z)
	if fwdXZ.Magnitude > EPSILON then
		fwdXZ = fwdXZ.Unit
	else
		fwdXZ = Vector3.xAxis
	end

	return transformCFrame.Position + (fwdXZ * dist) + Vector3.new(0, h2p, 0)
end

--- Computes lowest point clearance of the pendulum swing
function PointCalculator.getLowestPointClearance(
	rootPosition: Vector3,
	anchorPosition: Vector3,
	filterInstances: { Instance }?
): (number?, number?, boolean)
	local anchorToGround, groundDetected = PointCalculator.calculateP2G(anchorPosition, filterInstances)
	if not groundDetected then
		return nil, nil, false
	end

	local ropeLength = (anchorPosition - rootPosition).Magnitude
	return anchorToGround - ropeLength, anchorToGround, true
end

--- Iteratively lifts anchor position until minimum lowest point clearance above ground is satisfied
function PointCalculator.enforceMinimumLowestPointClearance(
	rootPosition: Vector3,
	point: Vector3,
	filterInstances: { Instance }?,
	minClearance: number?
): Vector3
	local minimumClearance = minClearance or Constants.OptimalPoint.MinimumLowestPointClearance
	if minimumClearance <= 0 then
		return point
	end

	local adjustedPoint = point
	for _ = 1, 4 do
		local lowestPointClearance, _, groundDetected =
			PointCalculator.getLowestPointClearance(rootPosition, adjustedPoint, filterInstances)
		if not groundDetected or lowestPointClearance == nil then
			return adjustedPoint
		end

		local clearanceShortfall = minimumClearance - lowestPointClearance
		if clearanceShortfall <= 0.01 then
			return adjustedPoint
		end

		adjustedPoint += Vector3.yAxis * clearanceShortfall
	end

	return adjustedPoint
end

--- Calculates the ideal floating pendulum pivot point in the air ahead/above the player
function PointCalculator.calculateIdealPoint(
	rootCFrame: CFrame,
	velocity: Vector3,
	filterInstances: { Instance }?,
	configOverride: Types.OptimalPointConfig?
): (Vector3?, number?)
	local cfg = configOverride or Constants.OptimalPoint
	local p2g, groundDetected = PointCalculator.calculateP2G(rootCFrame.Position, filterInstances)

	-- Check if player is too close to ground to start a swing
	if groundDetected and p2g < cfg.MinimumP2GToSwing then
		return nil, nil
	end

	local xzSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local ySpeed = math.abs(velocity.Y)
	local determinantSpeed = math.max(xzSpeed, ySpeed)

	local targetDistance = PointCalculator.evaluateSpeedCurve(determinantSpeed, cfg.SpeedToDistanceCurve)

	local hasMax, determinantDistMaxAngle =
		PointCalculator.getMaxAngle(targetDistance, p2g - cfg.GroundOffset)

	local finalAngle = 80
	if hasMax and determinantDistMaxAngle < finalAngle then
		finalAngle = determinantDistMaxAngle
	end

	-- Safety: Ensure at least a 20-degree arc so the character doesn't bottom out immediately
	if determinantDistMaxAngle < 10 then
		targetDistance = PointCalculator.calculateMaxDistance(20, p2g - cfg.GroundOffset)
	end

	local point = PointCalculator.calculatePoint(rootCFrame, finalAngle, targetDistance, cfg.MinimumSwingHeight)
	local safePoint = PointCalculator.enforceMinimumLowestPointClearance(
		rootCFrame.Position,
		point,
		filterInstances,
		cfg.MinimumLowestPointClearance
	)

	return safePoint, targetDistance
end

return PointCalculator
