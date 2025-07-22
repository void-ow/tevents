local A, TEventsNamespace = ...

local defaultOptions = {
	printEventName = true,
	ttsVolume = 10,
	ttsSpeed = 4.9,
	spamThresholdSeconds = 2,
	--someNewOption = "banana",
}

local function registerCanvas(frame)
	local cat = Settings.RegisterCanvasLayoutCategory(frame, frame.name, frame.name);
	cat.ID = frame.name
	Settings.RegisterAddOnCategory(cat)
end

local function createCheckbox(option, label, parent, updateFunction)
	local checkBox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
	checkBox.Text:SetText(label)
	
	local function UpdateOption(value)
		TEventsDB[option] = value
		checkBox:SetChecked(value)
		if updateFunction then
			updateFunction(value)
		end
	end
	
	UpdateOption(TEventsDB[option])
	
	checkBox:HookScript("OnClick", function(_, btn, down)
		UpdateOption(checkBox:GetChecked())
	end)

	return checkBox
end

local function createEditbox(option, label, parent, updateFunction)
	local editBox = CreateFrame("EditBox", nil, parent)
	
	editBox:SetWidth(100);
	editBox:SetHeight(20);
	editBox:SetMovable(false);
	editBox:SetAutoFocus(false);
	editBox:SetMultiLine(false);
	editBox:SetFontObject("ChatFontNormal")
	editBox:SetMaxLetters(10);
	
	local function UpdateOption(value)
		TEventsDB[option] = value
		editBox:SetText(value)
		if updateFunction then
			updateFunction(value)
		end
	end
	
	UpdateOption(TEventsDB[option])
	
	editBox:HookScript("OnTextChanged", function(self, userInput)
		UpdateOption(editBox:GetText())
	end)

	return editBox
end

local function modulateFunction(option, modulation, minimum, maximum)
	local value = TEventsDB[option]
	value = value + modulation
	
	if value < minimum then
		value = minimum
	end
	
	if value > maximum then
		value = maximum
	end
	
	value = tonumber(string.format("%.1f", value))
	
	TEventsDB[option] = value
	EventRegistry:TriggerEvent("TEvents.ConfigUpdated")
end

local function createModulateButton(option, label, parent, modulation, minimum, maximum)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button.Text:SetText(label)
	button:SetWidth(40)
	
	local function UpdateOption()
		modulateFunction(option, modulation, minimum, maximum)
	end
	
	button:HookScript("OnClick", function(_, btn, down)
		UpdateOption()
	end)

	return button
end

local function createSimpleSlider(option, label, parent, modulation, minimum, maximum, prevFrame)
	
	local textFrame = CreateFrame("Frame", nil, parent)
	textFrame:SetWidth(50) 
	textFrame:SetHeight(20) 
	textFrame:SetAlpha(1);
	textFrame.text = textFrame:CreateFontString(nil,"ARTWORK") 
	textFrame.text:SetFont("Fonts\\ARIALN.ttf", 13, "OUTLINE")
	textFrame.text:SetPoint("CENTER",0,0)
	textFrame.text:SetText(label .. ": " .. TEventsDB[option])
	
	EventRegistry:RegisterCallback("TEvents.ConfigUpdated", function()
		textFrame.text:SetText(label .. ": " .. TEventsDB[option])
	end, cb)
	
	textFrame:SetPoint("TOPLEFT", prevFrame, 80, -40)
	
	local decrease = createModulateButton(option, -modulation, parent, -modulation, minimum, maximum)
	decrease:SetPoint("TOPLEFT", prevFrame, 0, -40)
	
	local increase = createModulateButton(option, "+" .. modulation, parent, modulation, minimum, maximum)
	increase:SetPoint("TOPLEFT", prevFrame, 170, -40)
	
	return decrease
end


local function initializeOptions()
	local mainPanel = CreateFrame("Frame")
	mainPanel.name = "TEvents"
	
	local checkboxPrintEventName = createCheckbox("printEventName", "Show names for Events", mainPanel)
	checkboxPrintEventName:SetPoint("TOPLEFT", 20, -20)

	local stopTestingButton = CreateFrame("Button", nil, mainPanel, "UIPanelButtonTemplate")
	stopTestingButton:SetPoint("TOPLEFT", checkboxPrintEventName, 0, -40)
	stopTestingButton:SetText("Stop Testing (reload UI)")
	stopTestingButton:SetWidth(200)
	stopTestingButton:SetScript("OnClick", function()
		ReloadUI()
	end)
	stopTestingButton:Hide()
	
	local testButton = CreateFrame("Button", nil, mainPanel, "UIPanelButtonTemplate")
	testButton:SetPoint("TOPLEFT", checkboxPrintEventName, 0, -40)
	testButton:SetText("Test Events")
	testButton:SetWidth(100)
	testButton:SetScript("OnClick", function()
		TEventsNamespace.testEvents()
		testButton:Hide()
		stopTestingButton:Show()
	end)
	
	local ttsVolumeSlider = createSimpleSlider("ttsVolume", "TTS Volume", mainPanel, 5, 5, 100, testButton)
	local ttsSpeedSlider = createSimpleSlider("ttsSpeed", "TTS Speed", mainPanel, 0.1, -10, 10, ttsVolumeSlider)
	local spamThresholdSlider = createSimpleSlider("spamThresholdSeconds", "Spam Threshold", mainPanel, 0.1, 0, 5, ttsSpeedSlider)
	
	registerCanvas(mainPanel)
end

TEventsNamespace.initializeOptions = initializeOptions
TEventsNamespace.defaultOptions = defaultOptions