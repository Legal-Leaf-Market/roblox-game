--!strict
-- ModuleScript: ReplicatedStorage > Shared > Data > Missions
-- Grandmaster Khadun's mining commissions, taken and turned in at the
-- Deepforge. Strictly sequential; the final mission repeats forever so the
-- forge never runs out of work. Ore is consumed from the pouch at turn-in.

export type MissionDef = {
	id: string,
	title: string,
	intro: string, -- dwarf's pitch when offering
	turnIn: string, -- dwarf's line on completion
	needs: { [string]: number }, -- ore id -> count
	rewardStones: number,
	rewardRaceSpins: number,
	rewardTalentSpins: number,
}

local Missions: { MissionDef } = {
	{
		id = "prove_your_arm",
		title = "Prove Your Arm",
		intro = "New hands. Hmph. The Mining Hall grows black iron like weeds. Bring me five, and swing like you mean it.",
		turnIn = "Passable. The mountain won't miss it. Here, stones. Spend them badly.",
		needs = { black_iron = 5 },
		rewardStones = 12,
		rewardRaceSpins = 1,
		rewardTalentSpins = 0,
	},
	{
		id = "cold_for_the_quench",
		title = "Cold for the Quench",
		intro = "My quench barrel's gone lukewarm, which is to say useless. Cold iron, eight pieces. It's the blue-veined stone that hates your fingers.",
		turnIn = "Ahh, hear the water scream? That's the sound of a proper edge being born.",
		needs = { cold_iron = 8 },
		rewardStones = 18,
		rewardRaceSpins = 0,
		rewardTalentSpins = 1,
	},
	{
		id = "sky_debt",
		title = "Sky Debt",
		intro = "Deeper hall, past my forge. Meteoric iron, six lumps. It fell from heaven, so technically heaven owes ME the delivery fee.",
		turnIn = "Star-metal. My father forged with it, and his mother before him. You have my grudging respect.",
		needs = { meteoric_iron = 6 },
		rewardStones = 26,
		rewardRaceSpins = 1,
		rewardTalentSpins = 1,
	},
	{
		id = "silver_for_a_bowstring",
		title = "Silver for a Bowstring",
		intro = "An immortal ordered a bow and paid in insults. Star silver, seven pieces, and I'll consider us all even.",
		turnIn = "Look how it takes the light. Almost worth dealing with immortals. Almost.",
		needs = { star_silver = 7 },
		rewardStones = 36,
		rewardRaceSpins = 1,
		rewardTalentSpins = 1,
	},
	{
		id = "the_heavy_metal",
		title = "The Heavy Metal",
		intro = "Profound gold. Xuanjin. Four pieces, and lift with your legs, cultivator, the ore does not care about your realm.",
		turnIn = "Heavier than sin and twice as useful. The forge sings tonight.",
		needs = { profound_gold = 4 },
		rewardStones = 50,
		rewardRaceSpins = 2,
		rewardTalentSpins = 1,
	},
	{
		id = "jade_of_the_immortals",
		title = "Jade of the Immortals",
		intro = "Now the true work. Immortal jade, four pieces. The deep veins guard it jealously, and so will I, once you hand it over.",
		turnIn = "By the deep roots... perfect stock. As long as the mountain stands, there is work here for you.",
		needs = { immortal_jade = 4 },
		rewardStones = 70,
		rewardRaceSpins = 2,
		rewardTalentSpins = 2,
	},
}

return table.freeze(Missions)
