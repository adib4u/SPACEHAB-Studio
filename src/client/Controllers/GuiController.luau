local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local SoundsConfig = require(ReplicatedStorage.Configs.Sounds)
--local StateController = require(script.Parent.StateController)

local BUTTON_TWEEN_DURATION = 0.1
local BUTTON_SCALE_FACTOR = 0.035

local BlurEffect = Instance.new("BlurEffect", Lighting)
BlurEffect.Size = 0

local ALWAYS_ENABLED_GUIS = {
	"HUDGui",
}

local Local = {}
local Shared = {}

Shared.BillboardGuis = {
	--StageArrow = PlayerGui:WaitForChild("StageArrow")
}

Shared.Guis = {
	HUDGui = PlayerGui:WaitForChild("HUDGui"),
}

local SetupGuiButtons = {} -- to exclude them from basic button effects (as they already have their own defined effect in SetupGui function)

function Shared.OnStart()
	--StateController.UpdateState.Event:Connect(function(action: StateController.UpdateStateAction)
	--	if action.type == "UpdateSetting" and action.setting == "Menu Blur" then
	--		Shared.ToggleBlurEffect(action.value)
	--	end
	--end)
	
	-- Animate all buttons
	for _, button in pairs(PlayerGui:GetDescendants()) do
		Shared.AnimateButton(button)
		Shared.BasicButtonEffect(button)
		Shared.ShowGlobalXP(button)
	end
	PlayerGui.DescendantAdded:Connect(function(descendant: Instance)
		Shared.AnimateButton(descendant)
		Shared.BasicButtonEffect(descendant)
		Shared.ShowGlobalXP(descendant)
	end)
end

function Shared.BasicButtonEffect(button)
	if not button:IsA("TextButton") and not button:IsA("ImageButton") then return end
	
	button.MouseButton1Down:Connect(function()
		--if StateController.GetState().settings["Sound Effects"] == true and not table.find(SetupGuiButtons, button) then
		--	SoundsConfig.PlaySound("Click")
		--end
	end)
end

function Shared.ShowGlobalXP(button: TextButton)
	if not button:IsA("TextButton") and not button:IsA("ImageButton") then return end
	if button.Name ~= "Level" then return end
	
	local Title = button:FindFirstChild("Title")
	local Title2 = button:FindFirstChild("Title2")
	if not Title or not Title2 then return end
	
	button.MouseEnter:Connect(function()
		Title.Visible = false
		Title2.Visible = true
	end)
	button.MouseLeave:Connect(function()
		Title.Visible = true
		Title2.Visible = false
	end)
end

function Shared.AnimateButton(button)
	if not button:IsA("TextButton") and not button:IsA("ImageButton") then return end
	if button.Name == "Level" then return end
	
	local buttonSizeOld = button.Size
	local UIScale = button:FindFirstChild("UIScale") or Instance.new("UIScale", button)
	local Default = UIScale.Scale

	button.MouseEnter:Connect(function()
		--if StateController.State.settings.SFX == true then
		--	InstantAudio.playSound("ButtonHover")
		--end

		TweenService:Create(
			UIScale,
			TweenInfo.new(BUTTON_TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = Default + BUTTON_SCALE_FACTOR }
		):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(
			UIScale,
			TweenInfo.new(BUTTON_TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = Default }
		):Play()
	end)

	button.MouseButton1Down:Connect(function()
		--if StateController.GetState().settings["Sound Effects"] == true then
		--	SoundsConfig.PlaySound("Click")
		--end

		TweenService:Create(
			UIScale,
			TweenInfo.new(BUTTON_TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = Default - BUTTON_SCALE_FACTOR }
		):Play()
	end)

	button.MouseButton1Up:Connect(function()
		TweenService:Create(
			UIScale,
			TweenInfo.new(BUTTON_TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = Default + BUTTON_SCALE_FACTOR }
		):Play()
	end)
end

function Shared.HandleProgressBar(progressBar: CanvasGroup, progressAmount: number, progressText: string?)
	local progressFrame: Frame = progressBar:FindFirstChild("Progress") or progressBar:FindFirstChildOfClass("Frame")
	if progressFrame and progressFrame:IsA("Frame") then
		local percent = math.clamp(progressAmount, 0, 1)
		local newSize = UDim2.fromScale(percent, 1)
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
		local tweenGoal = {
			Size = newSize
		}
		local tween = TweenService:Create(progressFrame, tweenInfo, tweenGoal)
		tween:Play()
	end
	
	local textLabel = progressBar:FindFirstChild("Amount") or progressBar:FindFirstChildOfClass("TextLabel")
	if progressText and textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = progressText
	end
end

function Shared.ToggleBlurEffect(isGuiActive: boolean)
	--local isSettingEnabled = SettingsConfig.GetSettingValue(StateController.GetState(), "Menu Blur")
	--if isGuiActive and not isSettingEnabled then return end

	local targetSize = if isGuiActive then 14 else 0
	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
	local tweenGoal = {}
	tweenGoal.Size = targetSize

	local tween = TweenService:Create(BlurEffect, tweenInfo, tweenGoal)
	tween:Play()
end

function Shared.SetupGui(gui: ScreenGui, openButton: TextButton?, exitButton: TextButton?)
	exitButton = if exitButton then exitButton else gui:FindFirstChild("Exit", true) :: TextButton
	
	if openButton and (openButton:IsA("TextButton") or openButton:IsA("ImageButton")) then
		if not table.find(SetupGuiButtons, openButton) then
			table.insert(SetupGuiButtons, openButton)
		end
		Shared.AnimateButton(openButton)
		
		openButton.MouseButton1Click:Connect(function()
			SoundsConfig.PlaySound("Menu-Click")
			Shared.ToggleGui(gui)
		end)
	elseif openButton and openButton:IsA("ClickDetector") then
		--Shared.AnimateButton(openButton)
		openButton.MouseClick:Connect(function(player)
			if player == Players.LocalPlayer then
				SoundsConfig.PlaySound("Menu-Click")
				Shared.ToggleGui(gui)
			end
		end)
	else
		print('No open button found for gui [' .. gui.Name .. ']')
	end

	if exitButton then
		if not table.find(SetupGuiButtons, exitButton) then
			table.insert(SetupGuiButtons, exitButton)
		end
		exitButton.MouseButton1Click:Connect(function()
			SoundsConfig.PlaySound("Menu-Click")
			Shared.ToggleGui(gui)
		end)
	end
end

function Shared.ToggleGui(gui: ScreenGui)
	--Shared.ToggleBlurEffect(not gui.Enabled)
	if gui.Enabled then
		Local.AnimateFrame(gui.Frame, false)
		return
	end
	
	Local.AnimateFrame(gui.Frame, true)

	gui.Enabled = true
	Local.HideGuis(gui)
end

function Local.HideGuis(gui: ScreenGui)
	for _, screenGui in PlayerGui:GetChildren() do
		local isSameGui = screenGui == gui
		local isAlwaysEnabled = table.find(ALWAYS_ENABLED_GUIS, screenGui.Name)
		local isOurGui = Local.IsOurGui(screenGui)
		if isSameGui or isAlwaysEnabled or not isOurGui then
			continue
		end

		if screenGui:IsA("ScreenGui") then
			screenGui.Enabled = false
		end
	end
end

function Local.AnimateFrame(frame: Frame, isOpening: boolean)
	local uiScale = Instance.new("UIScale", frame)
	uiScale.Scale = if isOpening then 0.02 else 1

	local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local tweenGoal = {}
	tweenGoal.Scale = if isOpening then 1 else 0.02

	local tween = TweenService:Create(uiScale, tweenInfo, tweenGoal)
	tween:Play()

	tween.Completed:Connect(function()
		uiScale:Destroy()
		if not isOpening then
			local gui = frame:FindFirstAncestorOfClass("ScreenGui")
			if gui then
				gui.Enabled = false
			end
		end
	end)
end

function Local.IsOurGui(gui: ScreenGui)
	for _, starterGui in StarterGui:GetChildren() do
		if starterGui.Name == gui.Name then
			return true
		end
	end
	return false
end

return Shared