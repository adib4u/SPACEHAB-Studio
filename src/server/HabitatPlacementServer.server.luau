--[[
	Script: HabitatPlacementServer
	Description: 
	Handles all server-side logic for placing habitat modules and interior items.
	This script is the single source of truth for zone volumes, validating every 
	placement request to ensure it complies with the defined habitat rules.
]]

--// SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--// MODULES
local ItemData = require(ReplicatedStorage:WaitForChild("Configs").ItemData)
local ZoneData = require(ReplicatedStorage:WaitForChild("Configs").ZoneData)

--// ASSETS (RemoteEvents)
local habitatModules = ReplicatedStorage:WaitForChild("HabitatModules")
local interiorItems = ReplicatedStorage:WaitForChild("InteriorItems")
local placeModuleEvent = ReplicatedStorage:WaitForChild("PlaceHabitatModule")
local placeItemEvent = ReplicatedStorage:WaitForChild("PlaceInteriorItem")

--// SERVER STATE
local zoneVolumes = {}
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
--// Handles placement, validation, and creation of the PERMANENT BillboardGui.
--============================================================================--
local function onPlaceItem(player, modelName, cframe, finalSize, targetZoneName)
	-- Step 1: Validation Checks
	local templateModel = interiorItems:FindFirstChild(modelName)
	local itemInfo = ItemData.Get(modelName)
	local zoneInfo = ZoneData.Get(targetZoneName)

	if not (templateModel and itemInfo and zoneInfo) then return end
	if itemInfo.Category ~= zoneInfo.Category then return end

	local primaryPartTemplate = templateModel.PrimaryPart
	if not primaryPartTemplate then return end
	
	-- Step 2: Calculate final volume and validate against server state
	local originalSize = primaryPartTemplate.Size
	local finalVolume = itemInfo.BaseVolume
	if finalSize and typeof(finalSize) == "Vector3" and originalSize.Magnitude > 0 then
		local scaleVector = finalSize / originalSize
		finalVolume = itemInfo.BaseVolume * scaleVector.X * scaleVector.Y * scaleVector.Z
	end

	if zoneVolumes[targetZoneName] + finalVolume > zoneInfo.MaxVolume + 0.01 then return end

	-- Step 3: All checks passed. Update server state and create the item.
	zoneVolumes[targetZoneName] = zoneVolumes[targetZoneName] + finalVolume
	print(string.format("✅ Placement Validated: Zone '%s' volume is now %.2f / %.2f m³.", zoneInfo.FriendlyName, zoneVolumes[targetZoneName], zoneInfo.MaxVolume))
	
	local newItem = templateModel:Clone()
	
	-- Apply final size
	if finalSize and originalSize.Magnitude > 0 then
		local scale = finalSize / originalSize
		for _, part in ipairs(newItem:GetDescendants()) do
			if part:IsA("BasePart") then part.Size = part.Size * scale end
		end
	end
	
	-- Finalize properties
	for _, part in ipairs(newItem:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 0
			part.CanCollide = true
			part.Anchored = true
		end
	end
	
	newItem:SetPrimaryPartCFrame(cframe) 
	newItem.Parent = workspace

	--========================================================================--
	--// THIS IS THE PERMANENT BILLBOARD GUI LOGIC (SERVER-SIDE)
	--// This code creates the volume display on the final, placed item for all players to see.
	--========================================================================--
	if itemInfo.BaseVolume > 0 then
		local primaryPart = newItem.PrimaryPart
		if primaryPart then
			local billboardGui = Instance.new("BillboardGui")
			billboardGui.Name = "VolumeDisplay"
			billboardGui.Adornee = primaryPart
			billboardGui.Size = UDim2.new(6, 0, 1.5, 0)
			billboardGui.StudsOffset = Vector3.new(0, 3, 0) -- Position it above the part
			billboardGui.AlwaysOnTop = true

			local textLabel = Instance.new("TextLabel")
			textLabel.Size = UDim2.new(1, 0, 1, 0)
			textLabel.BackgroundTransparency = 1
			textLabel.TextColor3 = Color3.new(1, 1, 1)
			textLabel.TextScaled = true
			textLabel.Font = Enum.Font.SourceSansBold
			textLabel.TextStrokeTransparency = 0.2
			textLabel.TextStrokeColor3 = Color3.new(0,0,0)
			
			-- Display the final calculated volume
			textLabel.Text = string.format("Volume: %.2f m³", finalVolume)

			textLabel.Parent = billboardGui
			billboardGui.Parent = primaryPart
		end
	end
	--// END OF BILLBOARD GUI LOGIC
	--========================================================================--
end


--// CONNECTIONS
-- Listen for events fired from the client scripts
placeModuleEvent.OnServerEvent:Connect(onPlaceModule)
placeItemEvent.OnServerEvent:Connect(onPlaceItem)