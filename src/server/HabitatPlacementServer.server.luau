--[[
	Script: HabitatPlacementServer
	Handles receiving placement requests with full CFrame data for all objects.
]]

--// SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// ASSETS
local habitatModules = ReplicatedStorage:WaitForChild("HabitatModules")
local interiorItems = ReplicatedStorage:WaitForChild("InteriorItems")
local placeModuleEvent = ReplicatedStorage:WaitForChild("PlaceHabitatModule")
local placeItemEvent = ReplicatedStorage:WaitForChild("PlaceInteriorItem")

--// MODIFIED: Now accepts a 'cframe' instead of 'position'
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

		--// MODIFIED: Uses the full cframe provided by the client
		newModule:SetPrimaryPartCFrame(cframe) 
		newModule.Parent = workspace
	else
		warn(player.Name .. " tried to place an invalid module: " .. tostring(modelName))
	end
end

-- This function is already correct, no changes needed here.
local function onPlaceItem(player, modelName, cframe)
	local templateModel = interiorItems:FindFirstChild(modelName)

	if templateModel then
		print(player.Name .. " is placing a " .. modelName)
		local newItem = templateModel:Clone()

		for _, part in ipairs(newItem:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 0
				part.CanCollide = true
				part.Anchored = true
			end
		end

		newItem:SetPrimaryPartCFrame(cframe) 
		newItem.Parent = workspace
	else
		warn(player.Name .. " tried to place an invalid item: " .. tostring(modelName))
	end
end


--// CONNECTIONS
placeModuleEvent.OnServerEvent:Connect(onPlaceModule)
placeItemEvent.OnServerEvent:Connect(onPlaceItem)