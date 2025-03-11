local A, TEventsNamespace = ...

local defaultOptions = {
	printEventName = true,
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
	
	registerCanvas(mainPanel)
end

TEventsNamespace.initializeOptions = initializeOptions
TEventsNamespace.defaultOptions = defaultOptions