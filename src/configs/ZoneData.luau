--// ReplicatedStorage > ZoneData

local ZoneData = {}

--[[
	Defines the properties for each placement zone.
	- Category: The type of items allowed here. Must match a category from ItemData.
	- MaxVolume: The total volume capacity for this zone in m³.
	- Color: The color to use for visualizing the zone.
	- FriendlyName: A display-friendly name for UI messages.
]]
ZoneData.Properties = {
	-- Deck 3
	["ExerciseZone"] = { Category = "Exercise", MaxVolume = 19.42, Color = Color3.fromRGB(255, 170, 0), FriendlyName = "Exercise Area" },
	["StorageZone"] = { Category = "Storage", MaxVolume = 6.00, Color = Color3.fromRGB(170, 85, 255), FriendlyName = "Storage Area" },

	-- Deck 1
	["KitchenZone"] = { Category = "Kitchen", MaxVolume = 7.65, Color = Color3.fromRGB(85, 255, 127), FriendlyName = "Kitchen Area" },
	["DiningZone"] = { Category = "Dining", MaxVolume = 10.09, Color = Color3.fromRGB(255, 255, 127), FriendlyName = "Dining & Social Area" },
	["MedicalZone"] = { Category = "Medical", MaxVolume = 7.00, Color = Color3.fromRGB(85, 170, 255), FriendlyName = "Medical Bay" },
	["HygieneZone"] = { Category = "Hygiene", MaxVolume = 10.67, Color = Color3.fromRGB(255, 85, 255), FriendlyName = "Hygiene & Waste Area" },
	["WorkstationZone"] = { Category = "Workstation", MaxVolume = 7.72, Color = Color3.fromRGB(170, 170, 170), FriendlyName = "Workstation Area" },
	["RecreationZone"] = { Category = "Recreation", MaxVolume = 18.20, Color = Color3.fromRGB(255, 85, 0), FriendlyName = "Recreation Area" },

	-- Deck 2 (Assuming you have 4 distinct zone parts)
	["CrewCabinZone1"] = { Category = "CrewCabin", MaxVolume = 7.5, Color = Color3.fromRGB(0, 85, 127), FriendlyName = "Crew Cabin 1" },
	["CrewCabinZone2"] = { Category = "CrewCabin", MaxVolume = 7.5, Color = Color3.fromRGB(0, 85, 127), FriendlyName = "Crew Cabin 2" },
	["CrewCabinZone3"] = { Category = "CrewCabin", MaxVolume = 7.5, Color = Color3.fromRGB(0, 85, 127), FriendlyName = "Crew Cabin 3" },
	["CrewCabinZone4"] = { Category = "CrewCabin", MaxVolume = 7.5, Color = Color3.fromRGB(0, 85, 127), FriendlyName = "Crew Cabin 4" },
}

function ZoneData.Get(zoneName)
	return ZoneData.Properties[zoneName]
end

return ZoneData