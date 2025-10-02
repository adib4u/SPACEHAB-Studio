--[[
	LocalScript: HabitatPlacementClient
	Version: Final - Robust WaitForChild Implementation
	Author: Gemini
	Location: StarterPlayer > StarterPlayerScripts

	Description: 
	Handles all client-side logic for the habitat placement system. This version is hardened
	with WaitForChild to prevent errors during game loading.
	- Visualizes valid placement zones as semi-transparent parts only when placing an item.
	- Displays the name of each visible zone on a temporary BillboardGui.
	- Provides real-time on-screen validation and volume feedback.
	- Handles all player inputs for placement, rotation, and scaling.
]]

--// SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

--// REFERENCES
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

--// MODULES
local ConfigsFolder = ReplicatedStorage:WaitForChild("Configs")
local ItemData = require(ConfigsFolder:WaitForChild("ItemData"))
local ZoneData = require(ConfigsFolder:WaitForChild("ZoneData"))

--// ASSETS & EVENTS
local habitatModules = ReplicatedStorage:WaitForChild("HabitatModules")
local interiorItems = ReplicatedStorage:WaitForChild("InteriorItems")
local placeModuleEvent = ReplicatedStorage:WaitForChild("PlaceHabitatModule")
local placeItemEvent = ReplicatedStorage:WaitForChild("PlaceInteriorItem")

--// WORKSPACE REFERENCES
local PLACEMENT_ZONES_FOLDER = workspace:WaitForChild("PlacementZones")

--// UI REFERENCES
-- Safely wait for all UI elements to exist before proceeding.
local GuiController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("GuiController"))
local mainGui = GuiController.Guis.HUDGui -- Assumes GuiController handles waiting internally
local mainHolder = mainGui:WaitForChild("Left", 5) and mainGui.Left:WaitForChild("Holder", 5)
local interiorItemsFrame = mainHolder and mainHolder:WaitForChild("ScrollingFrame", 5)

--// UI SETUP
local validationGui = Instance.new("ScreenGui")
validationGui.Name = "ValidationGui"
validationGui.ResetOnSpawn = false
local validationLabel = Instance.new("TextLabel")
validationLabel.Name = "ValidationLabel"
validationLabel.Size = UDim2.new(0, 450, 0, 50); validationLabel.AnchorPoint = Vector2.new(0.5, 1)
validationLabel.Position = UDim2.new(0.5, 0, 0.95, 0); validationLabel.BackgroundTransparency = 0.4
validationLabel.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1); validationLabel.TextColor3 = Color3.new(1, 1, 1)
validationLabel.Font = Enum.Font.SourceSansBold; validationLabel.TextScaled = true
validationLabel.TextStrokeTransparency = 0; validationLabel.Visible = false
validationLabel.Parent = validationGui
validationGui.Parent = playerGui

--// CLIENT-SIDE STATE
local currentGhostModel = nil; local isPlacing = false; local currentItemInfo = nil
local currentRotation = CFrame.new(); local isVolumeChangingEnabled = false
local originalPartSizes = {}; local currentScale = 1
local VOLUME_CHANGE_STEP = 0.05; local MIN_SCALE = 0.1
local zoneParts = {}; local clientZoneVolumes = {}

-- Safely populate zoneParts dictionary
for zoneName, _ in pairs(ZoneData.Properties) do
	clientZoneVolumes[zoneName] = 0
	local foundZonePart = PLACEMENT_ZONES_FOLDER:FindFirstChild(zoneName)
	if foundZonePart then
		zoneParts[zoneName] = foundZonePart
	else
		warn(string.format("[CRITICAL] ZoneData has key '%s', but no Part with that name exists in Workspace/PlacementZones!", zoneName))
	end
end

--============================================================================--
--// INITIALIZATION
--============================================================================--
local function initializeZoneGUIs()
	local guiCount = 0
	for zoneName, zonePart in pairs(zoneParts) do
		if zonePart then
			local zoneInfo = ZoneData.Get(zoneName)
			if zoneInfo then
				zonePart.Transparency = 1
				local billboardGui = Instance.new("BillboardGui"); billboardGui.Name = "ZoneNameDisplay"
				billboardGui.Adornee = zonePart; billboardGui.Size = UDim2.new(10, 0, 2, 0)
				billboardGui.StudsOffset = Vector3.new(0, 2, 0); billboardGui.AlwaysOnTop = true
				billboardGui.Enabled = false
				local textLabel = Instance.new("TextLabel"); textLabel.Size = UDim2.new(1, 0, 1, 0)
				textLabel.BackgroundTransparency = 1; textLabel.Text = zoneInfo.FriendlyName
				textLabel.Font = Enum.Font.SourceSansBold; textLabel.TextColor3 = Color3.new(1, 1, 1)
				textLabel.TextScaled = true; textLabel.TextStrokeTransparency = 0.5
				textLabel.Parent = billboardGui; billboardGui.Parent = zonePart
				guiCount = guiCount + 1
			end
		end
	end
	print(string.format("Zone name GUIs initialized for %d zones.", guiCount))
end

--============================================================================--
--// HELPER FUNCTIONS
--============================================================================--
local function showValidationMessage(message, isSuccess)
	validationLabel.Text = message
	validationLabel.TextColor3 = isSuccess and Color3.fromRGB(85, 255, 127) or Color3.fromRGB(255, 85, 85)
	validationLabel.Visible = true
end

local function hideValidationMessage() validationLabel.Visible = false end

local function setZoneVisibility(itemCategory, visible)
	for zoneName, zonePart in pairs(zoneParts) do
		if zonePart then
			local zoneInfo = ZoneData.Get(zoneName)
			if zoneInfo and zoneInfo.Category == itemCategory then
				zonePart.Color = zoneInfo.Color
				local targetTransparency = visible and 0.7 or 1
				TweenService:Create(zonePart, TweenInfo.new(0.3), { Transparency = targetTransparency }):Play()
				
				-- Safely find the GUI created during initialization
				local nameGui = zonePart:WaitForChild("ZoneNameDisplay", 1)
				if nameGui then nameGui.Enabled = visible end
			end
		end
	end
end

local function cancelPlacement()
	if not currentGhostModel then return end
	if currentItemInfo then setZoneVisibility(currentItemInfo.Category, false) end
	currentGhostModel:Destroy(); currentGhostModel = nil; isPlacing = false
	currentItemInfo = nil; hideValidationMessage()
end

--============================================================================--
--// CORE PLACEMENT LOGIC
--============================================================================--
local function updateGhostVolume()
	if not (currentGhostModel and currentItemInfo) then return end
	for part, originalSize in pairs(originalPartSizes) do
		if part and part.Parent then part.Size = originalSize * currentScale end
	end
	local primaryPart = currentGhostModel.PrimaryPart
	if primaryPart then
		local billboardGui = primaryPart:WaitForChild("VolumeDisplay", 1)
		if billboardGui then
			local textLabel = billboardGui:WaitForChild("VolumeLabel", 1)
			if textLabel then
				local displayedVolume = currentItemInfo.BaseVolume * (currentScale ^ 3)
				local modeText = isVolumeChangingEnabled and " [Scaling ON]" or ""
				textLabel.Text = string.format("Volume: %.2f m³%s", displayedVolume, modeText)
			end
		end
	end
end

local function createGhostModel(name, isModule)
	cancelPlacement()
	local templateModel = isModule and habitatModules:WaitForChild(name, 2) or interiorItems:WaitForChild(name, 2)
	if not templateModel then warn("Could not find template model: "..name); return end
	if not isModule then
		currentItemInfo = ItemData.Get(name)
		if not currentItemInfo then warn("No ItemData for: " .. name); return end
	end
	currentGhostModel = templateModel:Clone()
	if not currentGhostModel.PrimaryPart then warn("Template model '"..name.."' is missing its PrimaryPart!"); currentGhostModel:Destroy(); return end
	isPlacing = true; currentRotation = CFrame.new(); isVolumeChangingEnabled = false
	currentScale = 1; originalPartSizes = {}
	for _, part in ipairs(currentGhostModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 0.6; part.CanCollide = false; part.Anchored = true
			if not isModule then originalPartSizes[part] = part.Size end
		end
	end
	if currentItemInfo and currentItemInfo.BaseVolume > 0 and currentGhostModel.PrimaryPart then
		local billboardGui = Instance.new("BillboardGui"); billboardGui.Name = "VolumeDisplay"; billboardGui.Adornee = currentGhostModel.PrimaryPart
		billboardGui.Size = UDim2.new(8, 0, 2, 0); billboardGui.StudsOffset = Vector3.new(0, 3.5, 0); billboardGui.AlwaysOnTop = true
		local textLabel = Instance.new("TextLabel"); textLabel.Name = "VolumeLabel"; textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1; textLabel.TextColor3 = Color3.new(1, 1, 1); textLabel.TextScaled = true
		textLabel.Font = Enum.Font.SourceSansBold; textLabel.TextStrokeTransparency = 0.2; textLabel.TextStrokeColor3 = Color3.new(0,0,0)
		textLabel.Parent = billboardGui; billboardGui.Parent = currentGhostModel.PrimaryPart
	end
	currentGhostModel.Parent = workspace
	if not isModule then
		setZoneVisibility(currentItemInfo.Category, true)
		updateGhostVolume()
	end
end

local function onRenderStep()
	if not (isPlacing and currentGhostModel and currentGhostModel.PrimaryPart) then return end
	local primaryPart = currentGhostModel.PrimaryPart; local mouseLocation = UserInputService:GetMouseLocation()
	local unitRay = workspace.CurrentCamera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local raycastParams = RaycastParams.new(); raycastParams.FilterDescendantsInstances = { currentGhostModel }; raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
	if not raycastResult then hideValidationMessage(); return end
	local normal = raycastResult.Normal; local position = raycastResult.Position
	local orientation = CFrame.lookAt(Vector3.new(), normal) * currentRotation
	local partSize = primaryPart.Size; local cframe_noPos = primaryPart.CFrame - primaryPart.CFrame.Position
	local rightVec = cframe_noPos.RightVector; local upVec = cframe_noPos.UpVector; local lookVec = cframe_noPos.LookVector
	local totalOffset = math.abs(rightVec:Dot(normal) * partSize.X / 2) + math.abs(upVec:Dot(normal) * partSize.Y / 2) + math.abs(lookVec:Dot(normal) * partSize.Z / 2)
	local correctedCFrame = CFrame.new(position + normal * totalOffset) * (orientation - orientation.Position)
	currentGhostModel:SetPrimaryPartCFrame(correctedCFrame)
	if currentItemInfo then
		local touchingParts = workspace:GetPartsInPart(primaryPart); local currentZonePart = nil
		for _, part in ipairs(touchingParts) do if part.Parent == PLACEMENT_ZONES_FOLDER then currentZonePart = part; break end end
		if not currentZonePart then showValidationMessage("❌ Place item inside a designated colored zone.", false); return end
		local zoneName = currentZonePart.Name; local zoneInfo = ZoneData.Get(zoneName)
		if not zoneInfo or zoneInfo.Category ~= currentItemInfo.Category then showValidationMessage("❌ This item does not belong in the " .. (zoneInfo and zoneInfo.FriendlyName or "zone") .. ".", false); return end
		local ghostVolume = currentItemInfo.BaseVolume * (currentScale ^ 3)
		if clientZoneVolumes[zoneName] + ghostVolume > zoneInfo.MaxVolume + 0.01 then showValidationMessage("❌ " .. zoneInfo.FriendlyName .. " Volume Insufficient.", false); return end
		showValidationMessage("✅ NASA Compliant!", true)
	end
end

local function onInputBegan(input, gameProcessedEvent)
	if gameProcessedEvent or not isPlacing then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then cancelPlacement() end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if currentItemInfo then
			local ghostPart = currentGhostModel.PrimaryPart; local touchingParts = workspace:GetPartsInPart(ghostPart); local targetZonePart = nil
			for _, part in ipairs(touchingParts) do if part.Parent == PLACEMENT_ZONES_FOLDER then targetZonePart = part; break end end
			if not targetZonePart then return end
			local zoneName = targetZonePart.Name; local zoneInfo = ZoneData.Get(zoneName)
			if not zoneInfo or zoneInfo.Category ~= currentItemInfo.Category then return end
			local ghostVolume = currentItemInfo.BaseVolume * (currentScale ^ 3)
			if clientZoneVolumes[zoneName] + ghostVolume > zoneInfo.MaxVolume + 0.01 then return end
			clientZoneVolumes[zoneName] += ghostVolume
			placeItemEvent:FireServer(currentGhostModel.Name, ghostPart.CFrame, ghostPart.Size, zoneName)
			createGhostModel(currentGhostModel.Name, false) 
		else
			placeModuleEvent:FireServer(currentGhostModel.Name, currentGhostModel.PrimaryPart.CFrame); cancelPlacement()
		end
	end
	if input.KeyCode == Enum.KeyCode.R then currentRotation = currentRotation * CFrame.Angles(0, math.rad(45), 0) end
	if currentItemInfo and currentItemInfo.BaseVolume > 0 then
		if input.KeyCode == Enum.KeyCode.V then isVolumeChangingEnabled = not isVolumeChangingEnabled; updateGhostVolume() end
		if isVolumeChangingEnabled then
			if input.KeyCode == Enum.KeyCode.Equals then currentScale = currentScale + VOLUME_CHANGE_STEP; updateGhostVolume() end
			if input.KeyCode == Enum.KeyCode.Minus then currentScale = math.max(MIN_SCALE, currentScale - VOLUME_CHANGE_STEP); updateGhostVolume() end
		end
	end
end

--============================================================================--
--// SCRIPT EXECUTION START
--============================================================================--

initializeZoneGUIs()

--============================================================================--
--// CONNECTIONS
--============================================================================--

if not mainHolder then
	error("Could not find Main UI Holder. Check UI path and ensure GUI is enabled.")
end

print("Setting up UI button connections...")
local cylinderButton = mainHolder:WaitForChild("Cylinder", 5)
if cylinderButton then cylinderButton.MouseButton1Click:Connect(function() createGhostModel("Cylinder", true) end) else warn("UI Button 'Cylinder' not found") end
local domeButton = mainHolder:WaitForChild("Dome", 5)
if domeButton then domeButton.MouseButton1Click:Connect(function() createGhostModel("Dome", true) end) else warn("UI Button 'Dome' not found") end

if interiorItemsFrame then
	for _, button in ipairs(interiorItemsFrame:GetChildren()) do
		if button:IsA("ImageButton") or button:IsA("TextButton") then
			local itemName = button.Name
			button.MouseButton1Click:Connect(function()
				print("UI Request to place item: " .. itemName)
				createGhostModel(itemName, false)
			end)
		end
	end
else
	warn("Could not find Interior Items ScrollingFrame. Check UI path.")
end

UserInputService.InputBegan:Connect(onInputBegan)
RunService.RenderStepped:Connect(onRenderStep)

print("HabitatPlacementClient Initialized Successfully.")