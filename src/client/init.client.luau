--!strict
-- LocalScript: StarterPlayer > StarterPlayerScripts > Client
-- Client bootstrapper: requires every controller, Init() then Start().

local controllersFolder = script:WaitForChild("Controllers")
local modulesFolder = script:WaitForChild("Modules")

-- Core modules first: remote listeners and the animation loader must be
-- live before any controller reads them.
require(modulesFolder:WaitForChild("ClientState")).Init()
require(modulesFolder:WaitForChild("AnimUtil")).Init()

type Controller = {
	Init: (() -> ())?,
	Start: (() -> ())?,
}

local controllers: { [string]: Controller } = {}

for _, child in controllersFolder:GetChildren() do
	if child:IsA("ModuleScript") then
		local ok, result = pcall(require, child)
		if ok then
			controllers[child.Name] = result :: Controller
		else
			warn(`[Client] Failed to require controller "{child.Name}": {result}`)
		end
	end
end

for name, controller in controllers do
	if controller.Init then
		local ok, err = pcall(controller.Init :: any)
		if not ok then
			warn(`[Client] {name}.Init() failed: {err}`)
		end
	end
end

for name, controller in controllers do
	if controller.Start then
		task.spawn(function()
			local ok, err = pcall(controller.Start :: any)
			if not ok then
				warn(`[Client] {name}.Start() failed: {err}`)
			end
		end)
	end
end

print("[Client] Ready to cultivate.")
