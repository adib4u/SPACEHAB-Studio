--[[
	Script: HabitatPlacementServer
	Version: Final + STRICT VALIDATION
	Author: Gemini
	Location: ServerScriptService

	Description: 
	Handles placement and deletion with STRICT size validation. An item will be
	rejected if its size does not match the standard template size.
]]

--// SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// MODULES
local ConfigsFolder = ReplicatedStorage:WaitForChild("Configs")
local ItemData = require(ConfigsFolder:WaitForChild("ItemData"))
local ZoneData = require(ConfigsFolder:WaitForChild("ZoneData"))

--// ASSETS & EVENTS
local placeModuleEvent = ReplicatedStorage:WaitForChild("PlaceHabitatModule")
local placeItemEvent = ReplicatedStorage:WaitForChild("PlaceInteriorItem")
local deleteItemEvent = ReplicatedStorage:WaitForChild("DeleteInteriorItem")

--// WORKSPACE REFERENCES
local habitatModules = ReplicatedStorage:WaitForChild("HabitatModules")
local interiorItems = ReplicatedStorage:WaitForChild("InteriorItems")
local PLACED_ITEMS_FOLDER = workspace:WaitForChild("PlacedItems")

--// SERVER STATE
local zoneVolumes = {}
for zoneName, _ in pairs(ZoneData.Properties) do
	zoneVolumes[zoneName] = 0
end
print("HabitatPlacementServer Initialized: Zone volumes ready.")

--============================================================================--
--// HELPER: Reusable volume calculation (used for deletion)
--============================================================================--
local function calculateCurrentVolume(modelName, currentSize)
	local itemInfo = ItemData.Get(modelName)
	local templateModel = interiorItems:FindFirstChild(modelName)
	if not (itemInfo and templateModel and templateModel.PrimaryPart) then return 0 end
	local originalSize = templateModel.PrimaryPart.Size
	if originalSize.Magnitude < 0.001 then return 0 end
	local scaleVector = currentSize / originalSize
	return itemInfo.BaseVolume * scaleVector.X * scaleVector.Y * scaleVector.Z
end

--============================================================================--
--// FUNCTION: onPlaceModule (Unchanged)
--============================================================================--
local function onPlaceModule(player, modelName, cframe)
	-- This logic remains correct and unchanged.
	local templateModel = habitatModules:FindFirstChild(modelName)
	if templateModel then
		local newModule = templateModel:Clone()
		for _, part in ipairs(newModule:GetDescendants()) do
			if part:IsA("BasePart") then part.Transparency = 0; part.CanCollide = true; part.Anchored = true end
		end
		newModule:SetPrimaryPartCFrame(cframe); newModule.Parent = workspace
	end
end

--============================================================================--
--// FUNCTION: onPlaceItem (CRITICAL FIX)
--============================================================================--
local function onPlaceItem(player, modelName, cframe, finalSize, targetZoneName)
	local itemInfo = ItemData.Get(modelName)
	local zoneInfo = ZoneData.Get(targetZoneName)
	local templateModel = interiorItems:FindFirstChild(modelName)

	if not (itemInfo and zoneInfo and templateModel and templateModel.PrimaryPart) then return end

	-- 1. STRICT SIZE VALIDATION: Check if the received size matches the original.
	local originalSize = templateModel.PrimaryPart.Size
	if (finalSize - originalSize).Magnitude > 0.01 then
		warn(string.format("Player %s tried to place %s with a non-standard size. Rejected.", player.Name, modelName))
		return
	end

	-- 2. VOLUME VALIDATION (using BASE volume)
	local standardVolume = itemInfo.BaseVolume
	if zoneVolumes[targetZoneName] + standardVolume > zoneInfo.MaxVolume + 0.001 then
		warn(string.format("Player %s placement rejected. Zone %s is full.", player.Name, targetZoneName))
		return
	end

	-- 3. Update State & Create Item
	zoneVolumes[targetZoneName] = zoneVolumes[targetZoneName] + standardVolume
	print(string.format("✅ Placed: Zone '%s' now %.2f/%.2f m³.", zoneInfo.FriendlyName, zoneVolumes[targetZoneName], zoneInfo.MaxVolume))
	
	local newItem = templateModel:Clone() -- Just clone, no resizing needed.

	-- Finalize Parts
	for _, part in ipairs(newItem:GetDescendants()) do
		if part:IsA("BasePart") then part.Transparency = 0; part.CanCollide = true; part.Anchored = true end
	end
	
	-- Stamp attributes
	newItem:SetAttribute("OriginalName", modelName)
	newItem:SetAttribute("PlacedZone", targetZoneName)

	newItem:SetPrimaryPartCFrame(cframe) 
	newItem.Parent = PLACED_ITEMS_FOLDER 

	-- Create Permanent BillboardGui (using standard volume)
	if itemInfo.BaseVolume > 0 and newItem.PrimaryPart then
		local billboardGui = Instance.new("BillboardGui"); billboardGui.Name = "VolumeDisplay"
		billboardGui.Adornee = newItem.PrimaryPart; billboardGui.Size = UDim2.new(8, 0, 2.5, 0)
		billboardGui.StudsOffset = Vector3.new(0, 3, 0); billboardGui.AlwaysOnTop = true
		local textLabel = Instance.new("TextLabel"); textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1; textLabel.TextColor3 = Color3.new(1, 1, 1)
		textLabel.TextScaled = true; textLabel.Font = Enum.Font.SourceSansBold
		textLabel.TextStrokeTransparency = 0.2; textLabel.TextStrokeColor3 = Color3.new(0,0,0)
		textLabel.RichText = true; local friendlyName = itemInfo.FriendlyName or modelName
		textLabel.Text = string.format("<b>%s</b>\nVolume: %.2f m³", friendlyName, standardVolume)
		textLabel.Parent = billboardGui; billboardGui.Parent = newItem.PrimaryPart
	end
end

--============================================================================--
--// NEW FUNCTION: onDeleteItem (Unchanged)
--============================================================================--
local function onDeleteItem(player, targetModel)
	if not targetModel or not targetModel:IsDescendantOf(PLACED_ITEMS_FOLDER) then return end
	local originalName = targetModel:GetAttribute("OriginalName")
	local placedZone = targetModel:GetAttribute("PlacedZone")
	if not (originalName and placedZone and targetModel.PrimaryPart) then return end
	local volumeToRestore = calculateCurrentVolume(originalName, targetModel.PrimaryPart.Size)
	if zoneVolumes[placedZone] then
		zoneVolumes[placedZone] = math.max(0, zoneVolumes[placedZone] - volumeToRestore)
		print(string.format("🗑️ Deleted %s. Zone '%s' restored to %.2f m³.", originalName, placedZone, zoneVolumes[placedZone]))
	end
	targetModel:Destroy()
end

--// CONNECTIONS
placeModuleEvent.OnServerEvent:Connect(onPlaceModule)
placeItemEvent.OnServerEvent:Connect(onPlaceItem)
deleteItemEvent.OnServerEvent:Connect(onDeleteItem)