local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Local = {}
local Shared = {}

function Shared.GetSound(sound: SoundName): Sound
	return ReplicatedStorage.Sounds[sound]:Clone()
end

function Shared.GetMemeSound(sound: SoundName): Sound
	return ReplicatedStorage.Sounds:WaitForChild("Meme")[sound]:Clone()
end

function Shared.PlaySound(soundName: SoundName, part: Part | Attachment?)
	local sound = Shared.GetSound(soundName)
	if part then
		sound.Parent = part
	else
		sound.Parent = Workspace
	end

	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

function Shared.PlayMemeSound(soundName: SoundName)
	local sound = Shared.GetMemeSound(soundName)
	sound.Parent = Workspace

	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

return Shared
