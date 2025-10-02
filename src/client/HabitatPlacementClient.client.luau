--[[
	LocalScript: HabitatPlacementClient
	Handles ghost model placement, snapping, and now volume controls.
	
	--// NEW CONTROLS
	- Press [V] while placing an item to toggle Volume Scaling mode.
	- When Scaling is ON, press [=] to increase volume and [-] to decrease volume.
	- Press [R] to rotate.
]]

--// SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

--// Dependencies
local GuiController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("GuiController"))
local NHVData = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("NHVData"))

--// ASSETS
local habitatModules = ReplicatedStorage:WaitForChild("HabitatModules")
local interiorItems = ReplicatedStorage:WaitForChild("InteriorItems")
local placeModuleEvent = ReplicatedStorage:WaitForChild("PlaceHabitatModule")
local placeItemEvent = ReplicatedStorage:WaitForChild("PlaceInteriorItem")

--// UI ELEMENTS
local Gui = GuiController.Guis.HUDGui
local mainFrame = Gui:WaitForChild("Left").Holder
local cylinderButton = mainFrame:WaitForChild("Cylinder")
local domeButton = mainFrame:WaitForChild("Dome")
local interiorItemsFrame = mainFrame:WaitForChild("ScrollingFrame")

--// VARIABLES
local currentGhostModel = nil
local isPlacing = false
local placementMode = "Module"
local currentRotation = CFrame.new()

--// NEW: Volume control variables
local isVolumeChangingEnabled = false
local originalPartSizes = {} -- Dictionary to store original sizes of all parts
local baseVolume = 0
local currentScale = 1
local VOLUME_CHANGE_STEP = 0.05
local MIN_SCALE = 0.1

--// FORWARD DECLARATIONS
local function updateGhostVolume() end

--// FUNCTIONS

local function createGhostModel(name, mode)
	if currentGhostModel then
		currentGhostModel:Destroy()
	end

	placementMode = mode
	currentRotation = CFrame.new()

	local templateModel = (mode == "Module") and habitatModules:FindFirstChild(name)
		or interiorItems:FindFirstChild(name)

	if not templateModel then return end

	currentGhostModel = templateModel:Clone()
	isPlacing = true

	-- Reset volume control state for the new item
	isVolumeChangingEnabled = false
	originalPartSizes = {}
	baseVolume = 0
	currentScale = 1
	
	local hasVolumeData = false
	if placementMode == "Item" then
		baseVolume = NHVData.GetVolume(name) or 0
		if baseVolume > 0 then
			hasVolumeData = true
		end
	end

	for _, descendant in ipairs(currentGhostModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 0.7
			descendant.CanCollide = false
			descendant.Anchored = true
			if hasVolumeData then
				originalPartSizes[descendant] = descendant.Size -- Store original size for scaling
			end
		end
	end

	-- Create and setup the Billboard GUI if the item has volume data
	if hasVolumeData and currentGhostModel.PrimaryPart then
		local billboardGui = Instance.new("BillboardGui")
		billboardGui.Name = "VolumeDisplay"
		billboardGui.Adornee = currentGhostModel.PrimaryPart
		billboardGui.Size = UDim2.new(6, 0, 1.5, 0)
		billboardGui.StudsOffset = Vector3.new(0, 3, 0)
		billboardGui.AlwaysOnTop = true

		local textLabel = Instance.new("TextLabel")
		textLabel.Name = "VolumeLabel"
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.TextColor3 = Color3.new(1, 1, 1)
		textLabel.TextScaled = true
		textLabel.Font = Enum.Font.SourceSansBold
		textLabel.TextStrokeTransparency = 0.5
		textLabel.Parent = billboardGui

		billboardGui.Parent = currentGhostModel.PrimaryPart
		updateGhostVolume() -- Set initial text on the GUI
	end

	currentGhostModel.Parent = workspace
end

--// NEW: Updates the size and UI of the ghost model based on currentScale
function updateGhostVolume()
	if not currentGhostModel or baseVolume == 0 then return end

	-- Resize all parts of the model proportionally
	for part, originalSize in pairs(originalPartSizes) do
		if part and part.Parent then
			part.Size = originalSize * currentScale
		end
	end
	
	-- Update the Billboard GUI text
	local primaryPart = currentGhostModel.PrimaryPart
	if primaryPart then
		local billboardGui = primaryPart:FindFirstChild("VolumeDisplay")
		if billboardGui then
			local textLabel = billboardGui:FindFirstChild("VolumeLabel")
			local displayedVolume = baseVolume * (currentScale^3)
			local modeText = isVolumeChangingEnabled and " (Scaling ON)" or ""
			textLabel.Text = string.format("Volume: %.2f m³%s", displayedVolume, modeText)
		end
	end
end

local function onRenderStep()
	if not (isPlacing and currentGhostModel and currentGhostModel.PrimaryPart) then
		return
	end

	local primaryPart = currentGhostModel.PrimaryPart

	local mouseLocation = UserInputService:GetMouseLocation()
	local unitRay = workspace.CurrentCamera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { currentGhostModel }
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)

	if raycastResult then
		local normal = raycastResult.Normal
		local position = raycastResult.Position
		
		-- Base orientation depends on placement mode
		local orientation = CFrame.new()
		if placementMode == "Module" then
			orientation = currentRotation
		else -- "Item"
			orientation = CFrame.lookAt(Vector3.new(), normal) * currentRotation
		end

		-- Calculate the offset needed to place the model flush on the surface
		local partSize = primaryPart.Size -- Use the CURRENT, scaled size
		local cframe_noPos = primaryPart.CFrame - primaryPart.CFrame.Position
		
		local rightVec = cframe_noPos.RightVector
		local upVec = cframe_noPos.UpVector
		local lookVec = cframe_noPos.LookVector

		local totalOffset = math.abs(rightVec:Dot(normal) * partSize.X / 2)
			+ math.abs(upVec:Dot(normal) * partSize.Y / 2)
			+ math.abs(lookVec:Dot(normal) * partSize.Z / 2)

		-- Apply the final CFrame
		local correctedCFrame = CFrame.new(position + normal * totalOffset) * (orientation - orientation.Position)
		currentGhostModel:SetPrimaryPartCFrame(correctedCFrame)
	end
end

local function onInputBegan(input, gameProcessedEvent)
	if gameProcessedEvent or not isPlacing then return end

	-- Place Item (Left Click)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local modelName = currentGhostModel.Name
		local modelCFrame = currentGhostModel.PrimaryPart.CFrame
		if placementMode == "Module" then
			placeModuleEvent:FireServer(modelName, modelCFrame)
		else
			--// MODIFIED: Send the final size of the primary part to the server
			local finalSize = currentGhostModel.PrimaryPart.Size
			placeItemEvent:FireServer(modelName, modelCFrame, finalSize)
		end
		currentGhostModel:Destroy()
		currentGhostModel = nil
		isPlacing = false
	end

	-- Cancel Placement (Right Click)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		currentGhostModel:Destroy()
		currentGhostModel = nil
		isPlacing = false
	end

	-- Rotate (R key)
	if input.KeyCode == Enum.KeyCode.R then
		-- Rotate around the Y-axis, which is more intuitive for placing items
		currentRotation = currentRotation * CFrame.Angles(0, math.rad(45), 0)
	end
	
	--// NEW: Volume Control Input Logic
	if placementMode == "Item" and baseVolume > 0 then
		-- Toggle Volume Changing Mode (V key)
		if input.KeyCode == Enum.KeyCode.V then
			isVolumeChangingEnabled = not isVolumeChangingEnabled
			updateGhostVolume() -- Update GUI text to show mode change
		end
		
		-- Only allow scaling if the mode is enabled
		if isVolumeChangingEnabled then
			-- Increase Volume (= key)
			if input.KeyCode == Enum.KeyCode.Equals then
				currentScale = currentScale + VOLUME_CHANGE_STEP
				updateGhostVolume()
			end
			
			-- Decrease Volume (- key)
			if input.KeyCode == Enum.KeyCode.Minus then
				currentScale = math.max(MIN_SCALE, currentScale - VOLUME_CHANGE_STEP)
				updateGhostVolume()
			end
		end
	end
end

--// CONNECTIONS
cylinderButton.MouseButton1Click:Connect(function() createGhostModel("Cylinder", "Module") end)
domeButton.MouseButton1Click:Connect(function() createGhostModel("Dome", "Module") end)

for _, button in ipairs(interiorItemsFrame:GetChildren()) do
	if button:IsA("ImageButton") or button:IsA("TextButton") then
		button.MouseButton1Click:Connect(function()
			-- Assumes button.Name matches an item name in InteriorItems and NHVData
			createGhostModel(button.Name, "Item")
		end)
	end
end

UserInputService.InputBegan:Connect(onInputBegan)
RunService.RenderStepped:Connect(onRenderStep)```