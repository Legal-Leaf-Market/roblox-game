--!strict
-- ModuleScript: ReplicatedStorage > Shared > Data > Races
-- The 124 races of the cultivation world, drawn from Chinese myth: the
-- Classic of Mountains and Seas, the Four Symbols, the Four Perils, the
-- dragon courts, the underworld bureaucracy, and the spirits of beast,
-- plant and stone that cultivated a human form.
--
-- Everyone begins as a Mortal Human (fanren). New races come from Destiny
-- spins (server-rolled); any owned race can be equipped.
--
-- Balance lives in ONE place: statsFor() derives a race's modifiers from
-- rarity (how big the bonus budget is) and archetype (where it goes).
-- Individual entries carry identity and flavor only, so 124 races cannot
-- drift into 124 hand-tuned balance problems.

local Types = require(script.Parent.Parent.Types)

export type Archetype = "balanced" | "vitality" | "ferocity" | "wellspring" | "swiftness" | "sage" | "frugal"

export type RaceDef = {
	id: string,
	name: string,
	hanzi: string,
	rarity: Types.Rarity,
	archetype: Archetype,
	affinity: string?, -- element id; usable in techniques regardless of path
	blurb: string,
}

export type RaceStats = {
	maxQiMult: number,
	qiRegenMult: number,
	xpMult: number,
	damageMult: number,
	qiCostMult: number,
	cooldownMult: number,
	defenseBonus: number,
	maxHealthBonus: number,
	walkSpeedBonus: number,
}

local Races = {}

-- Bonus budget per rarity. All archetype effects scale off this single number.
local BUDGET: { [string]: number } = {
	common = 0.06,
	uncommon = 0.10,
	rare = 0.16,
	epic = 0.24,
	legendary = 0.34,
	mythic = 0.46,
}

-- Spin weights (relative). Server rolls against these.
Races.SPIN_WEIGHTS = table.freeze({
	common = 51.5,
	uncommon = 27.0,
	rare = 13.0,
	epic = 6.0,
	legendary = 2.0,
	mythic = 0.5,
})

-- Spirit stones refunded when a spin lands a race already owned.
Races.DUPLICATE_REFUND = table.freeze({
	common = 5,
	uncommon = 10,
	rare = 20,
	epic = 40,
	legendary = 80,
	mythic = 160,
})

local defs: { [string]: RaceDef } = {}
local order: { string } = {}

local function r(id: string, name: string, hanzi: string, rarity: Types.Rarity, archetype: Archetype, affinity: string?, blurb: string)
	assert(defs[id] == nil, `duplicate race id {id}`)
	defs[id] = {
		id = id,
		name = name,
		hanzi = hanzi,
		rarity = rarity,
		archetype = archetype,
		affinity = affinity,
		blurb = blurb,
	}
	table.insert(order, id)
end

-- =========================== MYTHIC (7) ===========================
r("qinglong", "Azure Dragon", "青龙", "mythic", "ferocity", "lightning",
	"The Eastern Symbol itself. Spring storms are its idle breathing.")
r("baihu", "White Tiger", "白虎", "mythic", "ferocity", nil,
	"The Western Symbol, lord of autumn and battle. Metal remembers its claws.")
r("zhuque", "Vermilion Bird", "朱雀", "mythic", "wellspring", "fire",
	"The Southern Symbol, elegant flame that no ash has ever followed.")
r("xuanwu", "Black Tortoise", "玄武", "mythic", "vitality", "ice",
	"The Northern Symbol, serpent and tortoise entwined. Winter is its patience.")
r("qilin", "Qilin", "麒麟", "mythic", "sage", "radiance",
	"Walks without bending grass. Appears only where a sage is about to.")
r("kunpeng", "Kunpeng", "鲲鹏", "mythic", "swiftness", "wind",
	"The fish that became the bird whose wings are weather. Ninety thousand li in one beat.")
r("yinglong", "Winged Dragon", "应龙", "mythic", "balanced", "lightning",
	"The oldest dragon, who dammed the floods and buried Chiyou. It has already won a war of gods.")

-- ========================= LEGENDARY (12) =========================
r("tianlong", "Celestial Dragon", "天龙", "legendary", "wellspring", "lightning",
	"Bearers of the heavenly palaces. Their qi is drawn from above the sky.")
r("shenlong", "Spirit Dragon", "神龙", "legendary", "balanced", "lightning",
	"Masters of rain and wind. Farmers pray to them; emperors pretend to.")
r("zhulong", "Torch Dragon", "烛龙", "legendary", "wellspring", "fire",
	"When its eye opens, day. When it closes, night. It does not blink carelessly.")
r("fenghuang", "Fenghuang", "凤凰", "legendary", "wellspring", "fire",
	"The august firebird whose death is a scheduling matter.")
r("jiuweihu", "Nine-Tailed Fox", "九尾狐", "legendary", "sage", "shadow",
	"Each tail is a century of cunning. It has nine and is collecting more.")
r("pixiu", "Pixiu", "貔貅", "legendary", "frugal", nil,
	"The treasure-beast that devours wealth and has no way to lose it. Qi hoards in it the same way.")
r("baize", "Baize", "白泽", "legendary", "sage", nil,
	"It named every one of the eleven thousand five hundred and twenty spirits. It remembers yours.")
r("jinwu", "Golden Crow", "金乌", "legendary", "ferocity", "fire",
	"Three-legged crow of the sun. Nine of its kin were shot down; this line remembers why.")
r("hundun", "Hundun", "混沌", "legendary", "balanced", nil,
	"Primordial chaos with a face it declined to finish. Order slides off it.")
r("pangu_remnant", "Pangu Remnant", "盘古遗脉", "legendary", "vitality", "earth",
	"Descended from the giant whose corpse became the world. The bones remember being mountains.")
r("yanluo_blood", "Yama Bloodline", "阎罗血脉", "legendary", "ferocity", "shadow",
	"Kin to the judge of the dead. Their killing intent files paperwork later.")
r("tianmo", "Heaven Demon", "天魔", "legendary", "frugal", "shadow",
	"Born in the gap between a cultivator's thought and deed. Temptation given a spine.")

-- =========================== EPIC (22) ============================
r("jiaolong", "Flood Dragon", "蛟龙", "epic", "vitality", "ice",
	"A serpent one storm short of dragonhood. Rivers make room anyway.")
r("qiulong", "Horned Dragon", "虬龙", "epic", "ferocity", "lightning",
	"Horned and impatient, the dragon shape most often met in a bad mood.")
r("fuzanglong", "Treasure Dragon", "伏藏龙", "epic", "frugal", "earth",
	"Coiled under the earth on hoards of jade and ore. Spending qi offends it.")
r("xiangliu", "Xiangliu-kin", "相柳之裔", "epic", "wellspring", "venom",
	"Nine heads, nine appetites, and marshes poisoned wherever it rested.")
r("taotie", "Taotie-kin", "饕餮之裔", "epic", "vitality", nil,
	"The glutton peril, all mouth and want. What it eats, it keeps.")
r("qiongqi", "Qiongqi-kin", "穷奇之裔", "epic", "ferocity", "wind",
	"The winged tiger peril that rewards the wicked. It flies fastest toward a fight.")
r("taowu", "Taowu-kin", "梼杌之裔", "epic", "ferocity", nil,
	"The obstinate peril. It has never once turned around.")
r("jiufeng", "Nine-Headed Phoenix", "九凤", "epic", "wellspring", "fire",
	"Nine heads that do not agree, except about burning.")
r("dapeng", "Great Peng", "大鹏", "epic", "swiftness", "wind",
	"A roc whose shadow is mistaken for dusk. Distance is a rumor to it.")
r("luan_bird", "Luan Bird", "鸾鸟", "epic", "sage", "radiance",
	"The five-colored herald of the Queen Mother of the West. Its song settles quarrels.")
r("xiezhi", "Xiezhi", "獬豸", "epic", "vitality", "radiance",
	"The one-horned arbiter that gores the party in the wrong. Do not lie near it.")
r("tianhu", "Celestial Fox", "天狐", "epic", "sage", nil,
	"A fox that finished its thousand years and got its paperwork approved.")
r("kui_beast", "Kui", "夔", "epic", "ferocity", "lightning",
	"One-legged storm ox. The Yellow Emperor made a war drum of its hide; the line holds a grudge.")
r("longma", "Dragon Horse", "龙马", "epic", "swiftness", nil,
	"Rose from the Yellow River with the trigrams on its back. It carries knowledge at a gallop.")
r("xingtian", "Xingtian-kin", "刑天之裔", "epic", "ferocity", nil,
	"Beheaded by heaven, it made its torso a face and kept fighting. Retreat is anatomically impossible.")
r("kuafu", "Kuafu-kin", "夸父之裔", "epic", "swiftness", nil,
	"Giants who chased the sun and died thirsty. The stride survived; so did the stubbornness.")
r("gonggong_blood", "Gonggong Bloodline", "共工血脉", "epic", "wellspring", "ice",
	"Heirs of the water titan who broke a pillar of heaven out of spite.")
r("zhurong_blood", "Zhurong Bloodline", "祝融血脉", "epic", "ferocity", "fire",
	"Heirs of the fire god who won that argument.")
r("leigong_blood", "Thunder Duke Line", "雷公血脉", "epic", "ferocity", "lightning",
	"The thunder bureau runs in the family. Their tempers are audible.")
r("banxian", "Half-Immortal", "半仙", "epic", "wellspring", nil,
	"One foot past the mortal ledger. Tribulation lightning has their address.")
r("xinmo", "Heart Demon", "心魔", "epic", "frugal", "shadow",
	"A cultivator's doubt that pulled itself out and walked. It knows every shortcut.")
r("heibai_wuchang", "Impermanence Twin", "黑白无常", "epic", "swiftness", "shadow",
	"Kin to the two constables of the dead. They always arrive exactly on time.")

-- =========================== RARE (27) ============================
r("panlong", "Coiling Dragon", "蟠龙", "rare", "vitality", nil,
	"A dragon of lakes that never rose. Its patience is structural.")
r("dilong", "Earth Dragon", "地龙", "rare", "vitality", "earth",
	"It keeps the underground rivers. Mines flood or hold at its pleasure.")
r("chilong", "Hornless Dragon", "螭龙", "rare", "swiftness", nil,
	"The sleek red climber carved on ten thousand eaves.")
r("bashe", "Ba Serpent", "巴蛇", "rare", "vitality", "venom",
	"It swallows elephants and discusses the bones three years later.")
r("bixi_son", "Bixi", "赑屃", "rare", "vitality", "earth",
	"Dragon-turtle son of the dragon, carrier of stele. Weight is its native language.")
r("suanni_son", "Suanni", "狻猊", "rare", "wellspring", "fire",
	"Lion son of the dragon who loves smoke and sitting. Incense burns in its lap.")
r("yazi_son", "Yazi", "睚眦", "rare", "ferocity", nil,
	"Blade-loving son of the dragon. It repays every glare.")
r("huli_jing", "Fox Spirit", "狐狸精", "rare", "sage", "shadow",
	"A fox partway up the thousand-year ladder, charming its way past the hard rungs.")
r("bifang", "Bifang Crane", "毕方", "rare", "ferocity", "fire",
	"The one-legged crane that appears where fires are about to be someone's fault.")
r("zhen_bird", "Zhen Bird", "鸩鸟", "rare", "frugal", "venom",
	"Its feathers steep a wine no taster survives. Emperors kept them; so did widows.")
r("xianhe", "Immortal Crane", "仙鹤", "rare", "wellspring", nil,
	"The mount and messenger of immortals. It has seen where they live.")
r("zouwu", "Zouwu", "驺吾", "rare", "swiftness", nil,
	"A five-colored tiger vaster than a hill that eats no living thing. Speed without appetite.")
r("tianma", "Heavenly Horse", "天马", "rare", "swiftness", "wind",
	"Winged herd of the upper pastures. Fences are a mortal concept.")
r("nian_beast", "Nian", "年兽", "rare", "ferocity", nil,
	"The year-end beast that fears red and firecrackers, and precious little else.")
r("yulong", "Gate-Leaping Carp", "跃龙门鲤", "rare", "wellspring", nil,
	"A carp that cleared the Dragon Gate and is still mid-transformation. Momentum incarnate.")
r("baishe_spirit", "White Snake", "白蛇", "rare", "wellspring", "venom",
	"A serpent of the Lady Bai's lineage: centuries of cultivation and one famous heartbreak.")
r("yutu", "Moon Hare", "玉兔", "rare", "sage", "ice",
	"It pounds the elixir of immortality on the moon and remembers every recipe.")
r("renshen_child", "Ginseng Child", "人参娃", "rare", "vitality", nil,
	"A root that slept ten thousand years and woke up a person. Vitality is its whole body.")
r("jiangshi", "Jiangshi", "僵尸", "rare", "vitality", "shadow",
	"Stiff-limbed risen dead. Breath left; endurance stayed.")
r("mengpo_novice", "Mengpo Novice", "孟婆弟子", "rare", "sage", nil,
	"Apprenticed at the bridge of forgetting. They remember what everyone else paid to lose.")
r("luocha", "Luocha", "罗刹", "rare", "ferocity", "shadow",
	"Rakshasa of the burning wastes. Beauty and hunger in no particular order.")
r("yecha", "Yecha", "夜叉", "rare", "ferocity", nil,
	"Yaksha soldiery of sea courts and hell garrisons. Professional violence.")
r("feilian", "Feilian", "飞廉", "rare", "swiftness", "wind",
	"The wind counts as its exhale. Deer's body, sparrow's head, no forwarding address.")
r("dianmu_line", "Lightning Mother Line", "电母血脉", "rare", "ferocity", "lightning",
	"Kin of the goddess who holds the mirrors that aim the thunder.")
r("fengbo_line", "Wind Uncle Line", "风伯血脉", "rare", "frugal", "wind",
	"Kin of the sack-carrier of gales. They spend breath, not qi.")
r("yushi_line", "Rain Master Line", "雨师血脉", "rare", "wellspring", "ice",
	"Kin of the rain bureau. Drought and downpour are family business.")
r("hebo_line", "River Lord Line", "河伯血脉", "rare", "wellspring", nil,
	"Kin of the Yellow River's god. Their qi meanders, floods, and always arrives.")

-- ========================= UNCOMMON (28) ==========================
r("tengshe", "Soaring Serpent", "腾蛇", "uncommon", "swiftness", "wind",
	"A snake that cultivated flight and skipped the legs entirely.")
r("chiwen_son", "Chiwen", "螭吻", "uncommon", "vitality", nil,
	"Roof-ridge son of the dragon who swallows fires. Buildings feel safer under it.")
r("pulao_son", "Pulao", "蒲牢", "uncommon", "wellspring", nil,
	"Bell-crowning son of the dragon. It screams at whales; the scream is the bell's soul.")
r("bian_son", "Bi'an", "狴犴", "uncommon", "vitality", nil,
	"Prison-gate son of the dragon. It stares down wrongdoing on principle.")
r("chaofeng_son", "Chaofeng", "嘲风", "uncommon", "swiftness", nil,
	"Eave-corner son of the dragon, addicted to heights and danger.")
r("qiuniu_son", "Qiuniu", "囚牛", "uncommon", "sage", nil,
	"Music-loving son of the dragon, carved on the necks of qin. It listens better than it fights.")
r("jiaotu_son", "Jiaotu", "椒图", "uncommon", "frugal", nil,
	"Door-knocker son of the dragon, clamped shut like a clam. Nothing gets in, including waste.")
r("jingwei", "Jingwei", "精卫", "uncommon", "sage", nil,
	"The drowned girl turned bird, filling the sea a pebble at a time. Persistence with wings.")
r("qingniao", "Azure Messenger", "青鸟", "uncommon", "swiftness", nil,
	"The Queen Mother's courier birds. News arrives before the dust does.")
r("shangyang", "Rain Bird", "商羊", "uncommon", "wellspring", "ice",
	"It dances on one leg before a downpour. Farmers watch its knees.")
r("bailu", "White Deer", "白鹿", "uncommon", "sage", nil,
	"Immortals ride it between mountains. It has overheard a great deal of dao.")
r("xiniu", "Spirit Rhinoceros", "灵犀", "uncommon", "vitality", nil,
	"Its horn holds one clear thread to another heart. Hard to move, harder to fool.")
r("ruishi", "Guardian Lion", "瑞狮", "uncommon", "vitality", nil,
	"Stone-lion spirit off its pedestal. It takes thresholds personally.")
r("chanchu", "Golden Toad", "金蟾", "uncommon", "frugal", nil,
	"The three-legged money toad. It spits coins in and swallows nothing out.")
r("qingshe_spirit", "Green Snake", "青蛇", "uncommon", "swiftness", "venom",
	"The White Lady's fiercer sister. Less patience, more fang.")
r("niutou", "Ox-Head", "牛头", "uncommon", "ferocity", nil,
	"Underworld constable stock. Escorting souls builds forearms.")
r("mamian", "Horse-Face", "马面", "uncommon", "swiftness", nil,
	"The other constable. Nobody outruns the schedule.")
r("wangliang", "Wangliang", "魍魉", "uncommon", "frugal", "shadow",
	"Marsh-shadow spirit that mimics voices. It pays for nothing at full price.")
r("chimei", "Chimei", "魑魅", "uncommon", "ferocity", "shadow",
	"Mountain-mist haunt that misleads travelers. Some of them it keeps.")
r("yuangui", "Vengeful Ghost", "冤鬼", "uncommon", "ferocity", "shadow",
	"Dead with a case still open. The grievance does the cultivating.")
r("chenghuang_scion", "City God Scion", "城隍之后", "uncommon", "sage", nil,
	"Descended from a mortal so upright the afterlife gave him a district.")
r("zhizhu_jing", "Spider Spirit", "蜘蛛精", "uncommon", "frugal", "venom",
	"Silk, patience, and a web-shaped budget. Nothing it catches is wasted.")
r("xiezi_jing", "Scorpion Spirit", "蝎子精", "uncommon", "ferocity", "venom",
	"Even Buddhas flinched at the sting. It is aware of this credential.")
r("wugong_jing", "Centipede Spirit", "蜈蚣精", "uncommon", "vitality", "venom",
	"A hundred legs, a hundred grudges, armor between every pair.")
r("huangshulang", "Weasel Spirit", "黄鼠狼", "uncommon", "swiftness", nil,
	"The yellow weasel that borrows luck and repays it crooked. Quick in every sense.")
r("lingzhi_jing", "Lingzhi Spirit", "灵芝精", "uncommon", "wellspring", nil,
	"A medicine mushroom that dosed itself for a thousand years.")
r("zhiren", "Paper Effigy", "纸人", "uncommon", "frugal", nil,
	"A funeral servant that outlived its funeral. Weighs nothing, wants little, burns never (so far).")
r("jueyuan", "Jueyuan Ape", "玃猿", "uncommon", "ferocity", nil,
	"A mountain ape old enough to have opinions about swordsmanship.")

-- ========================== COMMON (30) ===========================
r("fanren", "Mortal Human", "凡人", "common", "sage", nil,
	"No bloodline, no birthright, nothing but comprehension. Every immortal legend starts here.")
r("youhun", "Wandering Soul", "游魂", "common", "frugal", nil,
	"A soul that missed its ferry and kept walking. Travel light, want lighter.")
r("egui", "Hungry Ghost", "饿鬼", "common", "frugal", "shadow",
	"Cursed with a needle throat and a furnace belly. It wastes nothing, ever.")
r("shanxiao", "Mountain Imp", "山魈", "common", "swiftness", nil,
	"One-legged mischief of the high forests. It knows every shortcut it invented.")
r("yeren", "Wildman", "野人", "common", "vitality", nil,
	"The hairy hermit of the deep ranges. Weather is a suggestion.")
r("mao_yao", "Cat Spirit", "猫妖", "common", "swiftness", nil,
	"A cat that noticed people worship things and applied. Lands on its feet by doctrine.")
r("gou_yao", "Dog Spirit", "狗妖", "common", "vitality", nil,
	"Loyalty cultivated into a life philosophy. It holds the line because someone said stay.")
r("shu_jing", "Rat Spirit", "鼠精", "common", "frugal", nil,
	"First animal of the zodiac by way of cheating. Efficiency is a moral position.")
r("zhu_yao", "Pig Spirit", "猪妖", "common", "vitality", nil,
	"Appetite as foundation-building. Surprisingly durable, entirely unashamed.")
r("hou_yao", "Monkey Spirit", "猴妖", "common", "swiftness", nil,
	"Every monkey has heard the story of the stone one. Every monkey has plans.")
r("liyu_jing", "Carp Spirit", "鲤鱼精", "common", "wellspring", nil,
	"Still practicing for the Dragon Gate. The current is a training partner.")
r("hua_yao", "Flower Spirit", "花妖", "common", "wellspring", nil,
	"A garden bloom that drank moonlight past its bedtime for a century.")
r("shumu_jing", "Tree Spirit", "树木精", "common", "vitality", "earth",
	"An old tree that finally pulled its roots. It thinks in decades and hits like one.")
r("ciwei_jing", "Hedgehog Spirit", "刺猬精", "common", "vitality", nil,
	"One of the northern Five Immortal households. Small, spiked, respected.")
r("tudi_folk", "Earth God Folk", "土地民", "common", "balanced", "earth",
	"Villagers blessed by their local Tudigong. Modest gifts, reliably delivered.")
r("changbi_folk", "Long-Armed Folk", "长臂民", "common", "ferocity", nil,
	"From the country where arms reach the fish without a boat. Reach is a birthright.")
r("changgu_folk", "Long-Legged Folk", "长股民", "common", "swiftness", nil,
	"Their neighbors wade for them. A horizon is an afternoon.")
r("xiao_folk", "Small Folk", "小人国", "common", "frugal", nil,
	"The tiny nations of the far seas. Little bodies, precise appetites.")
r("guanxiong_folk", "Hole-Chested Folk", "贯胸民", "common", "wellspring", nil,
	"A tunnel through the chest where a heart's fear would be. Qi circulates strangely well.")
r("yumin_folk", "Feathered Folk", "羽民", "common", "swiftness", "wind",
	"Down-feathered islanders halfway to birds. Falling bores them.")
r("renyu", "Merfolk", "人鱼", "common", "wellspring", nil,
	"River merfolk whose tears are only tears. The pearls come with cultivation.")
r("niu_yao", "Ox Spirit", "牛妖", "common", "vitality", nil,
	"Patience with horns. It plowed for sixty years before asking a single question.")
r("yang_yao", "Goat Spirit", "羊妖", "common", "sage", nil,
	"It ate a library's worth of talisman paper and some of it took.")
r("ji_yao", "Rooster Spirit", "鸡妖", "common", "swiftness", "fire",
	"Announces the sun like it invented it. Ghosts leave when it clears its throat.")
r("gui_jing", "Turtle Spirit", "龟精", "common", "vitality", nil,
	"It intends to outlive the argument. All of them.")
r("wa_jing", "Frog Spirit", "蛙精", "common", "wellspring", nil,
	"A well-bottom sage who finally saw the whole sky and took notes.")
r("hudie_jing", "Butterfly Spirit", "蝴蝶精", "common", "swiftness", nil,
	"Possibly a philosopher dreaming it is a butterfly. Either way, hard to hit.")
r("denglong_jing", "Lantern Spirit", "灯笼精", "common", "frugal", "fire",
	"A festival lantern that refused to be packed away. It budgets its own light.")

do
	-- The bestiary promise: exactly 124 races.
	assert(#order == 124, `expected 124 races, got {#order}`)
end

Races.defs = table.freeze(defs)
Races.order = table.freeze(order)
Races.DEFAULT_RACE = "fanren"

function Races.get(id: string): RaceDef?
	return defs[id]
end

-- Derived modifiers. Deterministic from rarity + archetype so every race of
-- the same tier carries the same total strength, just aimed differently.
function Races.statsFor(id: string): RaceStats
	local def = defs[id] or defs[Races.DEFAULT_RACE]
	local b = BUDGET[def.rarity] or 0

	local stats: RaceStats = {
		maxQiMult = 1,
		qiRegenMult = 1,
		xpMult = 1,
		damageMult = 1,
		qiCostMult = 1,
		cooldownMult = 1,
		defenseBonus = 0,
		maxHealthBonus = 0,
		walkSpeedBonus = 0,
	}

	local a = def.archetype
	if a == "balanced" then
		stats.damageMult += b * 0.3
		stats.maxQiMult += b * 0.3
		stats.xpMult += b * 0.25
		stats.maxHealthBonus += b * 80
	elseif a == "vitality" then
		stats.maxHealthBonus += b * 250
		stats.defenseBonus += b * 0.2
	elseif a == "ferocity" then
		stats.damageMult += b * 0.8
		stats.maxHealthBonus += b * 100
	elseif a == "wellspring" then
		stats.maxQiMult += b * 0.7
		stats.qiRegenMult += b * 0.5
	elseif a == "swiftness" then
		stats.cooldownMult -= b * 0.5
		stats.walkSpeedBonus += b * 8
	elseif a == "sage" then
		stats.xpMult += b * 1.0
		stats.maxQiMult += b * 0.2
	elseif a == "frugal" then
		stats.qiCostMult -= b * 0.6
		stats.qiRegenMult += b * 0.3
	end

	return stats
end

return table.freeze(Races)
