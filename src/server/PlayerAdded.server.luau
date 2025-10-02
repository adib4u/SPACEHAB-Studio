local Players = game:GetService("Players")

local spaceSuit = game.ReplicatedStorage:WaitForChild("Accessory (Astronaut suit)")

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		spaceSuit:Clone().Parent = character
		
		for _, accessory in pairs(character:GetChildren()) do
			if accessory:IsA("Accessory") and string.find(accessory.Name, "Hair") then
				accessory:Destroy()
			end
		end
	end)
end)