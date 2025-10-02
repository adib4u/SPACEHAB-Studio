--[[
	Script: HabitatPlacementServer
	Author: Gemini
	Description: 
	Handles all server-side logic for placing habitat modules and interior items.
	This script is the single source of truth for zone volumes, validating every 
	placement request to ensure it complies with the defined habitat rules.
]]

--// SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--// MODULES
-- These modules contain the core data for items and placement zones.
local ItemData = require(ReplicatedStorage:WaitForChild("Configs").ItemData)
local ZoneData = require(ReplicatedStorage:WaitForChild("Configs").ZoneData)

--// ASSETS (RemoteEvents)
local habitatModules = ReplicatedStorage:WaitForChild("HabitatModules")
local interiorItems = ReplicatedStorage:WaitForChild("InteriorItems")
local placeModuleEvent = ReplicatedStorage:WaitForChild("PlaceHabitatModule")
local placeItemEvent = ReplicatedStorage:WaitForChild("PlaceInteriorItem")

--// SERVER STATE
-- This table tracks the current total volume of all items placed in each zone.
-- It is the authoritative state that prevents players from exceeding volume limits.
local zoneVolumes = {}

-- Initialize the volume tracker for every zone defined in ZoneData.
for zoneName, _ in pairs(ZoneData.Properties) do
	zoneVolumes[zoneName] = 0
end
print("HabitatPlacementServer Initialized: Zone volumes ready.")


--============================================================================--
--// FUNCTION: onPlaceModule
--// Handles the placement of large habitat structures like Cylinders or Domes.
--// These do not have zone or volume restrictions.
--============================================================================--
local function onPlaceModule(player, modelName, cframe) 
	local templateModel = habitatModules:FindFirstChild(modelName)

	if templateModel then
		print(player.Name .. " is placing a module: " .. modelName)
		local newModule = templateModel:Clone()

		-- Finalize the properties of all parts in the new module
		for _, part in ipairs(newModule:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 0
				part.CanCollide = true
				part.Anchored = true
			end
		end

		newModule:SetPrimaryPartCFrame(cframe) 
		newModule.Parent = workspace
	else
		warn(player.Name .. " tried to place an invalid module: " .. tostring(modelName))
	end
end


--============================================================================--
--// FUNCTION: onPlaceItem
--// Handles the placement and validation of interior items.
--============================================================================--
local function onPlaceItem(player, modelName, cframe, finalSize, targetZoneName)
	-- Step 1: Validate all incoming data from the client
	local templateModel = interiorItems:FindFirstChild(modelName)
	local itemInfo = ItemData.Get(modelName)
	local zoneInfo = ZoneData.Get(targetZoneName)

	if not (templateModel and itemInfo and zoneInfo) then
		warn(player.Name .. " sent invalid placement data (Item, ItemInfo, or ZoneInfo not found).")
		return
	end

	-- Security Check: Ensure the item category matches the zone category
	if itemInfo.Category ~= zoneInfo.Category then
		warn(player.Name .. " tried to place item in a mismatched category zone.")
		return
	end

	-- Step 2: Calculate the final volume based on client-provided size
	local primaryPartTemplate = templateModel.PrimaryPart
	if not primaryPartTemplate then
		warn("Item '".. modelName .."' is missing a PrimaryPart and cannot be placed.")
		return
	end
	
	local originalSize = primaryPartTemplate.Size
	local finalVolume = itemInfo.BaseVolume
	
	-- Only apply scaling if the data is valid
	if finalSize and typeof(finalSize) == "Vector3" and originalSize.Magnitude > 0 then
		local scaleVector = finalSize / originalSize
		-- The volume scales cubically with the linear scale factor
		finalVolume = itemInfo.BaseVolume * scaleVector.X * scaleVector.Y * scaleVector.Z
	end

	-- Security Check: Validate against server-side volume state
	-- Use a small tolerance (0.01) to account for floating point inaccuracies.
	if zoneVolumes[targetZoneName] + finalVolume > zoneInfo.MaxVolume + 0.01 then
		warn(player.Name .. " exceeded volume limit for zone '" .. targetZoneName .. "'. Placement rejected.")
		return
	end

	-- Step 3: All checks passed. Update server state and create the item.
	zoneVolumes[targetZoneName] = zoneVolumes[targetZoneName] + finalVolume
	print(string.format("✅ Placement Validated: Zone '%s' volume is now %.2f / %.2f m³.", zoneInfo.FriendlyName, zoneVolumes[targetZoneName], zoneInfo.MaxVolume))
	
	local newItem = templateModel:Clone()
	
	-- Apply the final size to all parts of the new item model
	if finalSize and originalSize.Magnitude > 0 then
		local scale = finalSize / originalSize
		for _, part in ipairs(newItem:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Size = part.Size * scale
			end
		end
	end
	
	-- Finalize the properties of all parts
	for _, part in ipairs(newItem:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 0
			part.CanCollide = true
			part.Anchored = true
		end
	end
	
	newItem:SetPrimaryPartCFrame(cframe) 
	newItem.Parent = workspace
end


--// CONNECTIONS
-- Listen for events fired from the client scripts
placeModuleEvent.OnServerEvent:Connect(onPlaceModule)
placeItemEvent.OnServerEvent:Connect(onPlaceItem)