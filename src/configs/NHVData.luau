--[[
	ModuleScript: NHVData
	Stores Net Habitable Volume (NHV) data for various habitat items.
	Data is extracted from "Table 16: Functional Spaces and Volumes" (Page 13) of the provided NASA PDF.
	The 4-crew volume is used as the base value.
]]

local NHVData = {}

-- Mapping descriptive names from the PDF to potential in-game item names.
-- Make sure the names here (e.g., "CycleErgometer") match the names of your Models in ReplicatedStorage/InteriorItems.
NHVData.Volumes = {
	-- Exercise
	["CycleErgometer"] = 6.12,
	["Treadmill"] = 3.38,
	["ResistiveDevice"] = 3.92,

	-- Social & Work
	["RecreationArea"] = 18.20, -- Group Social-1 (Open Area) / Mission Planning-3 (Training)
	["CommunalTable"] = 10.09, -- Group Social-2 (Table) / Meal Consumption / Mission Planning-1 (Table)

	-- Hygiene & Waste
	["WasteCollector"] = 2.36,
	["HygieneStation"] = 4.35, -- Human Waste-2 (Cleansing) / Hygiene-1 (Cleansing)
	["WasteManagementUnit"] = 3.76,

	-- Logistics
	["TemporaryStowage"] = 6.00,

	-- Maintenance
	["ComputerStation"] = 3.40, -- Maintenance-1 (Computer) / EVA-2 (EVA Computer/Data)
	["WorkSurface"] = 4.82, -- Maintenance-2 (Work Surface) / Logistics-1 (Work Surface) / EVA-1 (Suit Testing)

	-- Galley (Kitchen)
	["FoodPrepStation"] = 4.35,
	["GalleyWorkSurface"] = 3.30,

	-- Medical
	["MedicalComputer"] = 1.20,
	["MedicalBay"] = 5.80,

	-- Command
	["CommandConsole"] = 3.42, -- Mission Planning-2 (Computer/Command) / Spacecraft Monitoring

	-- Habitation
	["PrivateWorkstation"] = 17.40, -- Private Habitation-1 (Work Surface) / Medical-2 (Ambulatory Care)
	["SleepingQuarters"] = 13.96, -- Private Habitation-2 (Sleep & Relaxation) / Hygiene-2 (Non-Cleansing)
}

-- Function to get the base volume for an item.
-- Returns the volume number, or nil if the item is not in the dataset.
function NHVData.GetVolume(itemName)
	return NHVData.Volumes[itemName]
end

return NHVData