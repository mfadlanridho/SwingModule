--!strict
--[[
    Constants.luau (SwingModule)
    Default parameters for swing detection, clearances, and trajectory calculations.
--]]

local Types = require(script.Parent.Types)

export type DetectionConfig = Types.DetectionConfig
export type OptimalPointConfig = Types.OptimalPointConfig

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
		MinimumP2GToSwing = 8,
		GroundOffset = 5,
		SpeedToDistanceCurve = {
			{ Speed = 0, Distance = 40 },
			{ Speed = 10, Distance = 40 },
			{ Speed = 20, Distance = 40 },
			{ Speed = 30, Distance = 50 },
			{ Speed = 40, Distance = 60 },
		},
	} :: OptimalPointConfig,
}

return table.freeze(Constants)
