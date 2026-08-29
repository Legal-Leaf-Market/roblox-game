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

	-- A disciple's breakthrough honors the master: their qi gain deepens.
	if data.masterUserId then
		local masterUserId = data.masterUserId :: number
		local master = Players:GetPlayerByUserId(masterUserId)
		local masterData = if master then DataService.Get(master) else nil
		if master and masterData then
			masterData.masterBonus = math.min(Config.MASTER_BONUS_CAP, masterData.masterBonus + Config.MASTER_BONUS_PER_BREAKTHROUGH)
			DataService.Notify(master, `Your disciple {player.Name} has broken through! Your qi gain deepens (+{Config.MASTER_BONUS_PER_BREAKTHROUGH}x).`, Color3.fromRGB(255, 215, 120))
			DataService.PushStats(master)
		else
			DataService.MailCredit(masterUserId, Config.MASTER_BONUS_PER_BREAKTHROUGH)
		end
	end

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

-- Qi Step: qi flows over the feet. Costs qi every tick, grants speed via
-- attributes the client's movement formula reads; the QiStepping attribute
-- replicates, so every client can draw the foot glow.
local qiStepping: { [Player]: boolean } = {}

local function setQiStep(player: Player, active: boolean)
	if active then
		qiStepping[player] = true
	else
		qiStepping[player] = nil
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid:SetAttribute("QiStepBonus", if active then Config.QISTEP_SPEED_BONUS else 0)
		humanoid:SetAttribute("QiStepping", active)
	end
end

function QiSystem.Init()
	local meditateSet = Net.remoteEvent("MeditateSet")
	meditateSet.OnServerEvent:Connect(function(player, wants: unknown)
		DataService.SetMeditating(player, wants == true)
		DataService.PushStats(player)
	end)

	Net.remoteEvent("QiStepSet").OnServerEvent:Connect(function(player, wants: unknown)
		local data = DataService.Get(player)
		if data == nil then
			return
		end
		if wants == true and data.qi < Config.QISTEP_DRAIN * 2 then
			DataService.Notify(player, "Not enough qi to cover your feet.")
			return
		end
		setQiStep(player, wants == true)
	end)

	Players.PlayerRemoving:Connect(function(player)
		qiStepping[player] = nil
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

			-- Dao fortune from disciples adds whole multipliers to qi gain.
			local regen = realm.qiRegen * (mods.qiRegenMult + data.masterBonus)
			if meditating then
				regen *= realm.meditateMult
			end

			-- Qi Step pays its toll before regen is applied. A dead or
			-- missing character ends it: without this, dying mid-step left
			-- the flag set and drained qi invisibly forever.
			if qiStepping[player] then
				local character = player.Character
				local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
				if humanoid == nil or humanoid.Health <= 0 then
					setQiStep(player, false)
				elseif data.qi <= Config.QISTEP_DRAIN then
					setQiStep(player, false)
					DataService.Notify(player, "Your qi runs thin; the light leaves your feet.")
				else
					data.qi -= Config.QISTEP_DRAIN
				end
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
