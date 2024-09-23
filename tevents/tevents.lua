-- Set up global entrypoint for testing
TEvents = {}

-- Set up namespace to grab data from config
local A, NS = ...

-- Get the spell database from Config
local trackedUnits = NS.trackedUnits
local additionalTracking = NS.additionalTracking
local eventTypes = NS.eventTypes
local spellSelector = NS.spellSelector
local castsSelector = NS.castsSelector
local buffsSelector = NS.buffsSelector
local constants = NS.constants
local ttsVoicesConfig = NS.ttsVoices

local TEventsMessageFrame = nil
local highPriorityVoiceId
local lowPriorityVoiceId

-- Set up "Casts in Progress", a table that contains sound ids for casts of each unit. Should only care about tracked units.
local castsInProgress = {}

local function checkIfTracked(flags)
	for k,_ in pairs(trackedUnits) do
		if bit.band(flags, k) > 0 then
			return true
		end
	end
	return false
end

-- Check if spell is supposed to be tracked
local function findSpell(sourceFlags, spellId, spellArray)
	
	if not sourceFlags then
		return
	end
	
	if not checkIfTracked(sourceFlags) then
		return
	end
	
	return spellArray[spellId]
end

local function findSpellByUnit(unit, spellId, spellArray)
	
	if not unit then
		return
	end
	
	if not additionalTracking[unit] then
		return
	end
	
	return spellArray[spellId]
end

local function findSpecByGUID(sourceGUID)
	-- todo: this is inefficient, we should probably only get this once and cache but solo shuffle though
	local arena2 = UnitGUID("arena2")
	local arena3 = UnitGUID("arena3")
	
	local toQuery = 1
	if sourceGUID == arena2 then
		toQuery = 2
	elseif sourceGUID == arena3 then
		toQuery = 3
	end
		
	local specId = GetArenaOpponentSpec(toQuery)
	return specId
end

local function playSoundNeeded(foundSpell, spellName, sourceGUID, spellId, customSoundFunction) 
	
	local customSound = foundSpell.customSound
	if customSound then
		customSoundFunction(customSound, sourceGUID, spellId)
		return
	end
	
	local gameSound = foundSpell.gameSound
	if gameSound then
		PlaySound(gameSound, constants.soundChannel)
		return
	end
	
	local ttsName = foundSpell.ttsName or foundSpell.displayName or spellName
		
	local ttsVoice = lowPriorityVoiceId
	if foundSpell.ttsPriority then
		ttsVoice = highPriorityVoiceId
	end
		
	C_VoiceChat.SpeakText(ttsVoice, ttsName, 1, constants.ttsSpeed, constants.ttsVolume)
	
end

-- Main processing logic for spell events and cast events    
local function processUnitSpellEvent(self, sourceFlags, sourceGUID, spellId, spellArray, customSoundFunction)
	
	local foundSpell = findSpell(sourceFlags, spellId, spellArray)
	
	if not foundSpell then
		return
	end
	
	if foundSpell.customFunction then
		foundSpell.customFunction(sourceGUID)
		return
	end
	
	if foundSpell.specId then
		local specId = findSpecByGUID(sourceGUID)
		if specId and foundSpell.specId ~= specId then
			return
		end
	end
	
	local spellInfo = C_Spell.GetSpellInfo(spellId)
	
	local spellName = spellInfo.name
	local icon = spellInfo.iconID
	
	playSoundNeeded(foundSpell, spellName, sourceGUID, spellId, customSoundFunction)
	
	if foundSpell.hidden then
		return
	end
	
	local eventType = foundSpell.eventType or eventTypes["warning"]
	local name = foundSpell.displayName or spellName
	
	self:AddMessage("|T"..icon..":"..constants.iconSize.."|t "..name, eventType.r, eventType.g, eventType.b);
end

-- Default way to play a provided sound
local function defaultSoundPlayback(sound) 
	PlaySoundFile(constants.filePath..sound, constants.soundChannel)
end

-- Way to play a stoppable sound for casts
local function castsSoundPlayback(sound, sourceGUID, spellId)
	_, soundHandle = PlaySoundFile(constants.filePath.."casts\\"..sound, constants.soundChannel)
	
	castsInProgress[sourceGUID] = {}
	castsInProgress[sourceGUID][spellId] = soundHandle
end

local function handleSpellCastSuccess(self, sourceFlags, sourceGUID, spellId)
	processUnitSpellEvent(self, sourceFlags, sourceGUID, spellId, spellSelector, defaultSoundPlayback)
end

local function handleSpellCastStart(self, sourceFlags, sourceGUID, spellId)
	processUnitSpellEvent(self, sourceFlags, sourceGUID, spellId, castsSelector, castsSoundPlayback)
end

local function handleSpellBuffApply(self, sourceFlags, sourceGUID, spellId)
	processUnitSpellEvent(self, sourceFlags, sourceGUID, spellId, buffsSelector, defaultSoundPlayback)
end

-- Handle stopping a cast and stopping an associated sound play
local function handleSpellCastStop(self, unit, spellId)
	
	local foundSpell = findSpellByUnit(unit, spellId, castsSelector)
	
	if not foundSpell then
		return
	end
	
	local sourceGUID = UnitGUID(unit)
	soundHandle = castsInProgress[sourceGUID] and castsInProgress[sourceGUID][spellId]
	
	if not soundHandle then
		return
	end
	
	StopSound(soundHandle, 100)
	PlaySound(constants.spellCancelSound, constants.soundChannel)
	castsInProgress[sourceGUID][spellId] = nil
	
end

-- Handle the kick event to play "counter" sound
local function handleSpellCastInterrupt(self, destFlags)
	
	if not checkIfTracked(destFlags) then
		return
	end
	
	defaultSoundPlayback(constants.counterSoundPath)
end 

-- Event handler for Message Frame
local function eventHandler(self, event, unit, _, spellId)
	
	if not event then
		return
	end
	
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, subEvent, _, sourceGUID, _, sourceFlags, _, _, _, destFlags,_ ,_ = CombatLogGetCurrentEventInfo()
			
		if subEvent == "SPELL_AURA_APPLIED" then
			spellId = select(12, CombatLogGetCurrentEventInfo())
			handleSpellBuffApply(self, sourceFlags, sourceGUID, spellId)
			return
		end
		
		if subEvent == "SPELL_CAST_START" then
			spellId = select(12, CombatLogGetCurrentEventInfo())
			handleSpellCastStart(self, sourceFlags, sourceGUID, spellId)
			return
		end
		
		if subEvent == "SPELL_CAST_SUCCESS" then
			spellId = select(12, CombatLogGetCurrentEventInfo())
			handleSpellCastSuccess(self, sourceFlags, sourceGUID, spellId)
			return
		end
		
		if subEvent == "SPELL_INTERRUPT" then
			handleSpellCastInterrupt(self, destFlags)
			return
		end
			
	end
	
	if event == "UNIT_SPELLCAST_INTERRUPTED" then
		handleSpellCastStop(self, unit, spellId)
		return
	end
	
end

local function setUpTtsVoices() 

	local highPriorityVoiceName = ttsVoicesConfig[1]
	local lowPriorityVoiceName = ttsVoicesConfig[2]
	
	local installedVoices = C_VoiceChat.GetTtsVoices()
	
	for k, installedVoice in pairs(installedVoices) do		
		
		if string.find(installedVoice.name:lower(), highPriorityVoiceName:lower()) then
			highPriorityVoiceId = installedVoice.voiceID
		end
		
		if string.find(installedVoice.name:lower(), lowPriorityVoiceName:lower()) then
			lowPriorityVoiceId = installedVoice.voiceID
		end
	end
	
	if not highPriorityVoiceId then
		if lowPriorityVoiceId then
			highPriorityVoiceId = lowPriorityVoiceId
		else
			print("TEvents: WARNING - Missing the TTS Voice with the name " .. highPriorityVoiceName .. "! Defaulting to the first available voice...")
			highPriorityVoiceId = 0
		end
	end	
	
	if not lowPriorityVoiceId then
		if highPriorityVoiceId then
			lowPriorityVoiceId = highPriorityVoiceId
		else
			print("TEvents: WARNING - Missing the TTS Voice with the name " .. lowPriorityVoiceName .. "! Defaulting to the first available voice...")
			lowPriorityVoiceId = 0
		end
	end
end

-- Init Method, only called in arena or for testing
local function initializeTEvents()

	-- https://github.com/Gethe/wow-ui-source/blob/live/Interface/SharedXML/ScrollingMessageFrame.lua#L289
	--C_VoiceChat.SpeakRemoteTextSample("text")
	
	TEventsMessageFrame = CreateFrame("ScrollingMessageFrame")
	TEventsMessageFrame:SetSize(constants.frameWidth, constants.frameHeight)
	TEventsMessageFrame:SetPoint("BOTTOM", "UIParent", "CENTER", 0, constants.frameOffsetY)
	TEventsMessageFrame:SetInsertMode("BOTTOM"); -- start from bottom
	TEventsMessageFrame:SetTimeVisible(constants.timeVisible);
	TEventsMessageFrame:SetFading(true);
	TEventsMessageFrame:SetFadeDuration(constants.fadeDuration);

	TEventsMessageFrame:SetFont("Fonts\\FRIZQT__.TTF", constants.fontSize, "OUTLINE")

	TEventsMessageFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	TEventsMessageFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	
	TEventsMessageFrame:SetScript("OnEvent",eventHandler)
	
	setUpTtsVoices();
end

local TEventsMainFrame = CreateFrame("Frame")
TEventsMainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

local function eventHandlerMain(self,event)
	
	local _,instanceType = GetInstanceInfo();
	
	if not instanceType then
		return
	end
	
	if TEventsMessageFrame then
		TEventsMessageFrame:UnregisterAllEvents()
		TEventsMessageFrame = nil
	end
	
	if instanceType ~= "arena" then
		return
	end
		
	initializeTEvents()
	
end

TEventsMainFrame:SetScript("OnEvent",eventHandlerMain)

function TEvents.test()
	initializeTEvents()
	
	-- Add Player/Allies to tracked units
	trackedUnits[COMBATLOG_OBJECT_REACTION_FRIENDLY] = true
	additionalTracking["player"] = true
	
	-- Add Priest spells for testing
    spellSelector[586] = {} -- Test Spells with Fade
    spellSelector[139] = {eventType = eventTypes["summon"], displayName = "Incarnation: Chosen of", ttsPriority = "true"} -- Test Spells + Custom Name with Renew
	spellSelector[17] = {customSound = "aimedShot.ogg"} -- Test Spells + Custom Sound with Power Word: Shield
    spellSelector[21562] = {ttsName = "changed name so tts can actually pronounce feral frenzy"} -- Test Spells + Custom TTS with Power Word: Fortitude
	spellSelector[1706] = {hidden = true} -- Test Spells + Hidden message with Levitate
	spellSelector[47540] = {hidden = true, gameSound = 89367} -- Test Hidden + Game Sound with Penance
	
	castsSelector[194509] = {customSound = "fear.ogg"} -- Test Casts with Power Word: Radiance
	castsSelector[2061] = {hidden = true, customSound = "seduction.ogg"} -- Test Casts + Hidden Message with Flash Heal Cast
	
	-- Play Test Sounds
	-- Counter!
	defaultSoundPlayback(constants.counterSoundPath)
end