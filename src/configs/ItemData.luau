--// ReplicatedStorage > Configs > ItemData

local ItemData = {}

--[[
	Maps item model names to their properties.
	- Category: The type of zone this item can be placed in.
	- BaseVolume: The item's default Net Habitable Volume in cubic meters (m³).
	- FriendlyName: A clean, display-friendly name for the item.
]]
ItemData.Properties = {
	-- Deck 3: Exercise
	["CycleErgometer"] = { Category = "Exercise", BaseVolume = 3.38, FriendlyName = "Cycle Ergometer" },
	["Treadmill"] = { Category = "Exercise", BaseVolume = 6.12, FriendlyName = "Treadmill" },
	["ResistiveDevice"] = { Category = "Exercise", BaseVolume = 3.92, FriendlyName = "Resistive Exercise Device" },

	-- Deck 1: Kitchen & Dining
	["FoodPrepStation"] = { Category = "Kitchen", BaseVolume = 7.65, FriendlyName = "Food Prep Station" },
	["DiningTable"] = { Category = "Dining", BaseVolume = 10.09, FriendlyName = "Dining Table" },

	-- Deck 1: Medical
	["MedicalCouch"] = { Category = "Medical", BaseVolume = 5.80, FriendlyName = "Medical Couch" },
	["MedicalWorkstation"] = { Category = "Medical", BaseVolume = 1.20, FriendlyName = "Medical Workstation" },

	-- Deck 1: Hygiene & Waste
	["HygieneStation"] = { Category = "Hygiene", BaseVolume = 6.71, FriendlyName = "Hygiene Station" },
	["WasteManagementUnit"] = { Category = "Hygiene", BaseVolume = 3.76, FriendlyName = "Waste Management Unit" },

	-- Deck 1: Work & Recreation
	["MissionControl"] = { Category = "Workstation", BaseVolume = 3.42, FriendlyName = "Mission Control" },
	["GeneralWorkstation"] = { Category = "Workstation", BaseVolume = 4.30, FriendlyName = "General Workstation" },
	["RecreationArea"] = { Category = "Recreation", BaseVolume = 18.20, FriendlyName = "Recreation Area" },

	-- Deck 2: Private Cabins
	["SleepingBerth"] = { Category = "CrewCabin", BaseVolume = 4.0, FriendlyName = "Sleeping Berth" },
	["PersonalComputer"] = { Category = "CrewCabin", BaseVolume = 3.5, FriendlyName = "Personal Computer" },

	-- Storage
	["StorageShelves"] = { Category = "Storage", BaseVolume = 6.00, FriendlyName = "Storage Shelves" },
}

function ItemData.Get(itemName)
	return ItemData.Properties[itemName]
end

return ItemData