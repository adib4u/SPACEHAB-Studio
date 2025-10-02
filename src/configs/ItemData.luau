--// ReplicatedStorage > ItemData

local ItemData = {}

--[[
	Maps item model names to their properties.
	- Category: The type of zone this item can be placed in.
	- BaseVolume: The item's default Net Habitable Volume in cubic meters (m³).
]]
ItemData.Properties = {
	-- Deck 3: Exercise
	["CycleErgometer"] = { Category = "Exercise", BaseVolume = 3.38 },
	["Treadmill"] = { Category = "Exercise", BaseVolume = 6.12 },
	["ResistiveDevice"] = { Category = "Exercise", BaseVolume = 3.92 },

	-- Deck 1: Kitchen & Dining
	["FoodPrepStation"] = { Category = "Kitchen", BaseVolume = 7.65 },
	["DiningTable"] = { Category = "Dining", BaseVolume = 10.09 },

	-- Deck 1: Medical
	["MedicalCouch"] = { Category = "Medical", BaseVolume = 5.80 },
	["MedicalWorkstation"] = { Category = "Medical", BaseVolume = 1.20 },

	-- Deck 1: Hygiene & Waste
	["HygieneStation"] = { Category = "Hygiene", BaseVolume = 6.71 },
	["WasteManagementUnit"] = { Category = "Hygiene", BaseVolume = 3.76 },

	-- Deck 1: Work & Recreation
	["MissionControl"] = { Category = "Workstation", BaseVolume = 3.42 },
	["GeneralWorkstation"] = { Category = "Workstation", BaseVolume = 4.30 }, -- Calculated from total
	["RecreationArea"] = { Category = "Recreation", BaseVolume = 18.20 },

	-- Deck 2: Private Cabins
	["SleepingBerth"] = { Category = "CrewCabin", BaseVolume = 4.0 }, -- Approximated
	["PersonalComputer"] = { Category = "CrewCabin", BaseVolume = 3.5 }, -- Approximated

	-- Storage
	["StorageShelves"] = { Category = "Storage", BaseVolume = 6.00 },
}

function ItemData.Get(itemName)
	return ItemData.Properties[itemName]
end

return ItemData