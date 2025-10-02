local GuiController = require(script.Parent.Controllers.GuiController)

local Gui = GuiController.Guis.HUDGui
local Frame = Gui.Left
local Holder = Frame.Holder
local OpenButton: TextButton = Frame.Open

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