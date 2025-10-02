local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ZoneData = require(ReplicatedStorage:WaitForChild("Configs").ZoneData)

local PlacementZones = Workspace:WaitForChild("PlacementZones")

for index, data in ZoneData.Properties do
    local zonePart = PlacementZones:FindFirstChild(index)
    if zonePart and zonePart:IsA("BasePart") and data.Color then
        zonePart.Color = data.Color
    end
end