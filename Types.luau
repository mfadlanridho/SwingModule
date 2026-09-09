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

export type SwingConfig = {
	Detection: DetectionConfig?,
	OptimalPoint: OptimalPointConfig?,
}

return nil
