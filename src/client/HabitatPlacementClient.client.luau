--[[
	LocalScript: HabitatPlacementClient
	Author: Gemini
	Description: 
	Handles all client-side logic for the habitat placement system. This includes:
	- Creating and controlling a "ghost" model for placement.
	- Visualizing valid placement zones based on item category.
	- Handling all player inputs (mouse movement, clicks, rotation, scaling).
	- Providing real-time on-screen validation feedback (e.g., "NASA Compliant!").
	- Communicating final placement data to the server for authorization.
	
	--// PLAYER CONTROLS
	- Left Click: Place item/module.
	- Right Click: Cancel placement.
	- R Key: Rotate item.
	- V Key: Toggle volume scaling mode for items.
	- = Key: Increase volume (when scaling is enabled).
	- - Key: Decrease volume (when scaling isenabled).
]]

--// SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

--// MODULES
local ItemData = require(ReplicatedStorage:WaitForChild("Configs").ItemData)
local ZoneData = require(ReplicatedStorage:WaitForChild("Configs").ZoneData)

--// ASSETS & EVENTS
local habitatModules = ReplicatedStorage:WaitForChild("HabitatModules")
local interiorItems = ReplicatedStorage:WaitForChild("InteriorItems")
local placeModuleEvent = ReplicatedStorage:WaitForChild("PlaceHabitatModule")
local placeItemEvent = ReplicatedStorage:WaitForChild("PlaceInteriorItem")

--// WORKSPACE REFERENCES
local PLACEMENT_ZONES_FOLDER = workspace:WaitForChild("PlacementZones")

--// UI SETUP
-- Creates the validation GUI programmatically to keep the script self-contained.
local validationGui = Instance.new("ScreenGui")
validationGui.Name = "ValidationGui"
validationGui.ResetOnSpawn = false
local validationLabel = Instance.new("TextLabel")
validationLabel.Name = "ValidationLabel"
validationLabel.Size = UDim2.new(0, 450, 0, 50)
validationLabel.AnchorPoint = Vector2.new(0.5, 1)
validationLabel.Position = UDim2.new(0.5, 0, 0.95, 0)
validationLabel.BackgroundTransparency = 0.4
validationLabel.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
validationLabel.TextColor3 = Color3.new(1, 1, 1)
validationLabel.Font = Enum.Font.SourceSansBold
validationLabel.TextScaled = true
validationLabel.TextStrokeTransparency = 0
validationLabel.Visible = false
validationLabel.Parent = validationGui
validationGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

--// CLIENT-SIDE STATE
local currentGhostModel = nil
local isPlacing = false
local currentItemInfo = nil
local currentRotation = CFrame.new()

-- Volume control state
local isVolumeChangingEnabled = false
local originalPartSizes = {}
local currentScale = 1
local VOLUME_CHANGE_STEP = 0.05
local MIN_SCALE = 0.1

-- Zone state
local zoneParts = {}
local clientZoneVolumes = {} -- Client's copy of zone volumes for instant feedback
for zoneName, _ in pairs(ZoneData.Properties) do
	clientZoneVolumes[zoneName] = 0
	zoneParts[zoneName] = PLACEMENT_ZONES_FOLDER:FindFirstChild(zoneName)
end


--============================================================================--
--// HELPER FUNCTIONS
--============================================================================--

-- Shows a validation message on the player's screen.
local function showValidationMessage(message, isSuccess)
	validationLabel.Text = message
	validationLabel.TextColor3 = isSuccess and Color3.fromRGB(85, 255, 127) or Color3.fromRGB(255, 85, 85)
	validationLabel.Visible = true
end

-- Hides the validation message.
local function hideValidationMessage()
	validationLabel.Visible = false
end

-- Shows or hides the placement zones for a specific item category.
local function setZoneVisibility(itemCategory, visible)
	for zoneName, zonePart in pairs(zoneParts) do
		if zonePart then
			local zoneInfo = ZoneData.Get(zoneName)
			-- Show zones that match the item's category.
			if zoneInfo and zoneInfo.Category == itemCategory then
				zonePart.Color = zoneInfo.Color
				local targetTransparency = visible and 0.7 or 1
				TweenService:Create(zonePart, TweenInfo.new(0.3), { Transparency = targetTransparency }):Play()
			end
		end
	end
end

-- Cleans up the current placement state.
local function cancelPlacement()
	if not currentGhostModel then return end
	
	if currentItemInfo then
		setZoneVisibility(currentItemInfo.Category, false)
	end
	
	currentGhostModel:Destroy()
	currentGhostModel = nil
	isPlacing = false
	currentItemInfo = nil
	hideValidationMessage()
end


--============================================================================--
--// CORE PLACEMENT LOGIC
--============================================================================--

-- Creates the ghost model and initializes the placement process.
local function createGhostModel(name, isModule)
	print("YYYYYYYYYYY")
	cancelPlacement() -- Clean up any previous state first

	local templateModel = isModule and habitatModules:FindFirstChild(name) or interiorItems:FindFirstChild(name)
	if not templateModel then return end

	if not isModule then
		currentItemInfo = ItemData.Get(name)
		if not currentItemInfo then
			warn("No ItemData found for: " .. name)
			return
		end
	end

	-- Initialize state variables
	currentGhostModel = templateModel:Clone()
	isPlacing = true
	currentRotation = CFrame.new()
	isVolumeChangingEnabled = false
	currentScale = 1
	originalPartSizes = {}
	
	-- Setup parts and store their original sizes for scaling calculations
	for _, part in ipairs(currentGhostModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 0.6
			part.CanCollide = false
			part.Anchored = true
			if not isModule then
				originalPartSizes[part] = part.Size
			end
		end
	end

	currentGhostModel.Parent = workspace
	
	-- Make the appropriate zones visible to the player
	if not isModule then
		setZoneVisibility(currentItemInfo.Category, true)
	end
end

-- Updates the size of the ghost model and its volume display based on the current scale.
local function updateGhostVolume()
	if not (currentGhostModel and currentItemInfo) then return end

	-- Resize all parts of the model proportionally
	for part, originalSize in pairs(originalPartSizes) do
		if part and part.Parent then
			part.Size = originalSize * currentScale
		end
	end
end

--============================================================================--
--// RUNSERVICE & USERINPUTSERVICE HANDLERS
--============================================================================--

-- This function runs every frame to update the ghost model's position and validate it.
local function onRenderStep()
	if not (isPlacing and currentGhostModel and currentGhostModel.PrimaryPart) then return end

	local primaryPart = currentGhostModel.PrimaryPart
	
	-- 1. Raycast from the mouse to find the surface below it
	local mouseLocation = UserInputService:GetMouseLocation()
	local unitRay = workspace.CurrentCamera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { currentGhostModel }
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)

	if not raycastResult then
		hideValidationMessage()
		return -- Hide ghost if not pointing at anything
	end
	
	-- 2. Calculate the correct CFrame to sit flush on the surface
	local normal = raycastResult.Normal
	local position = raycastResult.Position
	local orientation = CFrame.lookAt(Vector3.new(), normal) * currentRotation
	
	local partSize = primaryPart.Size -- Use the CURRENT, scaled size
	local cframe_noPos = primaryPart.CFrame - primaryPart.CFrame.Position
	
	local rightVec = cframe_noPos.RightVector
	local upVec = cframe_noPos.UpVector
	local lookVec = cframe_noPos.LookVector

	local totalOffset = math.abs(rightVec:Dot(normal) * partSize.X / 2)
		+ math.abs(upVec:Dot(normal) * partSize.Y / 2)
		+ math.abs(lookVec:Dot(normal) * partSize.Z / 2)
	
	local correctedCFrame = CFrame.new(position + normal * totalOffset) * (orientation - orientation.Position)
	currentGhostModel:SetPrimaryPartCFrame(correctedCFrame)
	
	-- 3. Perform real-time validation if placing an item
	if currentItemInfo then
		local touchingParts = workspace:GetPartsInPart(primaryPart)
		local currentZonePart = nil
		for _, part in ipairs(touchingParts) do
			if part.Parent == PLACEMENT_ZONES_FOLDER then
				currentZonePart = part
				break
			end
		end

		if not currentZonePart then
			showValidationMessage("❌ Place item inside a designated colored zone.", false)
			return
		end
		
		local zoneName = currentZonePart.Name
		local zoneInfo = ZoneData.Get(zoneName)

		if not zoneInfo or zoneInfo.Category ~= currentItemInfo.Category then
			showValidationMessage("❌ This item does not belong in the " .. (zoneInfo and zoneInfo.FriendlyName or "zone") .. ".", false)
			return
		end
		
		local ghostVolume = currentItemInfo.BaseVolume * (currentScale ^ 3)
		if clientZoneVolumes[zoneName] + ghostVolume > zoneInfo.MaxVolume + 0.01 then
			showValidationMessage("❌ " .. zoneInfo.FriendlyName .. " Volume Insufficient.", false)
			return
		end

		showValidationMessage("✅ NASA Compliant!", true)
	end
end

-- This function handles all key presses and mouse clicks.
local function onInputBegan(input, gameProcessedEvent)
	if gameProcessedEvent or not isPlacing then return end

	-- Cancel Placement
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		cancelPlacement()
	end

	-- Place Item/Module
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		print("ZZZZZZZZZZZZZz")
		if currentItemInfo then -- Placing an interior item
			-- Final validation check before sending to server
			local ghostPart = currentGhostModel.PrimaryPart
			local touchingParts = workspace:GetPartsInPart(ghostPart)
			local targetZonePart = nil
			for _, part in ipairs(touchingParts) do if part.Parent == PLACEMENT_ZONES_FOLDER then targetZonePart = part; break end end
			
			if not targetZonePart then return end
			local zoneName = targetZonePart.Name
			local zoneInfo = ZoneData.Get(zoneName)
			if not zoneInfo or zoneInfo.Category ~= currentItemInfo.Category then return end
			local ghostVolume = currentItemInfo.BaseVolume * (currentScale ^ 3)
			if clientZoneVolumes[zoneName] + ghostVolume > zoneInfo.MaxVolume + 0.01 then return end
			
			-- All checks passed. Update client state and fire to server.
			clientZoneVolumes[zoneName] += ghostVolume
			placeItemEvent:FireServer(currentGhostModel.Name, ghostPart.CFrame, ghostPart.Size, zoneName)
			
			-- Seamlessly start placing another of the same item
			createGhostModel(currentGhostModel.Name, false) 

		else -- Placing a module
			placeModuleEvent:FireServer(currentGhostModel.Name, currentGhostModel.PrimaryPart.CFrame)
			cancelPlacement()
		end
	end

	-- Rotate
	if input.KeyCode == Enum.KeyCode.R then
		currentRotation = currentRotation * CFrame.Angles(0, math.rad(45), 0)
	end
	
	-- Volume Controls (only for items with volume data)
	if currentItemInfo and currentItemInfo.BaseVolume > 0 then
		if input.KeyCode == Enum.KeyCode.V then
			isVolumeChangingEnabled = not isVolumeChangingEnabled
		end
		
		if isVolumeChangingEnabled then
			if input.KeyCode == Enum.KeyCode.Equals then
				currentScale = currentScale + VOLUME_CHANGE_STEP
				updateGhostVolume()
			end
			if input.KeyCode == Enum.KeyCode.Minus then
				currentScale = math.max(MIN_SCALE, currentScale - VOLUME_CHANGE_STEP)
				updateGhostVolume()
			end
		end
	end
end

--============================================================================--
--// CONNECTIONS
--============================================================================--

-- IMPORTANT: You must connect your UI buttons to the createGhostModel function.
-- Example (assuming you have a reference to your UI buttons):
local GuiController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("GuiController"))
local mainGui = GuiController.Guis.HUDGui
local mainHolder = mainGui:WaitForChild("Left"):WaitForChild("Holder")
local interiorItemsFrame = mainHolder:WaitForChild("ScrollingFrame")

print("Setting up UI button connections...")

--// Connect Habitat Module Buttons
-- These are the large, structural components. The second argument to createGhostModel is 'true'.

local cylinderButton = mainHolder:FindFirstChild("Cylinder")
if cylinderButton then
	cylinderButton.MouseButton1Click:Connect(function() 
		createGhostModel("Cylinder", true) 
	end)
else
	warn("UI Button 'Cylinder' not found in mainHolder.")
end

local domeButton = mainHolder:FindFirstChild("Dome")
if domeButton then
	domeButton.MouseButton1Click:Connect(function() 
		createGhostModel("Dome", true) 
	end)
else
	warn("UI Button 'Dome' not found in mainHolder.")
end


--// Connect Interior Item Buttons
-- This loop connects all buttons inside the ScrollingFrame for interior items.
-- The second argument to createGhostModel is 'false'.

for _, button in ipairs(interiorItemsFrame:GetChildren()) do
	-- Ensure we only connect valid button types
	if button:IsA("ImageButton") or button:IsA("TextButton") then
		local itemName = button.Name
		
		-- The button's name MUST match the model name in ReplicatedStorage/InteriorItems
		-- and the key name in the ItemData module.
		button.MouseButton1Click:Connect(function()
			print("UI Request to place item: " .. itemName)
			createGhostModel(itemName, false)
		end)
	end
end

-- Connect the core event handlers
UserInputService.InputBegan:Connect(onInputBegan)
RunService.RenderStepped:Connect(onRenderStep)

print("HabitatPlacementClient Initialized.")