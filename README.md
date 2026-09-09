# SwingModule

Zero-dependency, standalone Roblox Luau package for pendulum swinging trajectory calculation, Player-to-Ground (P2G) clearance verification, and dynamic physical surface hit-point snapping.

---

## 📦 Features

- **P2G Clearance Safety**: Automatically raycasts downward to prevent initiating swings when too close to the floor.
- **Speed-to-Distance Curve**: Interpolates forward anchor distance based on horizontal and vertical player speed.
- **Arc Ground Clearance Enforcement**: Lifts the target anchor point so the bottom of the pendulum arc never collides with the ground.
- **Surface Snapping**: Uses `part:GetClosestPointOnSurface(idealPoint)` to snap mathematical targets to actual geometry (trees, cliffs, walls).
- **Fast-Path Linecasting**: Instantly latches onto obstacles directly dead-ahead.
- **Lateral Angle Scoring**: Selects whether the **Left** or **Right** hand should shoot by favoring $\approx 90^\circ$ side anchors for maximum pendulum momentum.

---

## 🚀 Quick Start

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SwingModule = require(ReplicatedStorage.Submodules.SwingModule)

-- Query best anchor point from candidate parts:
local hitResult, idealPoint = SwingModule.findBestAnchor(
    rootPart.CFrame,
    rootPart.AssemblyLinearVelocity,
    candidateParts, -- Array of BaseParts tagged "Swingable"
    "Right"         -- Preferred hand
)

if hitResult then
    print("Found anchor on:", hitResult.part.Name)
    print("Hit Position:", hitResult.position)
    print("Hand to shoot:", hitResult.hand) -- "Left" or "Right"
end
```

---

## 🛠️ Architecture

```
SwingModule/
├── README.md
├── Types.luau           -- Type definitions (Hand, HitResult, PointData, SwingConfig)
├── Constants.luau       -- Default radii, clearance heights, and speed curves
├── PointCalculator.luau -- Pure math trajectory and P2G ground-clearance solver
├── PointFinder.luau     -- Physical surface projection and Left/Right hand selector
└── init.luau            -- Public API entry point
```
