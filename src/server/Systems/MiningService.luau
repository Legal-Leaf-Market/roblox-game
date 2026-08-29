--!strict
-- ModuleScript: ServerScriptService > Server > Systems > MiningService
-- Ore nodes in the caves under Heavenpillar Mountain. WorldBuilder creates
-- the nodes (tagged "OreNode" with an OreId attribute and a ProximityPrompt);
-- this system owns what happens when one is mined: payout, depletion,
-- respawn, and a little cultivation xp for honest work.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ores = require(Shared:WaitForChild("Data"):WaitForChild("Ores"))

local DataService = require(script.Parent.DataService)
local QiSystem = require(script.Parent.QiSystem)

local MAX_MINE_DISTANCE = 20

local MiningService = {}

local rng = Random.new()

local function setDepleted(node: Model, prompt: ProximityPrompt, depleted: boolean)
	prompt.Enabled = not depleted
	for _, descendant in node:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == "Crystal" then
			descendant.Transparency = if depleted then 0.85 else 0
		end
	end
end

local function onMined(node: Model, prompt: ProximityPrompt, ore: Ores.OreDef, player: Player)
	local data = DataService.Get(player)
	if data == nil or not prompt.Enabled then
		return
	end

	-- Distance sanity: the prompt already limits range, but prompts are
	-- client-signaled, so verify on the server too.
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local nodePart = node.PrimaryPart or node:FindFirstChildWhichIsA("BasePart")
	if root == nil or not root:IsA("BasePart") or nodePart == nil then
		return
	end
	if (root.Position - nodePart.Position).Magnitude > MAX_MINE_DISTANCE then
		return
	end

	local amount = rng:NextInteger(ore.harvestMin, ore.harvestMax)
	if ore.id == "spirit_stone" then
		data.spiritStones += amount
		DataService.Notify(player, `+{amount} spirit stones`, ore.color)
	else
		data.ores[ore.id] = (data.ores[ore.id] or 0) + amount
		DataService.Notify(player, `+{amount} {ore.name}`, ore.color)
	end

	-- Working the mountain's marrow is cultivation too, barely.
	QiSystem.AddXp(player, 1)

	DataService.PushStats(player)
	DataService.PushInventory(player)

	setDepleted(node, prompt, true)
	task.delay(ore.respawnSeconds, function()
		if node.Parent ~= nil then
			setDepleted(node, prompt, false)
		end
	end)
end

local function bindNode(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local node = instance :: Model
	local oreId = node:GetAttribute("OreId")
	if typeof(oreId) ~= "string" then
		return
	end
	local ore = Ores.get(oreId)
	if ore == nil then
		warn(`[MiningService] Unknown ore id "{oreId}" on {node:GetFullName()}`)
		return
	end
	local prompt = node:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt == nil then
		return
	end
	prompt.Triggered:Connect(function(player)
		onMined(node, prompt, ore, player)
	end)
end

function MiningService.Init()
	for _, node in CollectionService:GetTagged("OreNode") do
		bindNode(node)
	end
	CollectionService:GetInstanceAddedSignal("OreNode"):Connect(bindNode)
end

return MiningService
