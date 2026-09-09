--!strict
--[[
    SwingModule (init.luau)
    Zero-dependency, standalone Roblox swinging & grapple trajectory module.
    Provides ground clearance verification, speed-to-distance curves,
    surface hit-point projection, and lateral hand selection.
--]]

local Types = require(script.Types)
local Constants = require(script.Constants)
local PointCalculator = require(script.PointCalculator)
local PointFinder = require(script.PointFinder)
local PhysicsUtility = require(script.PhysicsUtility)
local CustomPendulum = require(script.CustomPendulum)
local TetherRenderer = require(script.TetherRenderer)
local SwingPoseController = require(script.SwingPoseController)

export type Hand = Types.Hand
export type PointData = Types.PointData
export type HitResult = Types.HitResult
export type SwingConfig = Types.SwingConfig
export type DetectionConfig = Types.DetectionConfig
export type OptimalPointConfig = Types.OptimalPointConfig
export type PendulumConfig = Types.PendulumConfig
export type PoseConfig = Types.PoseConfig
export type ReleaseConfig = Types.ReleaseConfig
export type TetherVisualConfig = Types.TetherVisualConfig
export type SwingProjection = Types.SwingProjection
export type PendulumContext = Types.PendulumContext
export type ClampVelocityOptions = Types.ClampVelocityOptions

local SwingModule = {}
SwingModule.__index = SwingModule

SwingModule.Constants = Constants
SwingModule.PointCalculator = PointCalculator
SwingModule.PointFinder = PointFinder
SwingModule.PhysicsUtility = PhysicsUtility
SwingModule.CustomPendulum = CustomPendulum
SwingModule.TetherRenderer = TetherRenderer
SwingModule.SwingPoseController = SwingPoseController

--- Evaluates one frame of circular pendulum physics towards an anchor point
function SwingModule.stepPendulum(
	context: PendulumContext,
	anchorPosition: Vector3,
	desiredRadius: number?,
	configOverride: PendulumConfig?
): SwingProjection
	return CustomPendulum.step(context, anchorPosition, desiredRadius, configOverride)
end

--- Single-call helper to calculate the best physical anchor point given root CFrame, velocity, and candidate parts
function SwingModule.findBestAnchor(
	rootCFrame: CFrame,
	velocity: Vector3,
	candidates: { BasePart },
	preferredHand: Hand?,
	filterInstances: { Instance }?,
	optimalPointConfigOverride: Types.OptimalPointConfig?
): (HitResult?, Vector3?)
	if #candidates == 0 then
		return nil, nil
	end

	local forwardXZ = Vector3.new(rootCFrame.LookVector.X, 0, rootCFrame.LookVector.Z)
	if forwardXZ.Magnitude > 1e-4 then
		forwardXZ = forwardXZ.Unit
	else
		forwardXZ = Vector3.zAxis
	end

	local idealPoint = PointCalculator.calculateIdealPoint(
		rootCFrame,
		velocity,
		filterInstances,
		optimalPointConfigOverride
	)

	if not idealPoint then
		return nil, nil
	end

	local hitResult = PointFinder.findAppropriateHitPoint(
		rootCFrame.Position,
		idealPoint,
		forwardXZ,
		candidates,
		preferredHand
	)

	return hitResult, idealPoint
end

return SwingModule
