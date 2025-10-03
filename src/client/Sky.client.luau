local Lighting = game:GetService("Lighting")
local Sky: Sky = Lighting:WaitForChild("Stars")

while true do
    Sky.SkyboxOrientation = Sky.SkyboxOrientation + Vector3.new(-0.3,0,0)
    task.wait()
end