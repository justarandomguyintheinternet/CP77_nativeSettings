local nativeSettings = {
    data = {},
    fromMods = false,
    minCETVersion = 1.180000,
    settingsMainController = nil,
    settingsOptionsList = nil,
    currentTab = '',
    optionCount = 0,
    pressedButtons = {},
    version = 1.4,
    Cron = require("Cron")
}

registerForEvent("onInit", function()
    -- General setup things:

    local cetVer = tonumber((GetVersion():gsub('^v(%d+)%.(%d+)%.(%d+)(.*)', function(major, minor, patch, wip) -- <-- This has been made by psiberx, all credits to him
        return ('%d.%02d%02d%d'):format(major, minor, patch, (wip == '' and 0 or 1))
    end)))

    if cetVer < nativeSettings.minCETVersion then
        print(string.format("[NativeSettings] CET version is too low: %f, Minimum required is: %f", cetVer, nativeSettings.minCETVersion))
        return
    end

    Observe("SettingsMainGameController", "OnInitialize", function (this) -- Hide buttons
        if not nativeSettings.fromMods then return end

        nativeSettings.settingsMainController = this

        local rootWidget = this:GetRootCompoundWidget()
        local button = rootWidget:GetWidgetByPath(BuildWidgetPath({ 'wrapper', 'extra', "controller_btn"}))
        button:SetVisible(false)

        local button = rootWidget:GetWidgetByPath(BuildWidgetPath({ 'wrapper', 'extra', "brightness_btn"}))
        button:SetMargin(5000, 5000, 5000, 5000)

        local button = rootWidget:GetWidgetByPath(BuildWidgetPath({ 'wrapper', 'extra', "hdr_btn"}))
        button:SetMargin(5000, 5000, 5000, 5000)
    end)

    ObserveAfter("SettingsMainGameController", "OnInitialize", function (this) -- Get a ref to the settingsOptionsList
        if not nativeSettings.fromMods then return end

        nativeSettings.settingsOptionsList = this.settingsOptionsList
    end)

    Override("SettingsMainGameController", "ShowBrightnessScreen", function(_, wrapped) -- Disable brightness button functionality
        if nativeSettings.fromMods then return end
        wrapped()
    end)

    Override("SettingsMainGameController", "ShowControllerScreen", function(_, wrapped) -- Disable controller screen
        if nativeSettings.fromMods then return end
        wrapped()
    end)

    Observe("gameuiMenuItemListGameController", "AddMenuItem", function (this, _, spawnEvent) -- Add "Mods" menu button
        if spawnEvent.value == "OnSwitchToDlc" then
            this:AddMenuItem("Mods", "OnSwitchToSettings")
        end
    end)

    Observe("PauseMenuGameController", "OnMenuItemActivated", function (_, _, target) -- Check if activated button is the custom mods button
        nativeSettings.fromMods = target:GetData().label == "Mods"
    end)

    Observe("gameuiMenuItemListGameController", "OnMenuItemActivated", function (_, _, target) -- Check if activated button is the custom mods button
        nativeSettings.fromMods = target:GetData().label == "Mods"
    end)

    Observe("SettingsMainGameController", "RequestClose", function () -- Handle mod settings close
        if not nativeSettings.fromMods then return end
        nativeSettings.fromMods = false
        nativeSettings.settingsMainController = nil
        nativeSettings.clearControllers()
    end)

    Override("SettingsMainGameController", "PopulateCategories", function (this, idx, wrapped) -- Override to remove "Not Localized" on tabs
        if nativeSettings.fromMods then
            this.selectorCtrl:Clear()
            for _, curCategoty in pairs(this.data) do
                if not curCategoty.isEmpty then
                    local newData = ListItemData.new()
                    newData.label = GetLocalizedTextByKey(curCategoty.label)
                    if not newData.label or newData.label:len() == 0 then
                        newData.label = tostring(curCategoty.label.value)
                    end
                    this.selectorCtrl:PushData(newData)
                end
            end
            this.selectorCtrl:Refresh()
            if idx >= 0 and idx < #this.data then
                this.selectorCtrl:SetToggledIndex(idx)
            else
                this.selectorCtrl:SetToggledIndex(0)
            end
        else
            wrapped(idx)
        end
    end)

    Override("SettingsCategoryController", "Setup", function (this, label, wrapped) -- Override to remove "Not Localized" on Subcategories
        if nativeSettings.fromMods then
            local labelString = GetLocalizedTextByKey(label)
            if labelString:len() == 0 then
                labelString = label.value
            end
            this.label:SetText(labelString)
        else
            wrapped(label)
        end
    end)

    -- Adding UI things:

    Override("SettingsMainGameController", "PopulateSettingsData", function (this, wrapped) -- Add tabs to mods settings page
        if not nativeSettings.fromMods then -- Default behavior
            wrapped()
        else -- Opened from mods button
            local tabs = 0
            for _, _ in pairs(nativeSettings.data) do
                tabs = tabs + 1
            end
            if tabs == 0 then
                nativeSettings.addTab("noMod", "No mods using NativeSettings installed!") -- Add something when there are no settings, to make it not bug out
            end

            this.data = {}

            for _, tab in pairs(nativeSettings.data) do
                local category = SettingsCategory.new()
                category.label = tab.label
                category.groupPath = tostring("/" .. tab.path)
                category.isEmpty = false

                for _, k in pairs(tab.keys) do
                    local sub = tab.subcategories[k]

                    local currentSubcategory = SettingsCategory.new()
                    currentSubcategory.label = sub.label
                    currentSubcategory.groupPath = tostring("/" .. tab.path .. "/" .. sub.path)
                    currentSubcategory.isEmpty = false

                    category.subcategories = nativeSettings.nativeInsert(category.subcategories, currentSubcategory)
                end

                this.data = nativeSettings.nativeInsert(this.data, category)
            end
        end
    end)

    Override("SettingsMainGameController", "PopulateCategorySettingsOptions", function (this, idx, wrapped) -- Add actual settings options
        if nativeSettings.fromMods then
                this:PopulateSettingsData()
                nativeSettings.saveScrollPos()

                this.settingsElements = {}
                this.settingsOptionsList:RemoveAllChildren()
                this.descriptionText:SetVisible(false)

                if idx < 0 then
                    idx = this.selectorCtrl:GetToggledIndex()
                end

                local settingsCategory = this.data[idx + 1]

                nativeSettings.Cron.NextTick(function() -- "reduce the number of calls to game functions inside that single override" ~ psiberx
                    nativeSettings.clearControllers()
                    nativeSettings.currentTab = settingsCategory.groupPath.value:gsub('/', '')
                    nativeSettings.populateOptions(this, settingsCategory.groupPath.value) -- Add custom options to tab, no subcategory
                    for _, v in pairs(settingsCategory.subcategories) do
                        local settingsSubCategory = v
                        
                        local _, _, _, widgetName = nativeSettings.pathExists(settingsSubCategory.groupPath.value)
                        local categoryWidget = this:SpawnFromLocal(this.settingsOptionsList.widget, "settingsCategory")
                        categoryWidget:SetName(StringToName(widgetName))
                        local categoryController = categoryWidget:GetController()

                        if IsDefined(categoryController) then
                            categoryController:Setup(settingsSubCategory.label)
                        end
                        nativeSettings.populateOptions(this, settingsCategory.groupPath.value, settingsSubCategory.groupPath.value) -- Add custom options to subcategories
                    end
                    
                    nativeSettings.restoreScrollPos()
                end)

                this.selectorCtrl:SetSelectedIndex(idx)
        else
            wrapped(idx)
        end
    end)

    ObserveAfter("SettingsMainGameController", "OnSettingHoverOver", function (this, evt) -- Handle hover over description
        if nativeSettings.fromMods then
            local currentItem = evt:GetCurrentTarget():GetController()
            local data = nativeSettings.getOptionTable(currentItem)
            this.descriptionText:SetText(data.desc)
            this.descriptionText:SetVisible(true)
        end
    end)

    Observe("SettingsSelectorControllerBool", "AcceptValue", function (this) -- Handle boolean switch click
        if not nativeSettings.fromMods then return end
        local data = nativeSettings.getOptionTable(this)
        data.state = not data.state
        this.onState:SetVisible(data.state)
        this.offState:SetVisible(not data.state)
        data.callback(data.state)
    end)

    Override("SettingsSelectorControllerInt", "Refresh", function (this, wrapped) -- Handle slider drag int
        if nativeSettings.fromMods then
            local sliderController = this.sliderWidget:GetControllerByType("inkSliderController")
            local data = nativeSettings.getOptionTable(this)
            if data.currentValue == this.newValue then return end
            data.currentValue = this.newValue
            data.callback(data.currentValue)
            this.ValueText:SetText(tostring(this.newValue))
            sliderController:ChangeValue(math.floor(this.newValue))
        else
            wrapped()
        end
    end)

    Override("SettingsSelectorControllerInt", "ChangeValue", function (this, forward, wrapped) -- Handle slider int hold a/d
        if nativeSettings.fromMods then
            local data = nativeSettings.getOptionTable(this)
            if forward then
                this.newValue = this.newValue + data.step
            else
                this.newValue = this.newValue - data.step
            end
            this.newValue = math.max(math.min(data.max, this.newValue), data.min)
            this:Refresh()
        else
            wrapped(forward)
        end
    end)

    Observe("SettingsSelectorControllerInt", "AcceptValue", function (this, forward) -- Handle slider a / d int
        if not nativeSettings.fromMods then return end
        local data = nativeSettings.getOptionTable(this)
        if forward then
            this.newValue = this.newValue + data.step
        else
            this.newValue = this.newValue - data.step
        end
        this.newValue = math.max(math.min(data.max, this.newValue), data.min)
        this:Refresh()
    end)

    Override("SettingsSelectorControllerFloat", "Refresh", function (this, wrapped) -- Handle slider drag float
        if nativeSettings.fromMods then
            local sliderController = this.sliderWidget:GetControllerByType("inkSliderController")
            local data = nativeSettings.getOptionTable(this)
            if data.currentValue == this.newValue then return end
            data.currentValue = this.newValue
            data.callback(data.currentValue)
            this.ValueText:SetText(string.format(data.format, this.newValue))
            sliderController:ChangeValue(this.newValue)
        else
            wrapped()
        end
    end)

    Override("SettingsSelectorControllerFloat", "ChangeValue", function (this, forward, wrapped) -- Handle slider float hold a / d
        if nativeSettings.fromMods then
            local data = nativeSettings.getOptionTable(this)
            if forward then
                this.newValue = this.newValue + data.step
            else
                this.newValue = this.newValue - data.step
            end
            this.newValue = math.max(math.min(data.max, this.newValue), data.min)
            this:Refresh()
        else
            wrapped(forward)
        end
    end)

    Observe("SettingsSelectorControllerFloat", "AcceptValue", function (this, forward) -- Handle slider a / d float
        if not nativeSettings.fromMods then return end
        local data = nativeSettings.getOptionTable(this)
        if forward then
            this.newValue = this.newValue + data.step
        else
            this.newValue = this.newValue - data.step
        end
        this.newValue = math.max(math.min(data.max, this.newValue), data.min)
        this:Refresh()
    end)

    Observe("SettingsSelectorControllerListString", "ChangeValue", function (this, forward) -- Handle string list input
        if not nativeSettings.fromMods then return end
        local data = nativeSettings.getOptionTable(this)

        if forward then
            data.selectedElementIndex = data.selectedElementIndex + 1
        else
            data.selectedElementIndex = data.selectedElementIndex - 1
        end

        if data.selectedElementIndex > #data.elements then
            data.selectedElementIndex = 1
        elseif data.selectedElementIndex < 1 then
            data.selectedElementIndex = #data.elements
        end

        this.ValueText:SetText(tostring(data.elements[data.selectedElementIndex]))
        this:SelectDot(data.selectedElementIndex - 1)

        data.callback(data.selectedElementIndex)
    end)

    Observe('SettingsSelectorControllerBool', 'OnShortcutPress', function(this) -- Handle button widget press
        if not nativeSettings.fromMods then return end
        local data = nativeSettings.getOptionTable(this)
        if not data then return end

        if data.type ~= "button" then return end
        if nativeSettings.pressedButtons[tostring(data)] then return end

        nativeSettings.pressedButtons[tostring(data)] = true
        nativeSettings.Cron.NextTick(function ()
            nativeSettings.pressedButtons[tostring(data)] = nil
        end)

        local audioEvent = SoundPlayEvent.new() -- Play click sound
        audioEvent.soundName = "ui_menu_onpress"
        Game.GetPlayer():QueueEvent(audioEvent)

        data.callback()
    end)

    Observe('SettingsSelectorControllerKeyBinding', 'SetValue', function(this, key) -- Handle keybinding widget press
        if not nativeSettings.fromMods then return end
        local data = nativeSettings.getOptionTable(this)
        data.value = NameToString(key)
        data.controller.text:SetText(SettingsSelectorControllerKeyBinding.PrepareInputTag(data.value, "None", "None"))
        data.callback(data.value)
    end)

    Override("SettingsMainGameController", "RequestRestoreDefaults", function (this, wrapped) -- Handle reset settings
        if nativeSettings.fromMods then
            local audioEvent = SoundPlayEvent.new() -- Play click sound
            audioEvent.soundName = "ui_menu_onpress"
            Game.GetPlayer():QueueEvent(audioEvent)

            local settingsCategory = (this.data[this.selectorCtrl:GetToggledIndex() + 1].groupPath.value):gsub("/", "")
            for _, o in pairs(nativeSettings.data[settingsCategory].options) do
                if o.defaultValue then
                    nativeSettings.setOption(o, o.defaultValue)
                end
            end

            for _, sub in pairs(nativeSettings.data[settingsCategory].subcategories) do
                for _, o in pairs(sub.options) do
                    if o.defaultValue then
                        nativeSettings.setOption(o, o.defaultValue)
                    end
                end
            end
        else
            wrapped()
        end
    end)

    print("[NativeSettings] NativeSettings lib initialized!")
end)

registerForEvent("onUpdate", function(deltaTime)
    nativeSettings.Cron.Update(deltaTime)
end)

-- Functions for regular use by other mods:

function nativeSettings.addTab(path, label) -- Use this to add a new tab to the Menu. Path must look like this: "/path" ("/" followed by a simple identifier)
    path = path:gsub("/", "")

    local tab = {}
    tab.path = path
    tab.label = label
    tab.options = {}
    tab.subcategories = {}
    tab.keys = {}

    CName.add(label)
    CName.add(tostring("/" .. path))

    nativeSettings.data[path] = tab
end

function nativeSettings.addSubcategory(path, label, optionalIndex) -- Add a subcategory (Dark strip with a name) to a Tab. e.g "/path/subPath" (Path from addTab, followed by a simple identifier)
    local tabPath = path:match("/.*/"):gsub("/", "")
    local subPath = path:gsub(tabPath, ""):gsub("/", "")

    local validPath, state = nativeSettings.pathExists(tostring("/" .. tabPath))

    if not validPath or state ~= 1 then
        print(string.format("[NativeSettings] Tab path provided to the \"%s\" subcategory is not valid!", label))
        return
    end

    local category = {}
    category.path = subPath
    category.label = label
    category.options = {}

    CName.add(label)
    CName.add(path)

    nativeSettings.data[tabPath].subcategories[subPath] = category

    local idx = optionalIndex or #nativeSettings.data[tabPath].keys + 1
    table.insert(nativeSettings.data[tabPath].keys, idx, subPath)

    if nativeSettings.currentTab == tabPath then -- Handle subcategory adding when the tab is open
        local placementIndex = #nativeSettings.data[tabPath].options
        for i, settingsSubCategoryPath in pairs(nativeSettings.data[tabPath].keys) do
            if idx == i then
                break
            end
            placementIndex = placementIndex + #nativeSettings.data[tabPath].subcategories[settingsSubCategoryPath].options + 1
        end
        nativeSettings.saveScrollPos()
        local categoryWidget = nativeSettings.settingsMainController:SpawnFromLocal(nativeSettings.settingsOptionsList.widget, "settingsCategory")
        nativeSettings.settingsOptionsList.widget:ReorderChild(categoryWidget, placementIndex)
        nativeSettings.restoreScrollPos()
        categoryWidget:SetName(StringToName(subPath))
        local categoryController = categoryWidget:GetController()

        if IsDefined(categoryController) then
            categoryController:Setup(label)
        end
    end
end

function nativeSettings.removeSubcategory(path) -- Removes entire subcategory, requires path to it.
    local tabPath = path:match("/.*/"):gsub("/", "")
    local subPath = path:gsub(tabPath, ""):gsub("/", "")

    local validPath, state = nativeSettings.pathExists(tostring("/" .. tabPath))

    if not validPath or state ~= 1 then
        print(string.format("[NativeSettings] Tried to remove subcategory with invalid path: \"%s\"", path))
        return
    end

    if nativeSettings.data[tabPath].subcategories[subPath] == nil then
        return
    end

    if nativeSettings.currentTab == tabPath then -- Handle subcategory removing when the tab is open
        nativeSettings.saveScrollPos()
        inkCompoundRef.RemoveChildByName(nativeSettings.settingsOptionsList, subPath)
        for _, option in pairs(nativeSettings.data[tabPath].subcategories[subPath].options) do
            inkCompoundRef.RemoveChildByName(nativeSettings.settingsOptionsList, option.widgetName)
        end
        nativeSettings.restoreScrollPos()
    end

    nativeSettings.data[tabPath].subcategories[subPath] = nil
    nativeSettings.data[tabPath].keys[nativeSettings.getIndex(nativeSettings.data[tabPath].keys, subPath)] = nil
end

function nativeSettings.removeOption(tab) -- Remove option widget, needs option table.
    local success = false

    local _, state, tabPath, subPath = nativeSettings.pathExists(tab.fullPath)

    if state == 0 then -- From subcategory
        local i = nativeSettings.getIndex(nativeSettings.data[tabPath].subcategories[subPath].options, tab)
        if not i then return end

        if nativeSettings.currentTab == tabPath then
            local name = nativeSettings.data[tabPath].subcategories[subPath].options[i].widgetName
            nativeSettings.saveScrollPos()
            inkCompoundRef.RemoveChildByName(nativeSettings.settingsOptionsList, name)
            nativeSettings.restoreScrollPos()
        end

        nativeSettings.data[tabPath].subcategories[subPath].options[i] = nil
        table.remove(nativeSettings.data[tabPath].subcategories[subPath].options, i)
        success = true
    else -- From main tab
        local i = nativeSettings.getIndex(nativeSettings.data[tabPath].options, tab)
        if not i then return end

        if nativeSettings.currentTab == tabPath then
            local name = nativeSettings.data[tabPath].options[i].widgetName
            nativeSettings.saveScrollPos()
            inkCompoundRef.RemoveChildByName(nativeSettings.settingsOptionsList, name)
            nativeSettings.restoreScrollPos()
        end

        nativeSettings.data[tabPath].options[i] = nil
        success = true
    end

    if not success then
        print(string.format("[NativeSettings] Tried to remove option with invalid option table: \"%s\"", tab.label))
        return
    end
end

function nativeSettings.addSwitch(path, label, desc, currentState, defaultState, callback, optionalIndex) -- Call this to add a toggle switch
    local validPath, state, tabPath, subPath = nativeSettings.pathExists(path)
    local placementIndex = nativeSettings.getOptionIndexOffset(tabPath, subPath, optionalIndex)

    if not validPath then
        print(string.format("[NativeSettings] Path provided to the \"%s\" boolean switch is not valid!", label))
        return
    end

    local switch = {type = "switch", path = path, label = label, desc = desc, state = currentState, defaultValue = defaultState, callback = callback, controller = nil, fullPath = path}

    if state == 0 then -- Add to subcategory
        switch.path = subPath
        local idx = optionalIndex or #nativeSettings.data[tabPath].subcategories[subPath].options + 1
        table.insert(nativeSettings.data[tabPath].subcategories[subPath].options, idx, switch)
    else -- Add to main tab
        switch.path = tabPath
        local idx = optionalIndex or #nativeSettings.data[tabPath].options + 1
        table.insert(nativeSettings.data[tabPath].options, idx, switch)
    end

    if nativeSettings.currentTab == tabPath then
        switch.widgetName = nativeSettings.getNextOptionName()
        nativeSettings.saveScrollPos()
        nativeSettings.spawnSwitch(nativeSettings.settingsMainController, switch, placementIndex)
        nativeSettings.restoreScrollPos()
    end

    return switch
end

function nativeSettings.addRangeInt(path, label, desc, min, max, step, currentValue, defaultValue, callback, optionalIndex) -- Call this to add a range int widget
    local validPath, state, tabPath, subPath = nativeSettings.pathExists(path)
    local placementIndex = nativeSettings.getOptionIndexOffset(tabPath, subPath, optionalIndex)

    if not validPath then
        print(string.format("[NativeSettings] Path provided to the \"%s\" int slider is not valid!", label))
        return
    end

    local range = {type = "rangeInt", path = path, label = label, desc = desc, min = min, max = max, step = math.floor(step), currentValue = currentValue, defaultValue = defaultValue, callback = callback, controller = nil, fullPath = path}

    if state == 0 then -- Add to subcategory
        range.path = subPath
        local idx = optionalIndex or #nativeSettings.data[tabPath].subcategories[subPath].options + 1
        table.insert(nativeSettings.data[tabPath].subcategories[subPath].options, idx, range)
    else -- Add to main tab
        range.path = tabPath
        local idx = optionalIndex or #nativeSettings.data[tabPath].options + 1
        table.insert(nativeSettings.data[tabPath].options, idx, range)
    end

    if nativeSettings.currentTab == tabPath then
        range.widgetName = nativeSettings.getNextOptionName()
        nativeSettings.saveScrollPos()
        nativeSettings.spawnRangeInt(nativeSettings.settingsMainController, range, placementIndex)
        nativeSettings.restoreScrollPos()
    end

    return range
end

function nativeSettings.addRangeFloat(path, label, desc, min, max, step, format, currentValue, defaultValue, callback, optionalIndex) -- Call this to add a range float widget
    local validPath, state, tabPath, subPath = nativeSettings.pathExists(path)
    local placementIndex = nativeSettings.getOptionIndexOffset(tabPath, subPath, optionalIndex)

    if not validPath then
        print(string.format("[NativeSettings] Path provided to the \"%s\" float slider is not valid!", label))
        return
    end

    local range = {type = "rangeFloat", path = path, label = label, desc = desc, min = min, max = max, step = step, format = format, currentValue = currentValue, defaultValue = defaultValue, callback = callback, controller = nil, fullPath = path}

    if state == 0 then -- Add to subcategory
        range.path = subPath
        local idx = optionalIndex or #nativeSettings.data[tabPath].subcategories[subPath].options + 1
        table.insert(nativeSettings.data[tabPath].subcategories[subPath].options, idx, range)
    else -- Add to main tab
        range.path = tabPath
        local idx = optionalIndex or #nativeSettings.data[tabPath].options + 1
        table.insert(nativeSettings.data[tabPath].options, idx, range)
    end

    if nativeSettings.currentTab == tabPath then
        range.widgetName = nativeSettings.getNextOptionName()
        nativeSettings.saveScrollPos()
        nativeSettings.spawnRangeFloat(nativeSettings.settingsMainController, range, placementIndex)
        nativeSettings.restoreScrollPos()
    end

    return range
end

function nativeSettings.addSelectorString(path, label, desc, elements, selectedElementIndex, defaultSelectedElementIndex, callback, optionalIndex) -- Call this to add a string selector widget
    local validPath, state, tabPath, subPath = nativeSettings.pathExists(path)
    local placementIndex = nativeSettings.getOptionIndexOffset(tabPath, subPath, optionalIndex)

    if not validPath then
        print(string.format("[NativeSettings] Path provided to the \"%s\" string selector is not valid!", label))
        return
    end

    local selector = {type = "selectorString", path = path, label = label, desc = desc, elements = elements, selectedElementIndex = selectedElementIndex, defaultValue = defaultSelectedElementIndex, callback = callback, controller = nil, fullPath = path}

    if state == 0 then -- Add to subcategory
        selector.path = subPath
        local idx = optionalIndex or #nativeSettings.data[tabPath].subcategories[subPath].options + 1
        table.insert(nativeSettings.data[tabPath].subcategories[subPath].options, idx, selector)
    else -- Add to main tab
        selector.path = tabPath
        local idx = optionalIndex or #nativeSettings.data[tabPath].options + 1
        table.insert(nativeSettings.data[tabPath].options, idx, selector)
    end

    if nativeSettings.currentTab == tabPath then
        selector.widgetName = nativeSettings.getNextOptionName()
        nativeSettings.saveScrollPos()
        nativeSettings.spawnStringList(nativeSettings.settingsMainController, selector, placementIndex)
        nativeSettings.restoreScrollPos()
    end

    return selector
end

function nativeSettings.addButton(path, label, desc, buttonText, textSize, callback, optionalIndex) -- Call this to add a button widget
    local validPath, state, tabPath, subPath = nativeSettings.pathExists(path)
    local placementIndex = nativeSettings.getOptionIndexOffset(tabPath, subPath, optionalIndex)

    if not validPath then
        print(string.format("[NativeSettings] Path provided to the \"%s\" button is not valid!", label))
        return
    end

    local button = {type = "button", path = path, label = label, desc = desc, buttonText = buttonText, textSize = textSize, callback = callback, controller = nil, fullPath = path}

    if state == 0 then -- Add to subcategory
        button.path = subPath
        local idx = optionalIndex or #nativeSettings.data[tabPath].subcategories[subPath].options + 1
        table.insert(nativeSettings.data[tabPath].subcategories[subPath].options, idx, button)
    else -- Add to main tab
        button.path = tabPath
        local idx = optionalIndex or #nativeSettings.data[tabPath].options + 1
        table.insert(nativeSettings.data[tabPath].options, idx, button)
    end

    if nativeSettings.currentTab == tabPath then
        button.widgetName = nativeSettings.getNextOptionName()
        nativeSettings.saveScrollPos()
        nativeSettings.spawnButton(nativeSettings.settingsMainController, button, placementIndex)
        nativeSettings.restoreScrollPos()
    end

    return button
end

function nativeSettings.addKeyBinding(path, label, desc, value, defaultValue, callback, optionalIndex) -- Call this to add a key binding widget
    local validPath, state, tabPath, subPath = nativeSettings.pathExists(path)
    local placementIndex = nativeSettings.getOptionIndexOffset(tabPath, subPath, optionalIndex)

    if not validPath then
        print(string.format("[NativeSettings] Path provided to the \"%s\" key binding is not valid!", label))
        return
    end

    local keyBinding = {type = "keyBinding", path = path, label = label, desc = desc, value = value, defaultValue = defaultValue, callback = callback, controller = nil, fullPath = path}

    if state == 0 then -- Add to subcategory
        keyBinding.path = subPath
        local idx = optionalIndex or #nativeSettings.data[tabPath].subcategories[subPath].options + 1
        table.insert(nativeSettings.data[tabPath].subcategories[subPath].options, idx, keyBinding)
    else -- Add to main tab
        keyBinding.path = tabPath
        local idx = optionalIndex or #nativeSettings.data[tabPath].options + 1
        table.insert(nativeSettings.data[tabPath].options, idx, keyBinding)
    end

    if nativeSettings.currentTab == tabPath then
        keyBinding.widgetName = nativeSettings.getNextOptionName()
        nativeSettings.saveScrollPos()
        nativeSettings.spawnKeyBinding(nativeSettings.settingsMainController, keyBinding, placementIndex)
        nativeSettings.restoreScrollPos()
    end

    return keyBinding
end

function nativeSettings.pathExists(path) -- Check if a path exists, return a boolean (Other returns can be ignored). Useful if you want to have two independet mods adding their options to the same tab
    if path:match("/.*/.*") then
        local tabPath = path:match("/.*/"):gsub("/", "")
        local subPath = path:gsub(tabPath, ""):gsub("/", "")

        if nativeSettings.data[tabPath].subcategories[subPath] == nil then return false end
        return true, 0, tabPath, subPath
    elseif path:match("/.*[^/]") then
        local tabPath = path:gsub("/", "")

        if nativeSettings.data[tabPath] == nil then return false end
        return true, 1, tabPath
    else
        return false, 2
    end
end

function nativeSettings.setOption(tab, value) -- Use this to set an options value from your mod. Useful if the option gets changed from e.g. an ImGui settings ui. Requires the option table that gets returned when adding the option (addSwitch ...)
    local success = false

    for _, o in pairs(nativeSettings.getAllOptions()) do
        if o == tab then
            success = true
            if o.type == "switch" then
                if type(value) == "boolean" then
                    if o.state == value then return end
                    o.state = value
                    o.callback(o.state)
                    if o.controller then
                        o.controller.onState:SetVisible(o.state)
                        o.controller.offState:SetVisible(not o.state)
                    end
                else
                    print(string.format("[NativeSettings] Invalid data type passed for setOption \"%s\" : %s, expected: boolean", tab.label, type(value)))
                end
            elseif o.type == "rangeInt"then
                if type(value) == "number" then
                    if o.currentValue == value then return end
                    o.currentValue = value
                    o.callback(o.currentValue)
                    if o.controller then
                        o.controller.newValue = o.currentValue

                        local sliderController = o.controller.sliderWidget:GetControllerByType("inkSliderController")
                        o.controller.ValueText:SetText(tostring(o.controller.newValue))
                        sliderController:ChangeValue(math.floor(o.controller.newValue))
                    end
                else
                    print(string.format("[NativeSettings] Invalid data type passed for setOption \"%s\" : %s, expected: number", tab.label, type(value)))
                end
            elseif o.type == "rangeFloat"then
                if type(value) == "number" then
                    if o.currentValue == value then return end
                    o.currentValue = value
                    o.callback(o.currentValue)
                    if o.controller then
                        o.controller.newValue = o.currentValue

                        local sliderController = o.controller.sliderWidget:GetControllerByType("inkSliderController")
                        o.controller.ValueText:SetText(string.format(o.format, o.controller.newValue))
                        sliderController:ChangeValue(o.controller.newValue)
                    end
                else
                    print(string.format("[NativeSettings] Invalid data type passed for setOption \"%s\" : %s, expected: number", tab.label, type(value)))
                end
            elseif o.type == "selectorString"then
                if type(value) == "number" then
                    if o.selectedElementIndex == value then return end
                    local idx = math.max(1, math.min(value, #o.elements))
                    o.selectedElementIndex = value
                    o.callback(o.selectedElementIndex)
                    if o.controller then
                        o.controller.ValueText:SetText(tostring(o.elements[idx]))
                        o.controller:SelectDot(idx - 1)
                    end
                else
                    print(string.format("[NativeSettings] Invalid data type passed for setOption \"%s\" : %s, expected: number", tab.label, type(value)))
                end
            elseif o.type == "keyBinding"then
                if type(value) == "string" then
                    if o.value == value then return end
                    o.value = value
                    o.callback(o.value)
                    if o.controller then
                        o.controller.text:SetText(SettingsSelectorControllerKeyBinding.PrepareInputTag(value, "None", "None"))
                    end
                else
                    print(string.format("[NativeSettings] Invalid data type passed for setOption \"%s\" : %s, expected: string", tab.label, type(value)))
                end
            end
        end
    end

    if not success then print(string.format("[NativeSettings] Could not set the option for \"%s\" correctly, the provided options table could not be found!", tab.label)) end
end

function nativeSettings.refresh() -- Refreshes the UI, e.g. after adding / removing widgets. Not needed anymore as of version 1.4
    if not nativeSettings.fromMods then return end
    if not nativeSettings.settingsMainController then return end
    nativeSettings.clearControllers()
    nativeSettings.settingsMainController:PopulateSettingsData()
    nativeSettings.settingsMainController:PopulateCategorySettingsOptions(-1)
end

------------- Mod functions, no need to touch those --------------------------

function nativeSettings.populateOptions(this, categoryPath, subCategoryPath) -- Select right widget to spawn
    if subCategoryPath then
        local _, _, _, subCategoryPath = nativeSettings.pathExists(subCategoryPath)
        for _, option in pairs(nativeSettings.data[categoryPath:gsub("/", "")].subcategories[subCategoryPath].options) do
            option.widgetName = nativeSettings.getNextOptionName()
            if option.type == "switch" then
                nativeSettings.spawnSwitch(this, option)
            elseif option.type == "rangeInt" then
                nativeSettings.spawnRangeInt(this, option)
            elseif option.type == "rangeFloat" then
                nativeSettings.spawnRangeFloat(this, option)
            elseif option.type == "selectorString" then
                nativeSettings.spawnStringList(this, option)
            elseif option.type == "button" then
                nativeSettings.spawnButton(this, option)
            elseif option.type == "keyBinding" then
                nativeSettings.spawnKeyBinding(this, option)
            end
        end
    else
        for _, option in pairs(nativeSettings.data[categoryPath:gsub("/", "")].options) do
            option.widgetName = nativeSettings.getNextOptionName()
            if option.type == "switch" then
                nativeSettings.spawnSwitch(this, option)
            elseif option.type == "rangeInt" then
                nativeSettings.spawnRangeInt(this, option)
            elseif option.type == "rangeFloat" then
                nativeSettings.spawnRangeFloat(this, option)
            elseif option.type == "selectorString" then
                nativeSettings.spawnStringList(this, option)
            elseif option.type == "button" then
                nativeSettings.spawnButton(this, option)
            elseif option.type == "keyBinding" then
                nativeSettings.spawnKeyBinding(this, option)
            end
        end
    end
end

function nativeSettings.spawnRangeInt(this, option, idx)
    local widget = this:SpawnFromLocal(this.settingsOptionsList.widget, "settingsSelectorInt")
    widget:SetName(StringToName(option.widgetName))
    local currentItem = widget:GetController()

    if idx ~= nil then
        this.settingsOptionsList.widget:ReorderChild(widget, idx)
    end

    currentItem.LabelText:SetText(option.label)
    currentItem:RegisterToCallback("OnHoverOver", this, "OnSettingHoverOver")
    currentItem:RegisterToCallback("OnHoverOut", this, "OnSettingHoverOut")

    currentItem.sliderController = currentItem.sliderWidget:GetControllerByType("inkSliderController")
    currentItem.sliderController:Setup(option.min, option.max, option.currentValue, option.step)
    currentItem.sliderController:RegisterToCallback("OnSliderValueChanged", currentItem, "OnSliderValueChanged")
    currentItem.sliderController:RegisterToCallback("OnSliderHandleReleased", currentItem, "OnHandleReleased")
    currentItem.newValue = option.currentValue
    currentItem.ValueText:SetText(tostring(option.currentValue))

    this.settingsElements = nativeSettings.nativeInsert(this.settingsElements, currentItem)

    option.controller = currentItem
end

function nativeSettings.spawnRangeFloat(this, option, idx)
    local widget = this:SpawnFromLocal(this.settingsOptionsList.widget, "settingsSelectorFloat")
    widget:SetName(StringToName(option.widgetName))
    local currentItem = widget:GetController()

    if idx ~= nil then
        this.settingsOptionsList.widget:ReorderChild(widget, idx)
    end

    currentItem.LabelText:SetText(option.label)
    currentItem:RegisterToCallback("OnHoverOver", this, "OnSettingHoverOver")
    currentItem:RegisterToCallback("OnHoverOut", this, "OnSettingHoverOut")

    currentItem.sliderController = currentItem.sliderWidget:GetControllerByType("inkSliderController")
    currentItem.sliderController:Setup(option.min, option.max, option.currentValue, option.step)
    currentItem.sliderController:RegisterToCallback("OnSliderValueChanged", currentItem, "OnSliderValueChanged")
    currentItem.sliderController:RegisterToCallback("OnSliderHandleReleased", currentItem, "OnHandleReleased")
    currentItem.newValue = option.currentValue
    currentItem.ValueText:SetText(string.format(option.format, option.currentValue))

    this.settingsElements = nativeSettings.nativeInsert(this.settingsElements, currentItem)

    option.controller = currentItem
end

function nativeSettings.spawnStringList(this, option, idx)
    local widget = this:SpawnFromLocal(this.settingsOptionsList.widget, "settingsSelectorStringList")
    widget:SetName(StringToName(option.widgetName))
    local currentItem = widget:GetController()

    if idx ~= nil then
        this.settingsOptionsList.widget:ReorderChild(widget, idx)
    end

    currentItem.LabelText:SetText(option.label)
    currentItem:RegisterToCallback("OnHoverOver", this, "OnSettingHoverOver")
    currentItem:RegisterToCallback("OnHoverOut", this, "OnSettingHoverOut")

    currentItem:PopulateDots(#option.elements)
    currentItem:SelectDot(option.selectedElementIndex - 1)

    currentItem.ValueText:SetText(option.elements[option.selectedElementIndex])

    this.settingsElements = nativeSettings.nativeInsert(this.settingsElements, currentItem)

    option.controller = currentItem
end

function nativeSettings.spawnSwitch(this, option, idx)
    local widget = this:SpawnFromLocal(this.settingsOptionsList.widget, "settingsSelectorBool")
    widget:SetName(StringToName(option.widgetName))
    local currentItem = widget:GetController()

    if idx ~= nil then
        this.settingsOptionsList.widget:ReorderChild(widget, idx)
    end

    currentItem.LabelText:SetText(option.label)
    currentItem.onState:SetVisible(option.state)
    currentItem.offState:SetVisible(not option.state)
    currentItem:RegisterToCallback("OnHoverOver", this, "OnSettingHoverOver")
    currentItem:RegisterToCallback("OnHoverOut", this, "OnSettingHoverOut")
    this.settingsElements = nativeSettings.nativeInsert(this.settingsElements, currentItem)

    option.controller = currentItem
end

function nativeSettings.spawnButton(this, option, idx)
    local widget = this:SpawnFromLocal(this.settingsOptionsList.widget, "settingsSelectorBool")
    widget:SetName(StringToName(option.widgetName))
    local currentItem = widget:GetController()

    if idx ~= nil then
        this.settingsOptionsList.widget:ReorderChild(widget, idx)
    end

    currentItem.LabelText:SetText(option.label)
    currentItem.onState:SetVisible(false)
    currentItem.offState:SetVisible(false)
    currentItem:RegisterToCallback("OnHoverOver", this, "OnSettingHoverOver")
    currentItem:RegisterToCallback("OnHoverOut", this, "OnSettingHoverOut")

    local anchor = inkCanvas.new()
    anchor:SetAnchorPoint(Vector2.new({ X = 0.5, Y = 0.5 }))
    anchor:SetInteractive(true)
    anchor:SetMargin(inkMargin.new({ left = 760.0, top = 38.0, right = 0.0, bottom = 0.0 }))
    anchor:Reparent(currentItem:GetRootWidget():GetWidgetByPath(BuildWidgetPath({ 'layout', "container"})), -1)

    local text = inkText.new()
    text:SetFontFamily('base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily')
    text:SetFontStyle('Medium')
    text:SetFontSize(option.textSize)
    text:SetLetterCase(textLetterCase.OriginalCase)
    text:SetTintColor(HDRColor.new({ Red = 1.1761, Green = 0.3809, Blue = 0.3476, Alpha = 1.0 }))
    text:SetAnchor(inkEAnchor.Fill)
    text:SetHorizontalAlignment(textHorizontalAlignment.Center)
    text:SetVerticalAlignment(textVerticalAlignment.Center)
    text:SetText(option.buttonText)
    text:Reparent(anchor, -1)

    this.settingsElements = nativeSettings.nativeInsert(this.settingsElements, currentItem)

    option.controller = currentItem
end

function nativeSettings.spawnKeyBinding(this, option, idx)
    local widget = this:SpawnFromLocal(this.settingsOptionsList.widget, "settingsSelectorKeyBinding")
    widget:SetName(StringToName(option.widgetName))
    local currentItem = widget:GetController()

    if idx ~= nil then
        this.settingsOptionsList.widget:ReorderChild(widget, idx)
    end

    currentItem.LabelText:SetText(option.label)
    currentItem:RegisterToCallback("OnHoverOver", this, "OnSettingHoverOver")
    currentItem:RegisterToCallback("OnHoverOut", this, "OnSettingHoverOut")
    currentItem.text:SetText(SettingsSelectorControllerKeyBinding.PrepareInputTag(option.value, "None", "None"))

    this.settingsElements = nativeSettings.nativeInsert(this.settingsElements, currentItem)

    option.controller = currentItem
end

function nativeSettings.nativeInsert(nTable, value)
    local t = nTable
    table.insert(t, value)

    return t
end

function nativeSettings.getIndex(tab, val)
    local index = nil
    for i, v in pairs(tab) do
        if v == val then
            index = i
        end
    end
    return index
end

function nativeSettings.isSameInstance(a, b) -- Credits to psiberx for this
    return Game['OperatorEqual;IScriptableIScriptable;Bool'](a, b)
end

function nativeSettings.getOptionTable(optionController)
    for _, tab in pairs(nativeSettings.data) do
        for _, o in pairs(tab.options) do
            if nativeSettings.isSameInstance(o.controller, optionController) then
                return o
            end
        end

        for _, sub in pairs(tab.subcategories) do
            for _, o in pairs(sub.options) do
                if nativeSettings.isSameInstance(o.controller, optionController) then
                    return o
                end
            end
        end
    end
end

function nativeSettings.getAllOptions()
    local all = {}

    for _, tab in pairs(nativeSettings.data) do
        for _, o in pairs(tab.options) do
            table.insert(all, o)
        end

        for _, sub in pairs(tab.subcategories) do
            for _, o in pairs(sub.options) do
                table.insert(all, o)
            end
        end
    end

    return all
end

function nativeSettings.clearControllers() -- Prevent crashes by releasing it from memory (I guess)
    for _, option in pairs(nativeSettings.getAllOptions()) do
        option.controller = nil
    end
    nativeSettings.currentTab = ''
end

function nativeSettings.getNextOptionName() -- Generate unique names for widgets
    local name = 'option_' .. nativeSettings.optionCount
    nativeSettings.optionCount = nativeSettings.optionCount + 1
    return name
end

function nativeSettings.getOptionIndexOffset(tabPath, subPath, optionalIndex)
    local placementIndex
    if subPath ~= nil then -- Add to subcategory
        local idx = optionalIndex or #nativeSettings.data[tabPath].subcategories[subPath].options + 1
        placementIndex = #nativeSettings.data[tabPath].options + idx
        for _, settingsSubCategoryPath in pairs(nativeSettings.data[tabPath].keys) do
            if settingsSubCategoryPath == subPath then
                break
            end
            placementIndex = placementIndex + #nativeSettings.data[tabPath].subcategories[settingsSubCategoryPath].options + 1
        end
    else -- Add to main tab
        placementIndex = optionalIndex or #nativeSettings.data[tabPath].options
        placementIndex = math.min(placementIndex, #nativeSettings.data[tabPath].options)
    end
    return placementIndex
end

function nativeSettings.saveScrollPos()
    local scrollArea = nativeSettings.settingsMainController:GetRootWidget():GetWidget(StringToName("wrapper/wrapper/MainScrollingArea/scroll_area"))
    nativeSettings.oldScrollPos = scrollArea:GetVerticalScrollPosition() * scrollArea:GetContentSize().Y
end

function nativeSettings.restoreScrollPos()
    nativeSettings.Cron.NextTick(function()
        local scrollArea = nativeSettings.settingsMainController:GetRootWidget():GetWidget(StringToName("wrapper/wrapper/MainScrollingArea/scroll_area"))
        local newPos = nativeSettings.oldScrollPos / scrollArea:GetContentSize().Y
        local mainScrollArea = nativeSettings.settingsMainController:GetRootWidget():GetWidget(StringToName("wrapper/wrapper/MainScrollingArea"))
        mainScrollArea:GetController():SetScrollPosition(newPos)
    end)
end

return nativeSettings