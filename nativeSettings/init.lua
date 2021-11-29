local nativeSettings = {
    data = {},
    fromMods = false,
    minCETVersion = 1.18001
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

        local rootWidget = this:GetRootCompoundWidget()
		local button = rootWidget:GetWidgetByPath(BuildWidgetPath({ 'wrapper', 'extra', "controller_btn"}))
        button:SetVisible(false)

        local button = rootWidget:GetWidgetByPath(BuildWidgetPath({ 'wrapper', 'extra', "brightness_btn"}))
        button:SetVisible(false)

        local button = rootWidget:GetWidgetByPath(BuildWidgetPath({ 'wrapper', 'extra', "hdr_btn"}))
        button:SetVisible(false)
    end)

    Override("SettingsMainGameController", "ShowBrightnessScreen", function(_, wrapped) -- Disable brightness button functionality
        if nativeSettings.fromMods then return end
        wrapped()
    end)

    Observe("gameuiMenuItemListGameController", "AddMenuItem", function (this, label) -- Add "Mods" menu button
        if label == "Additional Content" then
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
            inkTextRef.SetText(this.label, labelString)
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

                for _, sub in pairs(tab.subcategories) do
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

            this.settingsElements = {}
            inkCompoundRef.RemoveAllChildren(this.settingsOptionsList)
            inkWidgetRef.SetVisible(this.descriptionText, false)

            if idx < 0 then
                idx = this.selectorCtrl:GetToggledIndex()
            end

            local settingsCategory = this.data[idx + 1]

            nativeSettings.clearControllers()
            nativeSettings.populateOptions(this, settingsCategory.groupPath.value) -- Add custom options to tab, no subcategory

            for _, v in pairs(settingsCategory.subcategories) do
                local settingsSubCategory = v
                local categoryController = this:SpawnFromLocal(inkWidgetRef.Get(this.settingsOptionsList), "settingsCategory"):GetController()
                if IsDefined(categoryController) then
                    categoryController:Setup(settingsSubCategory.label)
                end
                nativeSettings.populateOptions(this, settingsCategory.groupPath.value, settingsSubCategory.groupPath.value) -- Add custom options to subcategories
            end
            this.selectorCtrl:SetSelectedIndex(idx)
        else
            wrapped(idx)
        end
    end)

    ObserveAfter("SettingsMainGameController", "OnSettingHoverOver", function (this, evt) -- Handle hover over description
        if nativeSettings.fromMods then
            local currentItem = evt:GetCurrentTarget():GetController()
            local data = nativeSettings.getOptionTable(currentItem)
            inkTextRef.SetText(this.descriptionText, data.desc)
            inkWidgetRef.SetVisible(this.descriptionText, true)
        end
    end)

    Observe("SettingsSelectorControllerBool", "AcceptValue", function (this) -- Handle boolean switch click
        if not nativeSettings.fromMods then return end
        local data = nativeSettings.getOptionTable(this)
        data.state = not data.state
        inkWidgetRef.SetVisible(this.onState, data.state)
        inkWidgetRef.SetVisible(this.offState, not data.state)
        data.callback(data.state)
    end)

    Override("SettingsSelectorControllerInt", "Refresh", function (this, wrapped) -- Handle slider drag int
        if nativeSettings.fromMods then
            local sliderController = inkWidgetRef.GetControllerByType(this.sliderWidget, "inkSliderController")
            local data = nativeSettings.getOptionTable(this)
            data.currentValue = this.newValue
            data.callback(data.currentValue)
            inkTextRef.SetText(this.ValueText, tostring(this.newValue))
            sliderController:ChangeValue(math.floor(this.newValue))
        else
            wrapped()
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
            local sliderController = inkWidgetRef.GetControllerByType(this.sliderWidget, "inkSliderController")
            local data = nativeSettings.getOptionTable(this)
            data.currentValue = this.newValue
            data.callback(data.currentValue)
            inkTextRef.SetText(this.ValueText, string.format(data.format, this.newValue))
            sliderController:ChangeValue(this.newValue)
        else
            wrapped()
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

        inkTextRef.SetText(this.ValueText, tostring(data.elements[data.selectedElementIndex]))
        this:SelectDot(data.selectedElementIndex - 1)

        data.callback(data.selectedElementIndex)
    end)

    Override("SettingsMainGameController", "RequestRestoreDefaults", function (this, wrapped) -- Handle reset settings
        if nativeSettings.fromMods then
            local audioEvent = SoundPlayEvent.new()
            audioEvent = SoundPlayEvent.new ()
            audioEvent.soundName = "ui_menu_onpress"
            Game.GetPlayer():QueueEvent(audioEvent) -- Play click sound

            local settingsCategory = (this.data[this.selectorCtrl:GetToggledIndex() + 1].groupPath.value):gsub("/", "")
            for _, o in pairs(nativeSettings.data[settingsCategory].options) do
                nativeSettings.setOption(o, o.defaultValue)
            end

            for _, sub in pairs(nativeSettings.data[settingsCategory].subcategories) do
                for _, o in pairs(sub.options) do
                    nativeSettings.setOption(o, o.defaultValue)
                end
            end
        else
            wrapped()
        end
    end)

    print("[NativeSettings] NativeSettings lib initialized!")
end)

-- Functions for regular use by other mods:

function nativeSettings.addTab(path, label) -- Use this to add a new tab to the Menu. Path must look like this: "/path" ("/" followed by a simple identifier)
    path = path:gsub("/", "")

    local tab = {}
    tab.path = path
    tab.label = label
    tab.options = {}
    tab.subcategories = {}

    CName.add(label)
    CName.add(tostring("/" .. path))

    nativeSettings.data[path] = tab
end

function nativeSettings.addSubcategory(path, label) -- Add a subcategory (Dark strip with a name) to a Tab. e.g "/path/subPath" (Path from addTab, followed by a simple identifier)
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
end

function nativeSettings.addSwitch(path, label, desc, currentState, defaultState, callback) -- Call this to add a toggle switch
    local validPath, state, tabPath, subPath = nativeSettings.pathExists(path)

    if not validPath then
        print(string.format("[NativeSettings] Path provided to the \"%s\" boolean switch is not valid!", label))
        return
    end

    local switch = {type = "switch", path = path, label = label, desc = desc, state = currentState, defaultValue = defaultState, callback = callback, controller = nil}

    if state == 0 then -- Add to subcategory
        switch.path = subPath
        table.insert(nativeSettings.data[tabPath].subcategories[subPath].options, switch)
    else -- Add to main tab
        switch.path = tabPath
        table.insert(nativeSettings.data[tabPath].options, switch)
    end

    return switch
end

function nativeSettings.addRangeInt(path, label, desc, min, max, step, currentValue, defaultValue, callback)
    local validPath, state, tabPath, subPath = nativeSettings.pathExists(path)

    if not validPath then
        print(string.format("[NativeSettings] Path provided to the \"%s\" int slider is not valid!", label))
        return
    end

    local range = {type = "rangeInt", path = path, label = label, desc = desc, min = min, max = max, step = math.floor(step), currentValue = currentValue, defaultValue = defaultValue, callback = callback, controller = nil}

    if state == 0 then -- Add to subcategory
        range.path = subPath
        table.insert(nativeSettings.data[tabPath].subcategories[subPath].options, range)
    else -- Add to main tab
        range.path = tabPath
        table.insert(nativeSettings.data[tabPath].options, range)
    end

    return range
end

function nativeSettings.addRangeFloat(path, label, desc, min, max, step, format, currentValue, defaultValue, callback)
    local validPath, state, tabPath, subPath = nativeSettings.pathExists(path)

    if not validPath then
        print(string.format("[NativeSettings] Path provided to the \"%s\" float slider is not valid!", label))
        return
    end

    local range = {type = "rangeFloat", path = path, label = label, desc = desc, min = min, max = max, step = step, format = format, currentValue = currentValue, defaultValue = defaultValue, callback = callback, controller = nil}

    if state == 0 then -- Add to subcategory
        range.path = subPath
        table.insert(nativeSettings.data[tabPath].subcategories[subPath].options, range)
    else -- Add to main tab
        range.path = tabPath
        table.insert(nativeSettings.data[tabPath].options, range)
    end

    return range
end

function nativeSettings.addSelectorString(path, label, desc, elements, selectedElementIndex, defaultSelectedElementIndex, callback)
    local validPath, state, tabPath, subPath = nativeSettings.pathExists(path)

    if not validPath then
        print(string.format("[NativeSettings] Path provided to the \"%s\" string selector is not valid!", label))
        return
    end

    local selector = {type = "selectorString", path = path, label = label, desc = desc, elements = elements, selectedElementIndex = selectedElementIndex, defaultValue = defaultSelectedElementIndex, callback = callback, controller = nil}

    if state == 0 then -- Add to subcategory
        selector.path = subPath
        table.insert(nativeSettings.data[tabPath].subcategories[subPath].options, selector)
    else -- Add to main tab
        selector.path = tabPath
        table.insert(nativeSettings.data[tabPath].options, selector)
    end

    return selector
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
                    o.state = value
                    o.callback(o.state)
                    if o.controller then
                        inkWidgetRef.SetVisible(o.controller.onState, o.state)
                        inkWidgetRef.SetVisible(o.controller.offState, not o.state)
                    end
                else
                    print(string.format("[NativeSettings] Invalid data type passed for setOption \"%s\" : %s, expected: boolean", tab.label, type(value)))
                end
            elseif o.type == "rangeInt"then
                if type(value) == "number" then
                    o.currentValue = value
                    if o.controller then
                        o.controller.newValue = o.currentValue
                        o.controller:Refresh()
                    end
                else
                    print(string.format("[NativeSettings] Invalid data type passed for setOption \"%s\" : %s, expected: number", tab.label, type(value)))
                end
            elseif o.type == "rangeFloat"then
                if type(value) == "number" then
                    o.currentValue = value
                    if o.controller then
                        o.controller.newValue = o.currentValue
                        o.controller:Refresh()
                    end
                else
                    print(string.format("[NativeSettings] Invalid data type passed for setOption \"%s\" : %s, expected: number", tab.label, type(value)))
                end
            elseif o.type == "selectorString"then
                if type(value) == "number" then
                    local idx = math.max(1, math.min(value, #o.elements))
                    o.selectedElementIndex = value
                    o.callback(o.selectedElementIndex)
                    if o.controller then
                        inkTextRef.SetText(o.controller.ValueText, tostring(o.elements[idx]))
                        o.controller:SelectDot(idx - 1)
                    end
                else
                    print(string.format("[NativeSettings] Invalid data type passed for setOption \"%s\" : %s, expected: number", tab.label, type(value)))
                end
            end
        end
    end

    if not success then print(string.format("[NativeSettings] Could not set the option for \"%s\" correctly, the provided options table could not be found!", tab.label)) end
end

------------- Mod functions, no need to touch those --------------------------

function nativeSettings.populateOptions(this, categoryPath, subCategoryPath) -- Select right widget to spawn
    if subCategoryPath then
        local _, _, _, subCategoryPath = nativeSettings.pathExists(subCategoryPath)
        for _, option in pairs(nativeSettings.data[categoryPath:gsub("/", "")].subcategories[subCategoryPath].options) do
            if option.type == "switch" then
                nativeSettings.spawnSwitch(this, option)
            elseif option.type == "rangeInt" then
                nativeSettings.spawnRangeInt(this, option)
            elseif option.type == "rangeFloat" then
                nativeSettings.spawnRangeFloat(this, option)
            elseif option.type == "selectorString" then
                nativeSettings.spawnStringList(this, option)
            end
        end
    else
        for _, option in pairs(nativeSettings.data[categoryPath:gsub("/", "")].options) do
            if option.type == "switch" then
                nativeSettings.spawnSwitch(this, option)
            elseif option.type == "rangeInt" then
                nativeSettings.spawnRangeInt(this, option)
            elseif option.type == "rangeFloat" then
                nativeSettings.spawnRangeFloat(this, option)
            elseif option.type == "selectorString" then
                nativeSettings.spawnStringList(this, option)
            end
        end
    end
end

function nativeSettings.spawnRangeInt(this, option)
    local currentItem = this:SpawnFromLocal(inkWidgetRef.Get(this.settingsOptionsList), "settingsSelectorInt"):GetController()
    currentItem.LabelText:SetText(option.label)
    currentItem:RegisterToCallback("OnHoverOver", this, "OnSettingHoverOver")
    currentItem:RegisterToCallback("OnHoverOut", this, "OnSettingHoverOut")

    currentItem.sliderController = inkWidgetRef.GetControllerByType(currentItem.sliderWidget, "inkSliderController")
    currentItem.sliderController:Setup(option.min, option.max, option.currentValue, option.step)
    currentItem.sliderController:RegisterToCallback("OnSliderValueChanged", currentItem, "OnSliderValueChanged")
    currentItem.sliderController:RegisterToCallback("OnSliderHandleReleased", currentItem, "OnHandleReleased")
    currentItem.newValue = option.currentValue
    inkTextRef.SetText(currentItem.ValueText, tostring(option.currentValue))

    this.settingsElements = nativeSettings.nativeInsert(this.settingsElements, currentItem)

    option.controller = currentItem
end

function nativeSettings.spawnRangeFloat(this, option)
    local currentItem = this:SpawnFromLocal(inkWidgetRef.Get(this.settingsOptionsList), "settingsSelectorFloat"):GetController()
    currentItem.LabelText:SetText(option.label)
    currentItem:RegisterToCallback("OnHoverOver", this, "OnSettingHoverOver")
    currentItem:RegisterToCallback("OnHoverOut", this, "OnSettingHoverOut")

    currentItem.sliderController = inkWidgetRef.GetControllerByType(currentItem.sliderWidget, "inkSliderController")
    currentItem.sliderController:Setup(option.min, option.max, option.currentValue, option.step)
    currentItem.sliderController:RegisterToCallback("OnSliderValueChanged", currentItem, "OnSliderValueChanged")
    currentItem.sliderController:RegisterToCallback("OnSliderHandleReleased", currentItem, "OnHandleReleased")
    currentItem.newValue = option.currentValue
    inkTextRef.SetText(currentItem.ValueText, string.format(option.format, option.currentValue))

    this.settingsElements = nativeSettings.nativeInsert(this.settingsElements, currentItem)

    option.controller = currentItem
end

function nativeSettings.spawnStringList(this, option)
    local currentItem = this:SpawnFromLocal(inkWidgetRef.Get(this.settingsOptionsList), "settingsSelectorStringList"):GetController()

    currentItem.LabelText:SetText(option.label)
    currentItem:RegisterToCallback("OnHoverOver", this, "OnSettingHoverOver")
    currentItem:RegisterToCallback("OnHoverOut", this, "OnSettingHoverOut")

    currentItem:PopulateDots(#option.elements)
    currentItem:SelectDot(option.selectedElementIndex - 1)

    inkTextRef.SetText(currentItem.ValueText, option.elements[option.selectedElementIndex])

    this.settingsElements = nativeSettings.nativeInsert(this.settingsElements, currentItem)

    option.controller = currentItem
end

function nativeSettings.spawnSwitch(this, option)
    local currentItem = this:SpawnFromLocal(inkWidgetRef.Get(this.settingsOptionsList), "settingsSelectorBool"):GetController()
    currentItem.LabelText:SetText(option.label)
    inkWidgetRef.SetVisible(currentItem.onState, option.state)
    inkWidgetRef.SetVisible(currentItem.offState, not option.state)
    currentItem:RegisterToCallback("OnHoverOver", this, "OnSettingHoverOver")
    currentItem:RegisterToCallback("OnHoverOut", this, "OnSettingHoverOut")
    this.settingsElements = nativeSettings.nativeInsert(this.settingsElements, currentItem)

    option.controller = currentItem
end

function nativeSettings.nativeInsert(nTable, value)
    local t = nTable
    table.insert(t, value)

    return t
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
end

return nativeSettings