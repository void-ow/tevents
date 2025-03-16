local A, TEventsNamespace = ...

local constants = {
	["frameWidth"] = 200,
	["frameHeight"] = 100,
	["frameOffsetY"] = 86,
	["fontSize"] = 13,
	["iconSize"] = 24,
	["timeVisible"] = 3.5,
	["fadeDuration"] = 0.5,
	["filePath"] = "Interface\\AddOns\\tevents\\sounds\\",
	["ttsSpeed"] = 4.9,
	["ttsVolume"] = 10,
	["spellCancelSound"] = 903,
	["counterSoundPath"] = "util\\counter.ogg",
	["soundChannel"] = "Master"
}

local trackedUnits = {
	[COMBATLOG_OBJECT_REACTION_HOSTILE] = true
}

local additionalTracking = {
	["arena1"] = true,
	["arena2"] = true,
	["arena3"] = true
}

local eventTypes = {
	["warning"] = {r = 1.0, g = 0.0, b = 0.0},
	["buff"] = {r = 1.0, g = 1.0, b = 0.0},
	["summon"] = {r = 1.0, g = 0.0, b = 1.0}
}

local ttsVoices = {
	[1] = "zira",
	[2] = "david"
}

local function findUnit(sourceGUID)
	
	local arena1 = UnitGUID("arena1")
	if arena1 and sourceGUID == arena1 then
		return "arena1"
	end
	
	local arena2 = UnitGUID("arena2")
	if arena2 and sourceGUID == arena2 then
		return "arena2"
	end
	
	local arena3 = UnitGUID("arena3")
	if arena3 and sourceGUID == arena3 then
		return "arena3"
	end
	
	-- Fallback to not fail miserably and AT LEAST say something
	return "player"
end

local function trinketLogic(sourceGUID)
	
	local unit = findUnit(sourceGUID)
	
	local _,className = UnitClass(unit)
	
	if not className then
		return
	end
	
	PlaySoundFile(constants.filePath.."trinket\\"..className..".ogg", constants.soundChannel)
end

-- Specific rules for spells:
-- EventType - what color should the message be, defaults to "warning"
-- DisplayName - what should be displayed AND read by TTS, defaults to spell name. Max length - 22 Symbols ("Incarnation: Chosen of")
-- TTSName - what should be read by TTS, defaults to DisplayName if its present, then to spell name
-- CustomSound - provides a customSound to play, defaults to TTS
-- Hidden - doesn't show a message on the screen, defaults to false
-- TTSPriority - changes TTS voice to signify priority
-- CustomFunction - hooks to a custom function, every other parameter is ignored by default
-- SpecId - checks for spec ids to not do false-positives for healers

local spellSelector = {
	
	--- ## Warnings ## ---
	-- # Tier 1 # --
	
	-- Demon Hunter --
	[258925] = {ttsPriority = "true"}, -- Fel Barrage
	-- Druid --
	[391528] = {ttsPriority = "true", displayName = "Convoke"}, -- Convoke the Spirits
	-- Evoker --
	[403631] = {ttsPriority = "true"}, -- Breath of Eons
	[357210] = {ttsPriority = "true", ttsName = "Breath of Eons"}, -- Deep Breath
	-- Paladin --
	[343721] = {ttsPriority = "true"}, -- Final Reckoning
	-- Rogue --
	[360194] = {ttsPriority = "true"}, -- Deathmark
	[280719] = {ttsPriority = "true"}, -- Secret Technique
	-- Warlock --
	[386997] = {ttsPriority = "true"}, -- Soul Rot
	-- Warrior --
	[376079] = {ttsPriority = "true"}, -- Champion's Spear
	
	-- # Tier 2 # --
	
	-- Death Knight --
	[275699] = {}, -- Apocalypse
	[305392] = {}, -- Chill Streak
	[210128] = {displayName = "Zombie Bomb"}, -- Reanimation (zombies that run at enemies)
	[439843] = {}, -- Reaper's Mark - [NEW in TWW]
	-- Demon Hunter --
	[258860] = {}, -- Essence Break
	[370965] = {}, -- The Hunt
	[390163] = {}, -- Sigil of Spite
	-- [442294] = {}, -- Reaver's Glaive - [NEW in TWW]
	-- Druid --
	[274837] = {ttsName = "Faeral Frenzy"}, -- Feral Frenzy
	-- Evoker --
	[370452] = {}, -- Shattering Star
	-- Hunter --
	[321530] = {}, -- Bloodshed
	[257044] = {}, -- Rapid Fire
	[360966] = {}, -- Spearhead
	-- [131894] = {displayName = "Crows"}, -- A Murder of Crows
	-- Mage --
	[321507] = {}, -- Touch of the Magi
	-- [153561] = {}, -- Meteor
	[431176] = {displayName = "Bolt Ready"}, -- Frostfire Empowerment - [NEW in TWW]
	-- Monk --
	-- [392983] = {displayName = "Windlord"}, -- Strike of the Windlord
	-- Paladin --
	[343527] = {}, -- Execution Sentence
	-- [198034] = {ttsPriority = "true"}, -- Divine Hammer (nobody picks this)
	[255937] = {}, -- Wake of Ashes
	[375576] = {specId = {[70] = true}}, -- Divine Toll
	-- Priest --
	[211522] = {ttsName = "Psaifiend"}, -- Psyfiend
	-- Rogue --
	[385627] = {}, -- Kingsbane
	[426591] = {ttsName = "Gore"}, -- Goremaw's Bite
	[196937] = {}, -- Ghostly Strike
	-- Shaman --
	[208963] = {displayName = "Skyfury"}, -- Totem of Wrath
	[460697] = {displayName = "Skyfury"}, -- Totem of Wrath
	-- Warlock --
	[267171] = {ttsName = "Lock Pet Spin"}, -- Demonic Strength
	[387976] = {displayName = "Rift"}, -- Dimensional Rift
	[417537] = {}, -- Oblivion (nobody takes this)
	[434635] = {}, -- Ruination - [NEW IN TWW]
	-- Warrior --
	[167105] = {}, -- ColosSUS Smash
	[262161] = {}, -- Warbreaker
	[384318] = {displayName = "Bleed Roar"}, -- Thunderous Roar
	[397364] = {displayName = "Bleed Roar"}, -- Thunderous Roar
	
	
	--- ## Summons ## ---
	-- # Tier 1 # --
	
	-- Death Knight --
	[63560] = {eventType = eventTypes["summon"], displayName = "Dark Transformation", ttsPriority = "true"}, -- Dark Transformation
--	[42650] = {eventType = eventTypes["summon"], displayName = "Army of the Dead", ttsPriority = "true"}, -- Army of the Dead
--	[455395] = {eventType = eventTypes["summon"], displayName = "Abomination", ttsPriority = "true"}, -- Raise Abomination
	-- Hunter --
	[205691] = {eventType = eventTypes["summon"], displayName = "GIGA Basilisk of Hell", ttsPriority = "true"}, -- Dire Beast: Basilisk
	-- Warlock --
	[205180] = {eventType = eventTypes["summon"], displayName = "Darkglare", ttsPriority = "true"}, -- Summon Darkglare
	[265187] = {eventType = eventTypes["summon"], displayName = "Tyrant", ttsPriority = "true"}, -- Summon Demonic Tyrant
	[1122] = {eventType = eventTypes["summon"], displayName = "Infernal", ttsPriority = "true"}, -- Summon Infernal
	
	--- ## Buffs ## ---
	-- # Tier 1 # --
	
	-- Death Knight --
	[51271] = {eventType = eventTypes["buff"]}, -- Pillar of Frost
	[47568] = {eventType = eventTypes["buff"], displayName = "Rune Weapon"}, -- Empower Rune Weapon
	[207289] = {eventType = eventTypes["buff"]}, -- Unholy Assault
	-- Demon Hunter --
	[200166] = {eventType = eventTypes["buff"]}, -- Metamorphosis
	-- Druid --
	[194223] = {eventType = eventTypes["buff"]}, -- Celestial Alignment
	[102560] = {eventType = eventTypes["buff"], displayName = "Incarnation"}, -- Incarnation: Chosen of Elune 
	[390414] = {eventType = eventTypes["buff"], displayName = "Incarnation"}, -- Incarnation: Chosen of Elune 2: First Blood
	[106951] = {eventType = eventTypes["buff"]}, -- Berserk
	[102543] = {eventType = eventTypes["buff"], displayName = "Incarnation"}, -- Incarnation: Avatar of Ashamane
	-- Evoker --
	[375087] = {eventType = eventTypes["buff"]}, -- Dragonrage
	-- Hunter --
	[19574] = {eventType = eventTypes["buff"]}, -- Bestial Wrath
	[288613] = {eventType = eventTypes["buff"]}, -- Trueshot
	[360952] = {eventType = eventTypes["buff"]}, -- Coordinated Assault
	[359844] = {eventType = eventTypes["buff"]}, -- Call of the Wild
	-- Mage --
	[190319] = {eventType = eventTypes["buff"]}, -- Combustion
	[12472] = {eventType = eventTypes["buff"]}, -- Icy Veins
	[198144] = {eventType = eventTypes["buff"]}, -- Ice Form
	-- Monk --
	[443028] = {eventType = eventTypes["buff"], specId = {[269] = true}, displayName = "Serenity"}, -- Celestial Conduit (for WW only)
	[137639] = {eventType = eventTypes["buff"]}, -- Storm, Earth and Fire
	-- Paladin --
	[31884] = {eventType = eventTypes["buff"], specId = {[70] = true}}, -- Avenging Wrath (for Ret only)
	[231895] = {eventType = eventTypes["buff"]}, -- Crusade
	-- Priest --
	[228260] = {eventType = eventTypes["buff"], displayName = "Voidform"}, -- Void Eruption (Voidform)
	[391109] = {eventType = eventTypes["buff"], displayName = "Voidform"}, -- Dark Ascension
	-- Rogue --
	[13750] = {eventType = eventTypes["buff"]}, -- Adrenaline Rush
	[185422] = {eventType = eventTypes["buff"]}, -- Shadow Dance
	[185313] = {eventType = eventTypes["buff"]}, -- Shadow Dance v2
	[121471] = {eventType = eventTypes["buff"]}, -- Shadow Blades
	-- Shaman --
	[384352] = {eventType = eventTypes["buff"]}, -- Doom Winds
	[204361] = {eventType = eventTypes["buff"]}, -- Bloodlust
	[204362] = {eventType = eventTypes["buff"], displayName = "Bloodlust"}, -- Heroism
	[191634] = {eventType = eventTypes["buff"]}, -- Stormkeeper
	-- Warrior --
	[107574] = {eventType = eventTypes["buff"]}, -- Avatar
	[1719] = {eventType = eventTypes["buff"]}, -- Recklessness
	
	--- ## Hidden ## --- (but sounds still play)
	
	-- # Casts & Actions # --	
	[198158] = {hidden = true, ttsName = "Mass Invis"}, -- Mass Invisibility
	--[108285] = {hidden = true, customSound = "totemicRecall.ogg"}, -- Totemic Recall
	--[198838] = {hidden = true, customSound = "earthenWallTotem.ogg"}, -- Earthen Wall Totem
	-- PvP Trinkets --
	[336135] = {hidden = true}, -- Adaptation
	[34709] = {hidden = true}, -- Shadow Sight
	[6262] = {hidden = true, customSound = "healthstone.ogg"}, -- Healthstone
	[452930] = {hidden = true, customSound = "healthstone.ogg"}, -- Demonic Healthstone
	-- Racials --
	[58984] = {hidden = true, customSound = "shadowmeld.ogg"}, -- Shadowmeld
	[7744] = {hidden = true, customSound = "willOfTheForsaken.ogg"}, -- Will of the Forsaken
	[59752] = {hidden = true, customSound = "everyMan.ogg"}, -- Will to Survive
	[256948] = {hidden = true, customSound = "spatialRift.ogg"}, -- Spatial Rift
	-- Death Knight --
	[49039] = {hidden = true, customSound = "lichborne.ogg"}, -- Lichborne
	[77606] = {hidden = true, customSound = "darkSimulacrum.ogg"}, -- Dark Simulacrum
	-- Demon Hunter --
	[188501] = {hidden = true, customSound = "spectralSight.ogg"}, -- Spectral Sight
	[205604] = {hidden = true, customSound = "reverseMagic.ogg"}, -- Reverse Magic
	-- Druid --
	[102793] = {hidden = true, customSound = "ursolsVortex.ogg"}, -- Ursol's Vortex
	[29166] = {hidden = true, customSound = "innervate.ogg"}, -- Innervate
	-- Evoker --
	[374251] = {hidden = true, customSound = "cauterizingFlame.ogg"}, -- Cauterizing Flame
	[372048] = {hidden = true, customSound = "oppressingRoar.ogg"}, -- Oppressing Roar
	-- Hunter --
	[187650] = {hidden = true, customSound = "freezingTrap.ogg"}, -- Freezing Trap
	[109248] = {hidden = true, customSound = "bindingShot.ogg"}, -- Binding Shot
	-- Mage --
	[45438] = {hidden = true, customSound = "iceBlock.ogg"}, -- Ice Block
	-- Monk --
--	[101643] = {hidden = true, customSound = "transcendence.ogg"}, -- Transcendence
	[388615] = {hidden = true, customSound = "revival.ogg"}, -- Restoral (Revival)
	[115310] = {hidden = true, customSound = "revival.ogg"}, -- Revival (Restoral)
	[122470] = {hidden = true, customSound = "touchOfKarma.ogg"}, -- Touch of Karma
	-- Paladin --
	[1022] = {hidden = true, customSound = "bop.ogg"}, -- Blessing of Protection
	[642] = {hidden = true, customSound = "divineShield.ogg"}, -- Divine Shield
	[204018] = {hidden = true, customSound = "spellwarding.ogg"}, -- Blessing of Spellwarding
	[199448] = {hidden = true, customSound = "ultimateSacrifice.ogg"}, -- Ultimate Sacrifice
	[199452] = {hidden = true, customSound = "ultimateSacrifice.ogg"}, -- Ultimate Sacrifice (which one is real????)
	[210256] = {hidden = true, customSound = "sanctuary.ogg"}, -- Blessing of Sanctuary
	-- Priest --
	[197268] = {hidden = true, customSound = "rayOfHope.ogg"}, -- Ray of Hope
	[213610] = {hidden = true, customSound = "holyWard.ogg"}, -- Holy Ward
	[8122] = {hidden = true, customSound = "psychicScream.ogg"}, -- Psychic Scream
	[108968] = {hidden = true, customSound = "voidShift.ogg"}, -- Void Shift
	[316262] = {hidden = true, customSound = "thoughtsteal.ogg"}, -- Thoughtsteal
	[32379] = {hidden = true, specId = {[256] = true, [257] = true}, customSound = "death.ogg"}, -- Shadow Word: Death - Healer only
	-- Rogue --
	[1856] = {hidden = true, customSound = "vanish.ogg"}, -- Vanish
	[212182] = {hidden = true, customSound = "smokeBomb.ogg"}, -- Smoke Bomb (Assassination & Outlaw)
	[359053] = {hidden = true, customSound = "smokeBomb.ogg"}, -- Smoke Bomb (Sub)
	-- Shaman --
	[409293] = {hidden = true, customSound = "burrow.ogg"}, -- Burrow
	[204331] = {hidden = true, customSound = "counterstrikeTotem.ogg"}, -- Counterstrike Totem
	[98008] = {hidden = true, customSound = "spiritLinkTotem.ogg"}, -- Spirit Link Totem
	[207399] = {hidden = true, customSound = "ancestralProtectionTotem.ogg"}, -- Ancestral Protection Totem
	[204336] = {hidden = true, customSound = "groundingTotem.ogg"}, -- Grounding Totem
	[8143] = {hidden = true, customSound = "tremorTotem.ogg"}, -- Tremor Totem
	-- Warlock --
	[212295] = {hidden = true, customSound = "netherWard.ogg"}, -- Nether Ward
	[80240] = {hidden = true, customSound = "havoc.ogg"}, -- Havoc
	[119905] = {hidden = true, ttsName = "Imp Dispel"}, -- Singe Magic (Imp)
	[132411] = {hidden = true, ttsName = "Imp Dispel"}, -- Singe Magic (Eaten Imp)
	-- Warrior --
	[18499] = {hidden = true, customSound = "berserkerRage.ogg"}, -- Berserker Rage
	[23920] = {hidden = true, customSound = "spellReflection.ogg"}, -- Spell Reflection
	[384100] = {hidden = true, customSound = "berserkerShout.ogg"}, -- Berserker Shout
	[1219201] = {hidden = true, customSound = "warBanner.ogg"}, -- Berserker Roar (pseudo war banner)
	[199261] = {hidden = true}, -- Death Wish
	
	--- ## Hidden + Game Sound ## ---
	
	-- Evoker --
	[351338] = {hidden = true, gameSound = 3227}, -- Quell
	-- Rogue --
	[408] = {hidden = true, gameSound = 58160}, -- Kidney Shot
	[1833] = {hidden = true, gameSound = 56698}, -- Cheap Shot
	-- Mage --
	[2139] = {hidden = true, gameSound = 3227}, -- Counterspell
	-- Warlock --
	[19647] = {hidden = true, gameSound = 3227}, -- Spell Lock (Felhunter)
	[132409] = {hidden = true, gameSound = 3227}, -- Spell Lock (Warlock)
	
	--- ## Custom Logic ## ---
	
	[336126] = {customFunction = trinketLogic} -- Gladiator's Medallion
}

local castsSelector = {
	
	--- ## Casts ## ---
	
	--[2637] = {customSound = "hibernate.ogg"}, -- Hibernate
	--[1513] = {customSound = "scareBeast.ogg"}, -- Scare Beast
	-- Druid --
	[33786] = {hidden = true, customSound = "cyclone.ogg"}, -- Cyclone
	[339] = {hidden = true, customSound = "entanglingRoots.ogg"}, -- Entangling Roots
	-- Evoker --
	[360806] = {hidden = true, customSound = "sleepwalk.ogg"}, -- Sleepwalk
	-- Hunter --
	[203155] = {hidden = true, customSound = "sniperShot.ogg"}, -- Sniper Shot
	-- Mage --
	[113724] = {hidden = true, customSound = "ringOfFrost.ogg"}, -- Ring of Frost
	[389794] = {hidden = true, customSound = "snowdrift.ogg"}, -- Snowdrift
	[118] = {hidden = true, customSound = "polymorph.ogg"}, -- Polymorph
	[28271] = {hidden = true, customSound = "polymorph.ogg"}, -- Polymorph : Turtle
	[28272] = {hidden = true, customSound = "polymorph.ogg"}, -- Polymorph : Pig
	[61025] = {hidden = true, customSound = "polymorph.ogg"}, -- Polymorph : Serpent
	[61305] = {hidden = true, customSound = "polymorph.ogg"}, -- Polymorph : Black Cat
	[61721] = {hidden = true, customSound = "polymorph.ogg"}, -- Polymorph : Rabbit
	[61780] = {hidden = true, customSound = "polymorph.ogg"}, -- Polymorph : Turkey
	[126819] = {hidden = true, customSound = "polymorph.ogg"}, -- Polymorph : Porcupine
	[161353] = {hidden = true, customSound = "polymorph.ogg"}, -- Polymorph : Polar Bear Cub
	[161354] = {hidden = true, customSound = "polymorph.ogg"}, -- Polymorph : Monkey
	[161355] = {hidden = true, customSound = "polymorph.ogg"}, -- Polymorph : Penguin
	[161372] = {hidden = true, customSound = "polymorph.ogg"}, -- Polymorph : Peacock
	[277787] = {hidden = true, customSound = "polymorph.ogg"}, -- Polymorph : Direhorn
	[277792] = {hidden = true, customSound = "polymorph.ogg"}, -- Polymorph : Bee
	[321395] = {hidden = true, customSound = "polymorph.ogg"}, -- Polymorph : Mawrat
	[391622] = {hidden = true, customSound = "polymorph.ogg"}, -- Polymorph : Duck
	[460392] = {hidden = true, customSound = "polymorph.ogg"}, -- Polymorph : Mosswool - [NEW IN TWW]
	[383121] = {hidden = true, customSound = "polymorph.ogg"}, -- Mass Polymorph
	-- Monk --
	[198898] = {hidden = true, customSound = "songOfChiJi.ogg"}, -- Song of Chi-Ji
	-- Paladin --
	[410126] = {hidden = true, customSound = "searingGlare.ogg"}, -- Searing Glare
	[20066] = {hidden = true, customSound = "repentance.ogg"}, -- Repentance
	-- Priest --
	[605] = {hidden = true, customSound = "mindControl.ogg"}, -- Mind Control
	[375901] = {hidden = true, customSound = "mindgames.ogg"}, -- Mindgames
	-- Shaman --
	[51514] = {hidden = true, customSound = "hex.ogg"}, -- Hex
	[210873] = {hidden = true, customSound = "hex.ogg"}, -- Hex : Compy
	[211004] = {hidden = true, customSound = "hex.ogg"}, -- Hex : Spider
	[211010] = {hidden = true, customSound = "hex.ogg"}, -- Hex : Snake
	[211015] = {hidden = true, customSound = "hex.ogg"}, -- Hex : Cockroach
	[269352] = {hidden = true, customSound = "hex.ogg"}, -- Hex : Skeletal Hatchling
	[277778] = {hidden = true, customSound = "hex.ogg"}, -- Hex : Zandalari Tendonripper
	[277784] = {hidden = true, customSound = "hex.ogg"}, -- Hex : Wicker Mongrel
	[309328] = {hidden = true, customSound = "hex.ogg"}, -- Hex : Living Honey
	-- Warlock --
	[5782] = {hidden = true, customSound = "fear.ogg"}, -- Fear
	[6358] = {hidden = true, customSound = "seduction.ogg"}, -- Seduction
	[115268] = {hidden = true, customSound = "seduction.ogg"}, -- Mesmerize - Shivarra Pet
	[261589] = {hidden = true, customSound = "seduction.ogg"} -- Eaten Demon Seduction - No one will EVER do that
	
}

local buffSelector = {
	[114050] = {eventType = eventTypes["buff"]}, -- Ascendance
	[114051] = {eventType = eventTypes["buff"]}, -- Ascendance
	[365362] = {eventType = eventTypes["buff"]}, -- Arcane Surge
	[248519] = {hidden = true, customSound = "interlope.ogg"}, -- Interlope
	[212704] = {hidden = true, customSound = "beastWithin.ogg"}, -- The Beast Within
	[433832] = {eventType = eventTypes["buff"]}, -- Dream Burst - [NEW in TWW]
	[442726] = {eventType = eventTypes["buff"]}, -- Malevolence - [NEW in TWW]
	[408558] = {hidden = true, specId = {[256] = true, [257] = true}, customSound = "greaterFade.ogg"}, -- Phase Shift - Healer only
}

TEventsNamespace.trackedUnits = trackedUnits
TEventsNamespace.eventTypes = eventTypes
TEventsNamespace.ttsVoices = ttsVoices
TEventsNamespace.spellSelector = spellSelector
TEventsNamespace.castsSelector = castsSelector
TEventsNamespace.buffsSelector = buffSelector
TEventsNamespace.constants = constants
TEventsNamespace.additionalTracking = additionalTracking