local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiController = require(script.Parent.Controllers.GuiController)

local Gui = GuiController.Guis.HUDGui
local Frame = Gui.Left
local Holder = Frame.Holder
local ScrollingFrame = Holder:WaitForChild("ScrollingFrame")
local OpenButton: TextButton = Frame.Open
local itemTemplate = ScrollingFrame:WaitForChild("Template")
itemTemplate.Visible = false

local InteriorItems = ReplicatedStorage:WaitForChild("InteriorItems")

local function PopulateItemButtons()
	for _, item: Model in pairs(InteriorItems:GetChildren()) do
		if item:IsA("Model") then
			local clone = itemTemplate:Clone()
			clone:WaitForChild("Title").Text = item.Name
			clone.Name = item.Name
			clone.Parent = ScrollingFrame
			clone.Visible = true
		end
	end
end

OpenButton.MouseButton1Click:Connect(function()
	if Holder.Visible == true then
		Frame.Position = UDim2.new(-0.21, 0, 0.1, 0)
		OpenButton.Title.Text = ">"
		Holder.Visible = false
	else
		Frame.Position = UDim2.new(0, 0, 0.1, 0)
		OpenButton.Title.Text = "<"
		Holder.Visible = true
	end
end)

PopulateItemButtons()