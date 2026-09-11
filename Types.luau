--!strict
--[[
    Types.luau (SwingModule)
    Public type definitions for SwingModule.
--]]

export type Hand = "Left" | "Right"

export type PointData = {
	part: BasePart,
	position: Vector3,
	signedAngle: number,
}

export type HitResult = {
	part: BasePart,
	position: Vector3,
	hand: Hand,
}

export type PointCurveKeyframe = {
	Speed: number,
	Distance: number,
}

export type DetectionConfig = {
	Tag: string,
	Radius: number,
	MaxParts: number,
}

export type OptimalPointConfig = {
	FwdCheckDist: number,
	MaxSwingRadius: number,
	MinimumSwingHeight: number,
	MinimumLowestPointClearance: number,
	MinimumP2GToSwing: number,
	GroundOffset: number,
	SpeedToDistanceCurve: { PointCurveKeyframe },
}

export type ClampVelocityOptions = {
	yRange: {
		min: number?,
		max: number?,
	}?,
	xzMaxSpeed: number?,
	xzMinSpeed: number?,
}

export type PendulumConfig = {
	SwingGravity: number,
	MaxSwingSpeed: number,
	InitXZSpeed: number,
	RopeLengthErrorGain: number,
	RopeLengthDampingGain: number,
	SwingRotationSpeed: number,
	VelocityBlendSpeed: number,
}

export type SwingProjection = {
	rawInput: Vector3,
	steeredInput: Vector3,
	currentVelocity: Vector3,
	targetVelocity: Vector3,
	forcePerpendicular: Vector3,
	currentAngle: number,
	signedAngle: number,
	accelerationMag: number,
}

export type PendulumContext = {
	rootPart: BasePart,
	humanoid: Humanoid?,
	deltaTime: number?,
	moveDirection: Vector3?,
}

export type TetherVisualConfig = {
	color: (ColorSequence | Color3)?,
	width0: number?,
	width1: number?,
	transparency: number?,
	texture: string?,
	textureSpeed: number?,
	textureLength: number?,
	lightEmission: number?,
}

export type PoseConfig = {
	FullTiltSpeed: number,
	MaxPitchDegrees: number,
	MaxYawDegrees: number,
	MaxRollDegrees: number,
	SmoothingSpeed: number,
	RootWeights: { pitch: number, yaw: number, roll: number },
	WaistWeights: { pitch: number, yaw: number, roll: number },
}

export type ReleaseConfig = {
	AngleThreshold: number,
	LowArcForwardBoost: number,
	LowArcMinUpwardVelocity: number,
	HighArcUpwardBoost: number,
	HighArcMinUpwardVelocity: number,
	MinHorizontalSpeed: number,
	MaxUpwardVelocity: number?,
}

export type SwingConfig = {
	Detection: DetectionConfig?,
	OptimalPoint: OptimalPointConfig?,
	Pendulum: PendulumConfig?,
	Pose: PoseConfig?,
	Release: ReleaseConfig?,
}

return nil
