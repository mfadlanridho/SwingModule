--!strict
--[[
    Constants.luau (SwingModule)
    Default parameters for swing detection, clearances, and trajectory calculations.
--]]

local Types = require(script.Parent.Types)

export type DetectionConfig = Types.DetectionConfig
export type OptimalPointConfig = Types.OptimalPointConfig
export type PendulumConfig = Types.PendulumConfig
export type PoseConfig = Types.PoseConfig
export type ReleaseConfig = Types.ReleaseConfig
export type TetherVisualConfig = Types.TetherVisualConfig

local Constants = {
	Detection = {
		Tag = "Swingable",
		Radius = 160,
		MaxParts = 64,
	} :: DetectionConfig,

	OptimalPoint = {
		FwdCheckDist = 50,
		MaxSwingRadius = 150,
		MinimumSwingHeight = 8,
		MinimumLowestPointClearance = 4,
		MinimumP2GToSwing = -100,
		GroundOffset = 5,
		SpeedToDistanceCurve = {
			{ Speed = 0, Distance = 40 },
			{ Speed = 10, Distance = 40 },
			{ Speed = 20, Distance = 40 },
			{ Speed = 30, Distance = 50 },
			{ Speed = 40, Distance = 60 },
		},
	} :: OptimalPointConfig,

	Pendulum = {
		SwingGravity = 196.2,
		MaxSwingSpeed = 85,
		InitXZSpeed = 35,
		RopeLengthErrorGain = 12,
		RopeLengthDampingGain = 1.5,
		SwingRotationSpeed = 5,
		VelocityBlendSpeed = 10,
	} :: PendulumConfig,

	Pose = {
		FullTiltSpeed = 60,
		MaxPitchDegrees = 60,
		MaxYawDegrees = 30,
		MaxRollDegrees = 40,
		SmoothingSpeed = 12,
		RootWeights = { pitch = 0.45, yaw = 0.5, roll = 0.55 },
		WaistWeights = { pitch = 0.55, yaw = 0.5, roll = 0.45 },
	} :: PoseConfig,

	Release = {
		AngleThreshold = 42,
		LowArcForwardBoost = 35,
		LowArcMinUpwardVelocity = 15,
		HighArcUpwardBoost = 35,
		HighArcMinUpwardVelocity = 25,
		MaxUpwardVelocity = 120,
		MinHorizontalSpeed = 25,
	} :: ReleaseConfig,

	Tether = {
		width0 = 0.15,
		width1 = 0.1,
		transparency = 0.1,
		lightEmission = 0.8,
	} :: TetherVisualConfig,
}

return table.freeze(Constants)
