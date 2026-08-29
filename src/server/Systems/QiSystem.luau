--!strict
-- ModuleScript: ServerScriptService > Server > Systems > QiSystem
-- The energy loop: qi regeneration, meditation, cultivation experience and
-- realm breakthroughs. Server-authoritative; the client only ever ASKS to
-- meditate and is TOLD its qi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))
local StatCalc = require(Shared:WaitForChild("StatCalc"))
local Realms = require(Shared:WaitForChild("Data"):WaitForChild("Realms"))

local DataService = require(script.Parent.DataService)

local QiSystem = {}

local techniqueVFX = Net.remoteEvent("TechniqueVFX")

function QiSystem.MaxQi(player: Player): number
	local data = DataService.Get(player)
	if data == nil then
		return 0
	end
	local realm = Realms[data.realm] or Realms[1]
	local mods = StatCalc.combine(data.path, data.race, data.equippedTalents)
	return math.floor(realm.maxQi * mods.maxQiMult + 0.5)
end

-- Deduct qi if the player has enough. The single gate every technique,
-- craft or art pays through.
function QiSystem.Spend(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if data == nil then
		return false
	end
	if data.qi < amount then
		return false
	end
	data.qi -= amount
	DataService.PushStats(player)
	return true
end

function QiSystem.AddXp(player: Player, amount: number)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local mods = StatCalc.combine(data.path, data.race, data.equippedTalents)
	data.cultivationXp += math.floor(amount * mods.xpMult + 0.5)
	QiSystem.CheckBreakthrough(player)
end

function QiSystem.CheckBreakthrough(player: Player)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	local realm = Realms[data.realm]
	if realm == nil or data.realm >= #Realms then
		return
	end
	if data.cultivationXp < realm.breakthroughXp then
		return
	end

	data.cultivationXp -= realm.breakthroughXp
	data.realm += 1
	data.qi = QiSystem.MaxQi(player)
	data.raceSpins += Config.BREAKTHROUGH_RACE_SPINS
	data.talentSpins += Config.BREAKTHROUGH_TALENT_SPINS

	local newRealm = Realms[data.realm]
	DataService.Notify(player, `Breakthrough! You have entered {newRealm.name}.`, Color3.fromRGB(255, 215, 120))
	DataService.Notify(player, `The heavens grant destiny: +{Config.BREAKTHROUGH_RACE_SPINS} race spins, +{Config.BREAKTHROUGH_TALENT_SPINS} talent spins.`)

	-- Golden pillar for everyone nearby.
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		techniqueVFX:FireAllClients({
			kind = "breakthrough",
			casterUserId = player.UserId,
			origin = root.Position,
		})
	end

	DataService.PushStats(player)
	DataService.PushDestiny(player)
end

function QiSystem.Init()
	local meditateSet = Net.remoteEvent("MeditateSet")
	meditateSet.OnServerEvent:Connect(function(player, wants: unknown)
		DataService.SetMeditating(player, wants == true)
		DataService.PushStats(player)
	end)
end

function QiSystem.Start()
	while true do
		task.wait(Config.QI_TICK_SECONDS)
		for _, player in Players:GetPlayers() do
			local data = DataService.Get(player)
			if data == nil then
				continue
			end
			local realm = Realms[data.realm] or Realms[1]
			local mods = StatCalc.combine(data.path, data.race, data.equippedTalents)
			local maxQi = math.floor(realm.maxQi * mods.maxQiMult + 0.5)

			local meditating = DataService.IsMeditating(player)
			if meditating then
				-- Standing up or walking ends meditation without a click.
				local character = player.Character
				local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
				if humanoid == nil or humanoid.MoveDirection.Magnitude > 0.05 or humanoid.Health <= 0 then
					meditating = false
					DataService.SetMeditating(player, false)
				end
			end

			local regen = realm.qiRegen * mods.qiRegenMult
			if meditating then
				regen *= realm.meditateMult
			end

			local changed = false
			if data.qi < maxQi then
				data.qi = math.min(maxQi, data.qi + regen)
				changed = true
			elseif data.qi > maxQi then
				data.qi = maxQi
				changed = true
			end

			if meditating then
				data.cultivationXp += math.floor(realm.meditateXp * mods.xpMult + 0.5)
				changed = true
				QiSystem.CheckBreakthrough(player)
			end

			if changed then
				DataService.PushStats(player)
			end
		end
	end
end

return QiSystem
