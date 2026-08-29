--!strict
-- ModuleScript: ServerScriptService > Server > Systems > CultivationService
-- The heart of the game: qi, meditation, cultivation xp, and the climb
-- through 144 stages. The server owns every number; the client only asks
-- to meditate or to attempt a breakthrough.
--
-- Cultivation xp flows in from several systems (combat, training,
-- meditation, later quests/alchemy/encounters) through AddXp, so sitting
-- still is a path but never the only one.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))
local Realms = require(Shared:WaitForChild("Realms"))
local RateLimit = require(Shared:WaitForChild("RateLimit"))

local DataService = require(script.Parent.DataService)

local CultivationService = {}

local combatFx = Net.remoteEvent("CombatFx")
local breakthroughLimit = RateLimit.new(4, 5)

-- Qi-rich places (tagged CultivationZone, Radius + QiMult attributes).
type Zone = { position: Vector3, radius: number, qiMult: number }
local zones: { Zone } = {}

local function registerZone(marker: Instance)
	if not marker:IsA("BasePart") then
		return
	end
	local radius = marker:GetAttribute("Radius")
	local qiMult = marker:GetAttribute("QiMult")
	table.insert(zones, {
		position = marker.Position,
		radius = if typeof(radius) == "number" then radius else 24,
		qiMult = if typeof(qiMult) == "number" then qiMult else 1.5,
	})
end

local function zoneMultiplierAt(position: Vector3): number
	local best = 1
	for _, zone in zones do
		if (position - zone.position).Magnitude <= zone.radius then
			best = math.max(best, zone.qiMult)
		end
	end
	return best
end

-- --------------------------- Character stats ----------------------------

-- Push this player's realm-derived stats onto their live character. The
-- attribute contract: the CLIENT owns humanoid.WalkSpeed and computes it
-- every frame from BaseWalkSpeed/SpeedFactor/SpeedFlat; the server never
-- writes WalkSpeed directly (two writers fight, and the client wins).
function CultivationService.RefreshStats(player: Player)
	local data = DataService.Get(player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if data == nil or humanoid == nil then
		return
	end
	local stats = Realms.statsFor(data.stage)
	local healthFrac = humanoid.Health / math.max(humanoid.MaxHealth, 1)
	humanoid.MaxHealth = stats.maxHealth
	humanoid.Health = math.max(1, stats.maxHealth * healthFrac)
	humanoid:SetAttribute("BaseWalkSpeed", Config.BASE_WALKSPEED + stats.speedBonus)
	humanoid:SetAttribute("SpeedFactor", 1)
	humanoid:SetAttribute("SpeedFlat", 0)
	humanoid:SetAttribute("DefenseFrac", stats.defenseFrac)
	humanoid:SetAttribute("Stage", data.stage)
	humanoid:SetAttribute("MajorRealm", Realms.majorOf(data.stage))
end

-- ------------------------------ Cultivation ------------------------------

function CultivationService.MaxQi(player: Player): number
	local data = DataService.Get(player)
	return if data then Realms.statsFor(data.stage).maxQi else 0
end

function CultivationService.Spend(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if data == nil or data.qi < amount then
		return false
	end
	data.qi -= amount
	DataService.PushStats(player)
	return true
end

function CultivationService.RestoreQi(player: Player, amount: number)
	local data = DataService.Get(player)
	if data == nil then
		return
	end
	data.qi = math.min(CultivationService.MaxQi(player), data.qi + amount)
	DataService.PushStats(player)
end

-- The one gate all cultivation xp passes through.
function CultivationService.AddXp(player: Player, amount: number)
	local data = DataService.Get(player)
	if data == nil or amount <= 0 then
		return
	end
	local cost = Realms.breakthroughCost(data.stage)
	if cost == nil then
		return -- a True Immortal XII has nothing left to gather
	end
	-- Xp pools up to the breakthrough cost and stops: reaching the limit
	-- is the signal to attempt a breakthrough, not a free ride past it.
	data.cultivationXp = math.min(cost, data.cultivationXp + math.floor(amount + 0.5))
	DataService.PushStats(player)
end

local function attemptBreakthrough(player: Player): { [string]: any }
	if not breakthroughLimit:Allow(player.UserId) then
		return { ok = false, error = "Breathe. Then try again." }
	end
	local data = DataService.Get(player)
	if data == nil then
		return { ok = false, error = "Data not loaded yet" }
	end
	local cost = Realms.breakthroughCost(data.stage)
	if cost == nil then
		return { ok = false, error = "There is no realm above yours." }
	end
	if data.cultivationXp < cost then
		return { ok = false, error = "Your foundation is not yet full." }
	end

	local crossing = Realms.isMajorCrossing(data.stage)
	if Realms.requiresTribulation(data.stage) then
		-- The Heavenly Tribulation encounter is its own coming system;
		-- until it exists the heavens grumble but permit passage.
		DataService.Notify(player, "Thunder rolls somewhere above the clouds... and subsides. (Heavenly Tribulations arrive in a coming update.)", Color3.fromRGB(200, 210, 255))
	end

	data.cultivationXp -= cost
	data.stage += 1
	data.qi = Realms.statsFor(data.stage).maxQi
	CultivationService.RefreshStats(player)

	local realmName = Realms.displayName(data.stage)
	if crossing then
		local major = Realms.major(data.stage)
		DataService.Notify(player, `MAJOR BREAKTHROUGH: you have entered the {major.name} Realm. {major.epithet}`, major.color)
	else
		DataService.Notify(player, `Breakthrough: {realmName}.`, Color3.fromRGB(255, 215, 120))
	end

	-- Everyone nearby sees the eruption.
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		combatFx:FireAllClients({
			kind = "breakthrough",
			userId = player.UserId,
			origin = root.Position,
			major = crossing,
			color = Realms.major(data.stage).color,
		})
	end

	DataService.PushStats(player)
	return { ok = true, stage = data.stage, realmName = realmName }
end

-- ------------------------------ Lifecycle -------------------------------

function CultivationService.Init()
	for _, marker in CollectionService:GetTagged("CultivationZone") do
		registerZone(marker)
	end
	CollectionService:GetInstanceAddedSignal("CultivationZone"):Connect(registerZone)

	Net.remoteEvent("MeditateSet").OnServerEvent:Connect(function(player, wants: unknown)
		DataService.SetMeditating(player, wants == true)
		DataService.PushStats(player)
	end)

	Net.remoteFunction("BreakthroughRequest").OnServerInvoke = attemptBreakthrough

	DataService.ObserveLoaded(function(player)
		CultivationService.RefreshStats(player)
		player.CharacterAdded:Connect(function()
			task.defer(CultivationService.RefreshStats, player)
		end)
	end)
end

function CultivationService.Start()
	while true do
		task.wait(Config.QI_TICK_SECONDS)
		for _, player in Players:GetPlayers() do
			local data = DataService.Get(player)
			if data == nil then
				continue
			end
			local stats = Realms.statsFor(data.stage)

			local meditating = DataService.IsMeditating(player)
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if meditating then
				-- Standing up, moving, or dying ends meditation by itself.
				if humanoid == nil or humanoid.Health <= 0 or humanoid.MoveDirection.Magnitude > 0.05 then
					meditating = false
					DataService.SetMeditating(player, false)
				end
			end

			local regen = stats.qiRegen
			local changed = false
			if meditating then
				local zoneMult = if root and root:IsA("BasePart") then zoneMultiplierAt(root.Position) else 1
				regen *= Config.MEDITATE_REGEN_MULT * zoneMult
				-- Meditation gathers cultivation, better in qi-rich places,
				-- but modestly: the world out there pays more.
				CultivationService.AddXp(player, (1 + data.stage * 0.06) * Config.MEDITATE_XP_MULT * zoneMult)
				changed = true
			end

			if data.qi < stats.maxQi then
				data.qi = math.min(stats.maxQi, data.qi + regen)
				changed = true
			elseif data.qi > stats.maxQi then
				data.qi = stats.maxQi
				changed = true
			end

			if changed then
				DataService.PushStats(player)
			end
		end
	end
end

return CultivationService
