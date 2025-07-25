
-- Set up namespace to grab data from config
local A, TEventsNamespace = ...

-- Get the spell database from Config
local trackedUnits = TEventsNamespace.trackedUnits
local additionalTracking = TEventsNamespace.additionalTracking
local eventTypes = TEventsNamespace.eventTypes
local spellSelector = TEventsNamespace.spellSelector
local castsSelector = TEventsNamespace.castsSelector
local buffsSelector = TEventsNamespace.buffsSelector
local constants = TEventsNamespace.constants
local ttsVoicesConfig = TEventsNamespace.ttsVoices
local defaultOptions = TEventsNamespace.defaultOptions

-- Get the global functions for addon
local initializeOptions = TEventsNamespace.initializeOptions

local TEventsMessageFrame = nil
local highPriorityVoiceId
local lowPriorityVoiceId

-- Set up "Casts in Progress", a table that contains spell ids for casts of each unit. Should only care about tracked units.
local castsInProgress = {}
-- Set up "Event Time", a table that contains spell ids for every event (thats not a cast) of each unit. Needed to do a de-spammifier.
local eventTime = {}

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

local function playSoundIfNeeded(foundSpell, spellName, sourceGUID, spellId, customSoundFunction) 
	
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
		
	C_VoiceChat.SpeakText(ttsVoice, ttsName, 1, TEventsDB["ttsSpeed"], TEventsDB["ttsVolume"])
	
end

local function isSpam(sourceGUID, timestamp, spellId)

	local lastEventTime = eventTime[sourceGUID] and eventTime[sourceGUID][spellId]

	if lastEventTime and (timestamp - lastEventTime < TEventsDB["spamThresholdSeconds"]) then
		-- Dont need to add the event to the event tracker, since otherwise spam filter will potentially be infinitely larger in time
		-- so we keep the time the event was actually fired
		return true
	end
	
	-- The event is not a spam, handle adding the event to the event tracking, with nil checks
	if not eventTime[sourceGUID] then
		eventTime[sourceGUID] = {}
	end
	
	eventTime[sourceGUID][spellId] = timestamp
	
	return false
end

-- Main processing logic for spell events and cast events    
local function processUnitSpellEvent(self, timestamp, sourceFlags, sourceGUID, spellId, spellArray, customSoundFunction, isSpamProtected)
	
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
		if not specId or not foundSpell.specId[specId] then
			return
		end
	end
	
	if isSpamProtected and isSpam(sourceGUID, timestamp, spellId) then
		return
	end
	
	local spellInfo = C_Spell.GetSpellInfo(spellId)
	
	local spellName = spellInfo.name
	local icon = spellInfo.iconID
	
	playSoundIfNeeded(foundSpell, spellName, sourceGUID, spellId, customSoundFunction)
	
	if foundSpell.hidden then
		return
	end
	
	local eventType = foundSpell.eventType or eventTypes["warning"]
	local name = foundSpell.displayName or spellName
	
	if TEventsDB.printEventName then
		self:AddMessage("|T"..icon..":"..constants.iconSize.."|t "..name, eventType.r, eventType.g, eventType.b);
	end
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

local function handleSpellCastSuccess(self, timestamp, sourceFlags, sourceGUID, spellId)
	processUnitSpellEvent(self, timestamp, sourceFlags, sourceGUID, spellId, spellSelector, defaultSoundPlayback, true)
end

local function handleSpellCastStart(self, timestamp, sourceFlags, sourceGUID, spellId)
	-- Not spam protected since people be faking
	processUnitSpellEvent(self, timestamp, sourceFlags, sourceGUID, spellId, castsSelector, castsSoundPlayback, false)
end

local function handleSpellBuffApply(self, timestamp, sourceFlags, sourceGUID, spellId)
	processUnitSpellEvent(self, timestamp, sourceFlags, sourceGUID, spellId, buffsSelector, defaultSoundPlayback, true)
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
		local timestamp, subEvent, _, sourceGUID, _, sourceFlags, _, _, _, destFlags,_ ,_ = CombatLogGetCurrentEventInfo()
			
		if subEvent == "SPELL_AURA_APPLIED" then
			spellId = select(12, CombatLogGetCurrentEventInfo())
			handleSpellBuffApply(self, timestamp, sourceFlags, sourceGUID, spellId)
			return
		end
		
		if subEvent == "SPELL_CAST_START" then
			spellId = select(12, CombatLogGetCurrentEventInfo())
			handleSpellCastStart(self, timestamp, sourceFlags, sourceGUID, spellId)
			return
		end
		
		if subEvent == "SPELL_CAST_SUCCESS" then
			spellId = select(12, CombatLogGetCurrentEventInfo())
			handleSpellCastSuccess(self, timestamp, sourceFlags, sourceGUID, spellId)
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
	-- C_VoiceChat.SpeakRemoteTextSample("text")
	
	-- Reset the global variables to save from potential memory leaks. Is there a garbage collection call in lua?
	castsInProgress = {}
	eventTime = {}
	
	TEventsMessageFrame = CreateFrame("ScrollingMessageFrame", "TEventsMessageFrame")
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

TEventsMainFrame = CreateFrame("Frame")
TEventsMainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
TEventsMainFrame:RegisterEvent("ADDON_LOADED")

local function setupDefaultOptions()
	
	TEventsDB = TEventsDB or {}
	for key, value in pairs(defaultOptions) do
		if TEventsDB[key] == nil then
			TEventsDB[key] = value
		end
	end
end

local function eventHandlerMain(self, event, addonName)

	if event == "ADDON_LOADED" then
		if addonName == "tevents" then
			setupDefaultOptions()
			initializeOptions()
		end
		self:UnregisterEvent(event)
	end
	
	if event == "PLAYER_ENTERING_WORLD" then
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
	
end

TEventsMainFrame:SetScript("OnEvent",eventHandlerMain)

local function testEvents()
	initializeTEvents()
	
	-- Add Player/Allies to tracked units
	trackedUnits[COMBATLOG_OBJECT_REACTION_FRIENDLY] = true
	additionalTracking["player"] = true
	
	-- Add Priest spells for testing
    spellSelector[586] = {} -- Test Spells with Fade
    spellSelector[139] = {eventType = eventTypes["summon"], displayName = "Incarnation: Chosen of", ttsPriority = "true"} -- Test Spells + Custom Name with Renew
	spellSelector[17] = {customSound = "aimedShot.ogg"} -- Test Spells + Custom Sound with Power Word: Shield
    spellSelector[21562] = {eventType = eventTypes["buff"], ttsName = "changed name so tts can actually pronounce feral frenzy"} -- Test Spells + Custom TTS with Power Word: Fortitude
	spellSelector[1706] = {hidden = true} -- Test Spells + Hidden message with Levitate
	spellSelector[47540] = {hidden = true, gameSound = 89367} -- Test Hidden + Game Sound with Penance
	
	castsSelector[194509] = {customSound = "fear.ogg"} -- Test Casts with Power Word: Radiance
	castsSelector[2061] = {hidden = true, customSound = "seduction.ogg"} -- Test Casts + Hidden Message with Flash Heal Cast
	
	-- Set the spec to 256 for spec checks
	findSpecByGUID = function (input) return 256 end
	
	-- Play Test Sounds
	-- Counter!
	defaultSoundPlayback(constants.counterSoundPath)
end

TEventsNamespace.testEvents = testEvents