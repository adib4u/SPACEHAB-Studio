--[[
	Script: HabitatPlacementServer
	Handles receiving placement requests and now also resizes items
	based on data from the client and attaches a volume display.
]]

--// SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// MODULES
local NHVData = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("NHVData"))

--// ASSETS
local habitatModules = ReplicatedStorage:WaitForChild("HabitatModules")
local interiorItems = ReplicatedStorage:WaitForChild("InteriorItems")
local placeModuleEvent = ReplicatedStorage:WaitForChild("PlaceHabitatModule")
local placeItemEvent = ReplicatedStorage:WaitForChild("PlaceInteriorItem")

--// This function is unchanged as modules do not have the volume feature.
local function onPlaceModule(player, modelName, cframe)
	local templateModel = habitatModules:FindFirstChild(modelName)

	if templateModel then
		print(player.Name .. " is placing a " .. modelName)
		local newModule = templateModel:Clone()

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

--// MODIFIED: Accepts a 'finalSize' Vector3 for resizing the placed item.
local function onPlaceItem(player, modelName, cframe, finalSize)
	local templateModel = interiorItems:FindFirstChild(modelName)

	if not templateModel then
		warn(player.Name .. " tried to place an invalid item: " .. tostring(modelName))
		return
	end

	print(player.Name .. " is placing a " .. modelName)
	local newItem = templateModel:Clone()

	local primaryPart = newItem.PrimaryPart
	if not primaryPart then
		warn("Placed item "..modelName.." has no PrimaryPart!")
		newItem:Destroy()
		return
	end

	local originalSize = primaryPart.Size
	local baseVolume = NHVData.GetVolume(modelName)

	-- Apply scaling if a valid finalSize is provided by the client
	if finalSize and typeof(finalSize) == "Vector3" and originalSize.Magnitude > 0 then
		local scale = finalSize / originalSize
		for _, part in ipairs(newItem:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Size = part.Size * scale
				part.Transparency = 0
				part.CanCollide = true
				part.Anchored = true
			end
		end
	else -- Fallback for items placed without scaling
		for _, part in ipairs(newItem:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 0
				part.CanCollide = true
				part.Anchored = true
			end
		end
	end

	newItem:SetPrimaryPartCFrame(cframe)
	newItem.Parent = workspace

	-- Add Billboard GUI for volume display if data exists for this item
	if baseVolume then
		local billboardGui = Instance.new("BillboardGui")
		billboardGui.Name = "VolumeDisplay"
		billboardGui.Adornee = primaryPart
		billboardGui.Size = UDim2.new(6, 0, 1.5, 0)
		billboardGui.StudsOffset = Vector3.new(0, 3, 0)
		billboardGui.AlwaysOnTop = true

		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.TextColor3 = Color3.new(1, 1, 1)
		textLabel.TextScaled = true
		textLabel.Font = Enum.Font.SourceSansBold
		textLabel.TextStrokeTransparency = 0

		-- Calculate the final displayed volume based on the new size
		local finalVolume = baseVolume
		if finalSize and originalSize.Magnitude > 0 then
			local scaleVector = finalSize / originalSize
			finalVolume = baseVolume * scaleVector.X * scaleVector.Y * scaleVector.Z
		end
		textLabel.Text = string.format("Volume: %.2f m³", finalVolume)

		textLabel.Parent = billboardGui
		billboardGui.Parent = primaryPart
	end
end


--// CONNECTIONS
placeModuleEvent.OnServerEvent:Connect(onPlaceModule)
placeItemEvent.OnServerEvent:Connect(onPlaceItem)