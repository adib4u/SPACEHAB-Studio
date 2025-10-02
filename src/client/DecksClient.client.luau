local Workspace = game:GetService("Workspace")
local GuiController = require(script.Parent:WaitForChild("Controllers"):WaitForChild("GuiController"))
local mainGui = GuiController.Guis.HUDGui
local mainHolder = mainGui:WaitForChild("Left", 5) and mainGui.Left:WaitForChild("Holder", 5)
local DeckPlaceButton = mainHolder:WaitForChild("DeckPlace")

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

        CurrentCam.CameraType = Enum.CameraType.Custom
    else
        debounce = true
        DeckPlaceButton.BackgroundColor3 = GreenColor
        DeckPlaceButton.Text = "Deck Placement Mode: ON"

        CurrentCam.CameraType = Enum.CameraType.Scriptable
	    CurrentCam.CFrame = Camera1.CFrame
    end
end)