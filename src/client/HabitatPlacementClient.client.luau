task.wait(3)

--[[
	LocalScript: HabitatPlacementClient
	Version: Final + STRICT VALIDATION + Deletion/Highlighting
	Author: Gemini
	Location: StarterPlayer > StarterPlayerScripts
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
local deleteItemEvent = ReplicatedStorage:WaitForChild("DeleteInteriorItem")

--// WORKSPACE REFERENCES
local PLACEMENT_ZONES_FOLDER = workspace:WaitForChild("PlacementZones")
local PLACED_ITEMS_FOLDER = workspace:WaitForChild("PlacedItems")

--// UI REFERENCES
local GuiController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("GuiController"))
local mainGui = GuiController.Guis.HUDGui
local mainHolder = mainGui:WaitForChild("Left", 5) and mainGui.Left:WaitForChild("Holder", 5)
local interiorItemsFrame = mainHolder and mainHolder:WaitForChild("ScrollingFrame", 5)

--// UI SETUP
local validationGui = Instance.new("ScreenGui"); validationGui.Name = "ValidationGui"; validationGui.ResetOnSpawn = false
validationGui.ZIndexBehavior = Enum.ZIndexBehavior.Global; validationGui.DisplayOrder = 100; validationGui.Parent = playerGui

local validationLabel = Instance.new("TextLabel"); validationLabel.Name = "ValidationLabel"; validationLabel.Size = UDim2.new(0, 500, 0, 100)
validationLabel.AnchorPoint = Vector2.new(0.5, 1); validationLabel.Position = UDim2.new(0.5, 0, 0.75, 0)
validationLabel.BackgroundTransparency = 0.4; validationLabel.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
validationLabel.TextColor3 = Color3.new(1, 1, 1); validationLabel.Font = Enum.Font.SourceSansBold
validationLabel.TextScaled = true; validationLabel.TextStrokeTransparency = 0; validationLabel.Visible = false
validationLabel.Parent = validationGui

local nhvStatusLabel = Instance.new("TextLabel"); nhvStatusLabel.Name = "NHVStatusLabel"; nhvStatusLabel.Size = UDim2.new(0, 300, 0, 40)
nhvStatusLabel.AnchorPoint = Vector2.new(0.5, 0); nhvStatusLabel.Position = UDim2.new(0.5, 0, 0.02, 0)
nhvStatusLabel.BackgroundTransparency = 0.2; nhvStatusLabel.Font = Enum.Font.SourceSansSemibold
nhvStatusLabel.TextScaled = true; nhvStatusLabel.Visible = false; nhvStatusLabel.Parent = mainGui

--// HIGHLIGHT ASSET
local deletionHighlight = Instance.new("Highlight")
deletionHighlight.FillColor = Color3.fromRGB(255, 0, 0); deletionHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
deletionHighlight.FillTransparency = 0.5; deletionHighlight.OutlineTransparency = 0

--// CLIENT-SIDE STATE
local currentGhostModel, isPlacing, currentItemInfo = nil, false, nil
local currentRotation, isVolumeChangingEnabled = CFrame.new(), false
local originalPartSizes, currentScale = {}, 1
local VOLUME_CHANGE_STEP, MIN_SCALE = 0.05, 0.1
local zoneParts, clientZoneVolumes, viewportModelsToRotate = {}, {}, {}
local isInDeleteMode, currentHoverToDeleteItem = false, nil

for zoneName, _ in pairs(ZoneData.Properties) do
	clientZoneVolumes[zoneName] = 0
	local foundZonePart = PLACEMENT_ZONES_FOLDER:WaitForChild(zoneName, 10)
	if foundZonePart then zoneParts[zoneName] = foundZonePart else warn("[CRITICAL] Missing Zone Part: " .. zoneName) end
end

--============================================================================--
--// INITIALIZATION & UI
--============================================================================--
local function initializeZoneGUIs()
	for zoneName, zonePart in pairs(zoneParts) do
		local zoneInfo = ZoneData.Get(zoneName)
		zonePart.Transparency = 1
		local billboardGui = Instance.new("BillboardGui"); billboardGui.Name = "ZoneNameDisplay"; billboardGui.Adornee = zonePart
		billboardGui.Size = UDim2.new(10, 0, 2, 0); billboardGui.StudsOffset = Vector3.new(0, 2, 0)
		billboardGui.AlwaysOnTop = true; billboardGui.Enabled = false
		local textLabel = Instance.new("TextLabel"); textLabel.Size = UDim2.new(1, 0, 1, 0); textLabel.BackgroundTransparency = 1
		textLabel.Text = zoneInfo.FriendlyName; textLabel.Font = Enum.Font.SourceSansBold; textLabel.TextColor3 = Color3.new(1, 1, 1)
		textLabel.TextScaled = true; textLabel.TextStrokeTransparency = 0.5
		textLabel.Parent = billboardGui; billboardGui.Parent = zonePart
	end
end

local function populateItemViewports()
	if not interiorItemsFrame then return end
	for _, button in ipairs(interiorItemsFrame:GetChildren()) do
		if button:IsA("GuiButton") then
			local template = interiorItems:FindFirstChild(button.Name)
			if template and template.PrimaryPart then
				local vp = Instance.new("ViewportFrame"); vp.Size = UDim2.new(1, 0, 1, 0)
				vp.BackgroundColor3 = Color3.fromRGB(40, 40, 40); vp.BackgroundTransparency = 0.5; vp.Active = false; vp.Parent = button
				local clone = template:Clone(); clone.Parent = vp; table.insert(viewportModelsToRotate, clone)
				local cam = Instance.new("Camera"); cam.Parent = vp; vp.CurrentCamera = cam
				local cf, size = clone:GetBoundingBox(); local maxDim = math.max(size.X, size.Y, size.Z); local dist = maxDim * 1.5
				cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist, dist * 0.7, dist), cf.Position)
				local light = Instance.new("PointLight"); light.Brightness = 2; light.Parent = cam
			end
		end
	end
end

local function showValidationMessage(message, isSuccess)
	validationLabel.Text = message
	validationLabel.TextColor3 = isSuccess and Color3.fromRGB(85, 255, 127) or Color3.fromRGB(255, 85, 85)
	validationLabel.Visible = true
end

local function setZoneVisibility(visible)
	for _, zonePart in pairs(zoneParts) do
		TweenService:Create(zonePart, TweenInfo.new(0.3), { Transparency = visible and 0.7 or 1 }):Play()
		local nameGui = zonePart:FindFirstChild("ZoneNameDisplay"); if nameGui then nameGui.Enabled = visible end
	end
end

local function updateStatusLabel()
	if isPlacing and currentItemInfo then
		nhvStatusLabel.Text = "(Placing Item) NHV Tracking On"
		nhvStatusLabel.BackgroundColor3 = Color3.fromRGB(255, 126, 0); nhvStatusLabel.Visible = true
	elseif isInDeleteMode then
		nhvStatusLabel.Text = "Delete Mode (Click to delete, X to exit)"
		nhvStatusLabel.BackgroundColor3 = Color3.fromRGB(200, 0, 0); nhvStatusLabel.Visible = true
	else nhvStatusLabel.Visible = false end
end

local function hideValidationMessage() validationLabel.Visible = false end

local function cancelAllModes()
	if currentGhostModel then currentGhostModel:Destroy() end
	currentGhostModel, isPlacing, currentItemInfo = nil, false, nil
	isInDeleteMode, deletionHighlight.Adornee, currentHoverToDeleteItem = false, nil, nil
	setZoneVisibility(false); hideValidationMessage(); updateStatusLabel()
end

--============================================================================--
--// PLACEMENT LOGIC
--============================================================================--
local function updateGhostVolume()
	if not (currentGhostModel and currentItemInfo) then return end
	for part, originalSize in pairs(originalPartSizes) do
		if part and part.Parent then part.Size = originalSize * currentScale end
	end
	if currentGhostModel.PrimaryPart then
		local textLabel = currentGhostModel.PrimaryPart:FindFirstChild("VolumeDisplay", true):FindFirstChild("VolumeLabel")
		if textLabel then
			local friendlyName = currentItemInfo.FriendlyName or currentGhostModel.Name
			local displayedVolume = currentItemInfo.BaseVolume * (currentScale ^ 3)
			local modeText = isVolumeChangingEnabled and " <br/><font color='#ffff00'>[Adjusting Volume]</font>" or ""
			textLabel.Text = string.format("<b>%s</b>%s\nVolume: %.2f m³", friendlyName, modeText, displayedVolume)
		end
	end
end

local function createGhostModel(name, isModule)
	cancelAllModes()
	local template = isModule and habitatModules:WaitForChild(name, 1) or interiorItems:WaitForChild(name, 1)
	if not template then return end
	if not isModule then
		currentItemInfo = ItemData.Get(name)
		if not currentItemInfo then return end
	end
	currentGhostModel = template:Clone()
	isPlacing = true; currentRotation = CFrame.new(); currentScale = 1; originalPartSizes = {}
	for _, part in ipairs(currentGhostModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 0.5; part.CanCollide = false; part.Anchored = true
			if not isModule then originalPartSizes[part] = part.Size end
		end
	end
	if currentItemInfo and currentGhostModel.PrimaryPart then
		local gui = Instance.new("BillboardGui"); gui.Name = "VolumeDisplay"; gui.Adornee = currentGhostModel.PrimaryPart
		gui.Size = UDim2.new(8, 0, 3, 0); gui.StudsOffset = Vector3.new(0, 3.5, 0); gui.AlwaysOnTop = true
		local label = Instance.new("TextLabel"); label.Name = "VolumeLabel"; label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1; label.TextColor3 = Color3.new(1, 1, 1); label.TextScaled = true
		label.Font = Enum.Font.SourceSansBold; label.TextStrokeTransparency = 0.5; label.RichText = true
		label.Parent = gui; gui.Parent = currentGhostModel.PrimaryPart
	end
	currentGhostModel.Parent = workspace
	if not isModule then setZoneVisibility(true); updateStatusLabel(); updateGhostVolume() end
end

--============================================================================--
--// MAIN RENDER LOOP & INPUT
--============================================================================--
local function onRenderStep(deltaTime)
	for _, model in ipairs(viewportModelsToRotate) do
		if model.PrimaryPart then model:SetPrimaryPartCFrame(model.PrimaryPart.CFrame * CFrame.Angles(0, deltaTime * 0.5, 0)) end
	end

	local unitRay = workspace.CurrentCamera:ViewportPointToRay(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)

	if isInDeleteMode then
		local rayParams = RaycastParams.new(); rayParams.FilterDescendantsInstances = {PLACED_ITEMS_FOLDER}; rayParams.FilterType = Enum.RaycastFilterType.Whitelist
		local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, rayParams)
		local foundModel = result and result.Instance:FindFirstAncestorOfClass("Model")
		if foundModel and foundModel.Parent == PLACED_ITEMS_FOLDER then
			if currentHoverToDeleteItem ~= foundModel then
				currentHoverToDeleteItem = foundModel; deletionHighlight.Adornee = foundModel; deletionHighlight.Parent = foundModel
			end
		else
			currentHoverToDeleteItem = nil; deletionHighlight.Adornee = nil; deletionHighlight.Parent = nil
		end
		return
	end

	if isPlacing and currentGhostModel and currentGhostModel.PrimaryPart then
		local rayParams = RaycastParams.new(); rayParams.FilterDescendantsInstances = {currentGhostModel, localPlayer.Character}; rayParams.FilterType = Enum.RaycastFilterType.Blacklist
		local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, rayParams)
		if not result then
			if currentGhostModel.Parent then currentGhostModel.Parent = nil end
			showValidationMessage("❌ Point at a surface.", false); return
		end
		if not currentGhostModel.Parent then currentGhostModel.Parent = workspace end

		local pp = currentGhostModel.PrimaryPart
		local cf = CFrame.lookAt(result.Position, result.Position + result.Normal) * currentRotation
		local offset = result.Normal * (pp.Size.Y / 2)
		currentGhostModel:SetPrimaryPartCFrame(cf * CFrame.new(offset))
		
		if currentItemInfo then
			local parts = workspace:GetPartsInPart(pp); local zone = nil
			for _, p in ipairs(parts) do if p.Parent == PLACEMENT_ZONES_FOLDER then zone = p; break end end
			
			if not zone then showValidationMessage("❌ Place inside a zone.", false)
			else
				local zName = zone.Name; local zInfo = ZoneData.Get(zName)
				if zInfo.Category ~= currentItemInfo.Category then
					showValidationMessage("❌ Wrong Zone. Needs: " .. currentItemInfo.Category, false)
				else
					-- CRITICAL FIX: Add a check for the scale
					if math.abs(currentScale - 1) > 0.001 then
						showValidationMessage("❌ Item must be at standard Volume to place.", false)
					else
						-- Only check volume if scale is correct
						local standardVolume = currentItemInfo.BaseVolume
						if clientZoneVolumes[zName] + standardVolume > zInfo.MaxVolume + 0.001 then
							showValidationMessage(string.format("❌ Zone Full! (%.2f + %.2f > %.2f)", clientZoneVolumes[zName], standardVolume, zInfo.MaxVolume), false)
						else
							showValidationMessage("✅ NASA Compliant!", true)
						end
					end
				end
			end
		end
	end
end

local function onInputBegan(input, gameProcessedEvent)
	if gameProcessedEvent then return end

	if input.KeyCode == Enum.KeyCode.X then
		if isPlacing or isInDeleteMode then cancelAllModes() else isInDeleteMode = true; updateStatusLabel() end
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if isInDeleteMode and currentHoverToDeleteItem then
			local item = currentHoverToDeleteItem
			local zName = item:GetAttribute("PlacedZone"); local origName = item:GetAttribute("OriginalName")
			if zName and origName and item.PrimaryPart then
				local itemInfo = ItemData.Get(origName); local template = interiorItems:FindFirstChild(origName)
				if itemInfo and template and template.PrimaryPart then
					local scaleVec = item.PrimaryPart.Size / template.PrimaryPart.Size
					local volToRemove = itemInfo.BaseVolume * scaleVec.X * scaleVec.Y * scaleVec.Z
					clientZoneVolumes[zName] = math.max(0, clientZoneVolumes[zName] - volToRemove)
				end
			end
			deleteItemEvent:FireServer(item)
			currentHoverToDeleteItem = nil; deletionHighlight.Parent = nil
			return
		end

		if isPlacing then
			if currentItemInfo then
				-- CRITICAL FIX: Run the full validation logic again on click
				if math.abs(currentScale - 1) > 0.001 then return end -- Fail if not standard size
				
				local pp = currentGhostModel.PrimaryPart; local parts = workspace:GetPartsInPart(pp); local zone = nil
				for _, p in ipairs(parts) do if p.Parent == PLACEMENT_ZONES_FOLDER then zone = p; break end end
				if not zone then return end
				
				local zName = zone.Name; local zInfo = ZoneData.Get(zName)
				if zInfo.Category ~= currentItemInfo.Category then return end
				
				local standardVolume = currentItemInfo.BaseVolume
				if clientZoneVolumes[zName] + standardVolume <= zInfo.MaxVolume + 0.001 then
					clientZoneVolumes[zName] += standardVolume
					-- Send original size, not scaled size
					placeItemEvent:FireServer(currentGhostModel.Name, pp.CFrame, originalPartSizes[pp], zName)
					createGhostModel(currentGhostModel.Name, false)
				end
				return 
			else
				placeModuleEvent:FireServer(currentGhostModel.Name, currentGhostModel.PrimaryPart.CFrame); cancelAllModes()
			end
		end
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then cancelAllModes() end

	if isPlacing and currentItemInfo then
		if input.KeyCode == Enum.KeyCode.R then currentRotation *= CFrame.Angles(0, math.rad(45), 0) end
		if currentItemInfo.BaseVolume > 0 then
			if input.KeyCode == Enum.KeyCode.V then isVolumeChangingEnabled = not isVolumeChangingEnabled; updateGhostVolume() end
			if isVolumeChangingEnabled then
				if input.KeyCode == Enum.KeyCode.Equals then currentScale += VOLUME_CHANGE_STEP; updateGhostVolume() end
				if input.KeyCode == Enum.KeyCode.Minus then currentScale = math.max(MIN_SCALE, currentScale - VOLUME_CHANGE_STEP); updateGhostVolume() end
			end
		end
	end
end

--============================================================================--
--// SCRIPT EXECUTION START & CONNECTIONS
--============================================================================--
initializeZoneGUIs()
populateItemViewports()

if not mainHolder then error("Could not find Main UI Holder.") end

local cylBtn = mainHolder:FindFirstChild("Cylinder"); if cylBtn then cylBtn.MouseButton1Click:Connect(function() createGhostModel("Cylinder", true) end) end
local domeBtn = mainHolder:FindFirstChild("Dome"); if domeBtn then domeBtn.MouseButton1Click:Connect(function() createGhostModel("Dome", true) end) end
if interiorItemsFrame then
	for _, btn in ipairs(interiorItemsFrame:GetChildren()) do
		if btn:IsA("GuiButton") then
			btn.MouseButton1Click:Connect(function() createGhostModel(btn.Name, false) end)
		end
	end
end

UserInputService.InputBegan:Connect(onInputBegan)
RunService.RenderStepped:Connect(onRenderStep)
print("HabitatPlacementClient Loaded.")