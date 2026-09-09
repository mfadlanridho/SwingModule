--!strict
--[[
    PointFinder.luau (SwingModule)
    Surface hit-point projection and hand selection:
    - Fast-path linecast for forward obstacles
    - Surface snapping using part:GetClosestPointOnSurface(idealPoint)
    - Signed angle measurement relative to player forward vector
    - Left vs. Right hand selection favoring lateral anchors (~90 degrees)
    - Surface height clamping
--]]

local Workspace = game:GetService("Workspace")
local Types = require(script.Parent.Types)

export type Hand = Types.Hand
export type PointData = Types.PointData
export type HitResult = Types.HitResult

local PointFinder = {}

local EPSILON = 1e-4

local function signedAngle(fromVec: Vector3, toVec: Vector3, axis: Vector3): number
	local dot = math.clamp(fromVec:Dot(toVec), -1, 1)
	local angle = math.deg(math.acos(dot))
	local cross = fromVec:Cross(toVec)
	return if cross:Dot(axis) > 0 then -angle else angle
end

local function isPointOnRightSide(origin: Vector3, forward: Vector3, point: Vector3): boolean
	local dirToPoint = point - origin
	local fwdXZ = Vector3.new(forward.X, 0, forward.Z)
	local dirXZ = Vector3.new(dirToPoint.X, 0, dirToPoint.Z)
	return fwdXZ:Cross(dirXZ).Y < 0
end

--- Collects candidate surface contact points from nearby swingable parts
function PointFinder.getClosestPoints(
	source: Vector3,
	point: Vector3,
	forward: Vector3,
	candidates: { BasePart },
	ignorePointsBehindSource: boolean?
): { PointData }
	local shouldIgnoreBehind = if ignorePointsBehindSource == nil then true else ignorePointsBehindSource
	local points: { PointData } = {}

	for _, part in ipairs(candidates) do
		if not part:IsA("BasePart") or not part.Parent then
			continue
		end

		local partTopY = part.Position.Y + (part.Size.Y / 2)
		if partTopY < source.Y + 2 then
			continue
		end

		local closestPointOnSurface = part:GetClosestPointOnSurface(point)

		if shouldIgnoreBehind then
			local sourceToPoint = closestPointOnSurface - source
			if sourceToPoint.Magnitude > EPSILON then
				local dotProduct = forward:Dot(sourceToPoint.Unit)
				if dotProduct < -0.1 then
					continue
				end
			end
		end

		local directionToPoint = closestPointOnSurface - point
		local directionXZ = Vector3.new(directionToPoint.X, 0, directionToPoint.Z)

		if directionXZ.Magnitude > EPSILON then
			directionXZ = directionXZ.Unit
			local forwardXZ = Vector3.new(forward.X, 0, forward.Z)
			if forwardXZ.Magnitude > EPSILON then
				forwardXZ = forwardXZ.Unit
			else
				forwardXZ = Vector3.zAxis
			end

			local angleVal = signedAngle(forwardXZ, directionXZ, Vector3.yAxis)
			local snappedPosition = Vector3.new(closestPointOnSurface.X, partTopY, closestPointOnSurface.Z)

			table.insert(points, {
				part = part,
				position = snappedPosition,
				signedAngle = angleVal,
			})
		end
	end

	return points
end

--- Determines the best Left and Right candidate points closest to 90 degrees lateral
function PointFinder.getBestGrapplePoint(points: { PointData }): (PointData?, PointData?)
	local bestLeftPoint: PointData? = nil
	local bestRightPoint: PointData? = nil
	local bestLeftAngleDiff = math.huge
	local bestRightAngleDiff = math.huge

	for _, point in ipairs(points) do
		local angle = point.signedAngle
		if angle < 0 then
			-- Left side
			local angleDiff = math.abs(90 + angle)
			if angleDiff < bestLeftAngleDiff then
				bestLeftAngleDiff = angleDiff
				bestLeftPoint = point
			end
		else
			-- Right side
			local angleDiff = math.abs(90 - angle)
			if angleDiff < bestRightAngleDiff then
				bestRightAngleDiff = angleDiff
				bestRightPoint = point
			end
		end
	end

	return bestLeftPoint, bestRightPoint
end

--- Evaluates the best physical surface contact point on candidate parts for the given ideal point
function PointFinder.findAppropriateHitPoint(
	source: Vector3,
	idealPoint: Vector3,
	forward: Vector3,
	candidates: { BasePart },
	preferredHand: Hand?
): HitResult?
	local targetHand: Hand = preferredHand or "Right"

	if #candidates == 0 then
		return nil
	end

	-- Fast path: linecast forward toward the ideal point to catch obstacles directly in the player's path
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = candidates

	local castDir = (idealPoint + forward * 10) - source
	local fastHit = Workspace:Raycast(source, castDir, raycastParams)
	if fastHit and fastHit.Instance:IsA("BasePart") then
		local hitPart = fastHit.Instance
		local partTopY = hitPart.Position.Y + (hitPart.Size.Y / 2)
		local grappleY = math.min(partTopY, idealPoint.Y)
		local grapplePos = Vector3.new(fastHit.Position.X, grappleY, fastHit.Position.Z)
		return {
			part = hitPart,
			position = grapplePos,
			hand = targetHand,
		}
	end

	-- Normal path: score candidate parts and pick best lateral hit point
	local points = PointFinder.getClosestPoints(source, idealPoint, forward, candidates)
	if #points == 0 then
		return nil
	end

	local bestLeft, bestRight = PointFinder.getBestGrapplePoint(points)
	if bestLeft == nil and bestRight == nil then
		return nil
	end

	local leftAngleDiff = if bestLeft ~= nil then math.abs(90 + bestLeft.signedAngle) else math.huge
	local rightAngleDiff = if bestRight ~= nil then math.abs(90 - bestRight.signedAngle) else math.huge

	local chosenPoint: PointData
	local chosenHand: Hand

	if targetHand == "Left" and bestLeft ~= nil and leftAngleDiff < 0.1 then
		chosenPoint = bestLeft
		chosenHand = "Left"
	elseif targetHand == "Right" and bestRight ~= nil and rightAngleDiff < 0.1 then
		chosenPoint = bestRight
		chosenHand = "Right"
	elseif bestLeft ~= nil and bestRight ~= nil then
		if leftAngleDiff < rightAngleDiff then
			chosenPoint = bestLeft
			chosenHand = "Left"
		else
			chosenPoint = bestRight
			chosenHand = "Right"
		end
	else
		local singlePoint = if bestLeft ~= nil then bestLeft else (bestRight :: PointData)
		chosenPoint = singlePoint
		chosenHand = if isPointOnRightSide(idealPoint, forward, singlePoint.position) then "Right" else "Left"
	end

	local finalY = math.min(chosenPoint.position.Y, idealPoint.Y)
	local finalPos = Vector3.new(chosenPoint.position.X, finalY, chosenPoint.position.Z)

	return {
		part = chosenPoint.part,
		position = finalPos,
		hand = chosenHand,
	}
end

return PointFinder
