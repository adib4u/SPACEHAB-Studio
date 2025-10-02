--[[
	LocalScript: HabitatPlacementClient
	Final version with precise, vector-based surface snapping.
]]

--// SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

--// Dependencies
local GuiController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("GuiController"))

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

--// FUNCTIONS

local function createGhostModel(name, mode)
	if currentGhostModel then
		currentGhostModel:Destroy()
	end

	placementMode = mode
	currentRotation = CFrame.new() -- Reset rotation for the new object

	local templateModel = (mode == "Module") and habitatModules:FindFirstChild(name)
		or interiorItems:FindFirstChild(name)

	if templateModel then
		currentGhostModel = templateModel:Clone()

		for _, part in ipairs(currentGhostModel:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 0.7
				part.CanCollide = false
				part.Anchored = true
			end
		end

		currentGhostModel.Parent = workspace
		isPlacing = true
	end
end

--// MODIFIED: This is the final, precise snapping logic.
local function onRenderStep()
	if not (isPlacing and currentGhostModel) then
		return
	end

	-- Ensure the model has a primary part to work with
	local primaryPart = currentGhostModel.PrimaryPart
	if not primaryPart then
		return
	end

	-- Perform the raycast to find the surface
	local mouseLocation = UserInputService:GetMouseLocation()
	local unitRay = workspace.CurrentCamera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { currentGhostModel }
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)

	if raycastResult then
		local initialCFrame

		-- Determine the base orientation
		if placementMode == "Module" then
			initialCFrame = CFrame.new(raycastResult.Position) * currentRotation
		else -- "Item"
			local surfaceCFrame = CFrame.lookAt(raycastResult.Position, raycastResult.Position + raycastResult.Normal)
			initialCFrame = surfaceCFrame * currentRotation
		end

		--// NEW AND IMPROVED SNAPPING LOGIC

		-- 1. Get the properties we need for the calculation
		local normal = raycastResult.Normal -- The direction the surface is facing
		local partSize = primaryPart.Size -- The local dimensions of the primary part

		-- We need to find the extent of the primary part's rotated bounding box along the surface normal.
		-- We do this by projecting the part's local axes (multiplied by half its size) onto the normal vector.

		-- 2. Get the part's rotational axes in world space
		local rightVec = initialCFrame.RightVector
		local upVec = initialCFrame.UpVector
		local lookVec = initialCFrame.LookVector

		-- 3. Calculate the total offset by summing the absolute projections of each axis extent.
		local totalOffset = math.abs(rightVec:Dot(normal) * partSize.X / 2)
			+ math.abs(upVec:Dot(normal) * partSize.Y / 2)
			+ math.abs(lookVec:Dot(normal) * partSize.Z / 2)

		-- 4. Create the final, corrected CFrame by pushing the initial CFrame out from the surface by the calculated offset.
		local correctedCFrame = initialCFrame * CFrame.new(0, 0, -totalOffset)

		-- For items, the Z axis is what points "into" the surface, so we offset along it.
		-- For modules on a flat floor, this logic simplifies correctly as well.
		if placementMode == "Module" then
			correctedCFrame = initialCFrame * CFrame.new(normal * totalOffset)
		end

		-- 5. Apply the corrected CFrame to the ghost model.
		currentGhostModel:SetPrimaryPartCFrame(correctedCFrame)
	end
end

local function onInputBegan(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end

	if isPlacing and input.UserInputType == Enum.UserInputType.MouseButton1 then
		local modelName = currentGhostModel.Name
		local modelCFrame = currentGhostModel.PrimaryPart.CFrame
		if placementMode == "Module" then
			placeModuleEvent:FireServer(modelName, modelCFrame)
		else
			placeItemEvent:FireServer(modelName, modelCFrame)
		end
		currentGhostModel:Destroy()
		currentGhostModel = nil
		isPlacing = false
	end

	if isPlacing and input.UserInputType == Enum.UserInputType.MouseButton2 then
		currentGhostModel:Destroy()
		currentGhostModel = nil
		isPlacing = false
	end

	if isPlacing and input.KeyCode == Enum.KeyCode.R then
		currentRotation = currentRotation * CFrame.Angles(0, 0, math.rad(90))
	end
end

--// CONNECTIONS
cylinderButton.MouseButton1Click:Connect(function()
	createGhostModel("Cylinder", "Module")
end)
domeButton.MouseButton1Click:Connect(function()
	createGhostModel("Dome", "Module")
end)

for _, button in ipairs(interiorItemsFrame:GetChildren()) do
	if button:IsA("ImageButton") or button:IsA("TextButton") then
		local itemName = button.Name
		button.MouseButton1Click:Connect(function()
			createGhostModel(itemName, "Item")
		end)
	end
end

UserInputService.InputBegan:Connect(onInputBegan)
RunService.RenderStepped:Connect(onRenderStep)
