local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local GuiController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("GuiController"))
local mainGui = GuiController.Guis.HUDGui
local mainHolder = mainGui:WaitForChild("Left", 5) and mainGui.Left:WaitForChild("Holder", 5)
local bottomFrame = mainGui:WaitForChild("Bottom")
local DeckPlaceButton = mainHolder:WaitForChild("DeckPlace")
local Deck1Button = mainHolder:WaitForChild("Deck1")
local Deck2Button = mainHolder:WaitForChild("Deck2")
local Deck3Button = mainHolder:WaitForChild("Deck3")
local gotoAirlock = bottomFrame:WaitForChild("Airlock")
local gotoDeck1 = bottomFrame:WaitForChild("Deck 1")
local gotoDeck2 = bottomFrame:WaitForChild("Deck 2")
local gotoDeck3 = bottomFrame:WaitForChild("Deck 3")
Deck1Button.Visible = false
Deck2Button.Visible = false
Deck3Button.Visible = false

local CrewGui = GuiController.Guis.CrewGui
local CrewSize4Button = CrewGui:WaitForChild("Frame"):WaitForChild("Crew4")
local CrewSize6Button = CrewGui:WaitForChild("Frame"):WaitForChild("Crew6")

local DecksFolder = ReplicatedStorage:WaitForChild("Decks")

local CurrentCam = Workspace.CurrentCamera
local Camera1 = Workspace:WaitForChild("Cameras"):WaitForChild("Camera1")

local RedColor = Color3.new(170, 0, 0)
local GreenColor = Color3.new(0, 0.611764, 0.235294)

local debounce = false
DeckPlaceButton.MouseButton1Click:Connect(function()
    if debounce then
        debounce = false
        DeckPlaceButton.BackgroundColor3 = RedColor
        DeckPlaceButton.Text = "Deck Placement Mode: OFF"

        Deck1Button.Visible = false
        Deck2Button.Visible = false
        Deck3Button.Visible = false
        CurrentCam.CameraType = Enum.CameraType.Custom
    else
        debounce = true
        DeckPlaceButton.BackgroundColor3 = GreenColor
        DeckPlaceButton.Text = "Deck Placement Mode: ON"

        Deck1Button.Visible = true
        Deck2Button.Visible = true
        Deck3Button.Visible = true
        CurrentCam.CameraType = Enum.CameraType.Scriptable
	    CurrentCam.CFrame = Camera1.CFrame
    end
end)

Deck1Button.MouseButton1Click:Connect(function()
    local Deck1 = DecksFolder:WaitForChild("Deck1")
    Deck1.Parent = Workspace
end)
Deck2Button.MouseButton1Click:Connect(function()
    local Deck2 = DecksFolder:WaitForChild("Deck2")
    Deck2.Parent = Workspace
end)
Deck3Button.MouseButton1Click:Connect(function()
    local Deck3 = DecksFolder:WaitForChild("Deck3")
    Deck3.Parent = Workspace
end)

gotoAirlock.MouseButton1Click:Connect(function()
    local character = Player.Character or Player.CharacterAdded:Wait()
    character.PrimaryPart.CFrame = Workspace:WaitForChild("Airlock"):WaitForChild("GOTO").CFrame
end)
gotoDeck1.MouseButton1Click:Connect(function()
    local character = Player.Character or Player.CharacterAdded:Wait()
    character.PrimaryPart.CFrame = Workspace:WaitForChild("Deck1"):WaitForChild("GOTO").CFrame
end)
gotoDeck2.MouseButton1Click:Connect(function()
    local character = Player.Character or Player.CharacterAdded:Wait()
    character.PrimaryPart.CFrame = Workspace:WaitForChild("Deck2"):WaitForChild("GOTO").CFrame
end)
gotoDeck3.MouseButton1Click:Connect(function()
    local character = Player.Character or Player.CharacterAdded:Wait()
    character.PrimaryPart.CFrame = Workspace:WaitForChild("Deck3"):WaitForChild("GOTO").CFrame
end)

CrewSize4Button.MouseButton1Click:Connect(function()
    CrewGui.Enabled = false
end)
CrewSize6Button.MouseButton1Click:Connect(function()
    CrewGui.Enabled = false
end)
