--!strict
-- Script: ServerScriptService > Server
-- Bootstrapper. Requires every system, runs Init() in a DECLARED order
-- (dictionary iteration order is not deterministic, and world-before-
-- gameplay matters), then Start() on all. Systems not in the order list
-- still load, after the listed ones.

local systemsFolder = script:WaitForChild("Systems")

type System = {
	Init: (() -> ())?,
	Start: (() -> ())?,
}

local ORDER = {
	"DataService",
	"WorldService",
	"CultivationService",
	"CombatService",
	"TechniqueService",
	"DiscipleService",
	"InventoryService",
	"NpcService",
}

local systems: { [string]: System } = {}
local names: { string } = {}

for _, child in systemsFolder:GetChildren() do
	if child:IsA("ModuleScript") then
		local ok, result = pcall(require, child)
		if ok then
			systems[child.Name] = result :: System
			table.insert(names, child.Name)
		else
			warn(`[Server] Failed to require system "{child.Name}": {result}`)
		end
	end
end

-- Ordered list first, then anything else alphabetically for stability.
table.sort(names, function(a, b)
	local ia = table.find(ORDER, a) or math.huge
	local ib = table.find(ORDER, b) or math.huge
	if ia ~= ib then
		return ia < ib
	end
	return a < b
end)

for _, name in names do
	local system = systems[name]
	if system.Init then
		local ok, err = pcall(system.Init :: any)
		if not ok then
			warn(`[Server] {name}.Init() failed: {err}`)
		end
	end
end

for _, name in names do
	local system = systems[name]
	if system.Start then
		task.spawn(function()
			local ok, err = pcall(system.Start :: any)
			if not ok then
				warn(`[Server] {name}.Start() failed: {err}`)
			end
		end)
	end
end

print("[Server] Heavenpillar stands.")
