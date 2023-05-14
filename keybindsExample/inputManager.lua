local holdTime = 0.5

local input = {
    listeningKeybindWidget = nil,
    inputListener = nil,
    bindings = {},
    activeKeys = {},
    nuiTables = {}
}

local function handleInput(event)
    local key = event:GetKey().value
    local action = event:GetAction().value

    if input.listeningKeybindWidget and key:find("IK_Pad") and action == "IACT_Release" then -- OnKeyBindingEvent has to be called manually for gamepad inputs, while there is a keybind widget listening for input
        input.listeningKeybindWidget:OnKeyBindingEvent(KeyBindingEvent.new({keyName = key}))
        input.listeningKeybindWidget = nil
    elseif input.listeningKeybindWidget and action == "IACT_Release" then -- Key was bound, by keyboard
        input.listeningKeybindWidget = nil
    end

    if action == "IACT_Press" then
        input.activeKeys[key] = 0
    else
        input.activeKeys[key] = nil
    end
end

function input.onInit()
    Observe("SettingsSelectorControllerKeyBinding", "ListenForInput", function(this) -- A keybind widget is listening for input, so should we (Since gamepad inputs are not sent to the native OnKeyBindingEvent by default)
        input.listeningKeybindWidget = this
    end)

    input.inputListener = NewProxy({
        OnKeyInput = { -- https://github.com/psiberx/cp2077-codeware/wiki#game-events
            args = {'whandle:KeyInputEvent'},
            callback = handleInput
        }
    })

    ObserveBefore("PlayerPuppet", "OnGameAttached", function()
        Game.GetCallbackSystem():UnregisterCallback("Input/Key", input.inputListener:Target())
        Game.GetCallbackSystem():RegisterCallback("Input/Key", input.inputListener:Target(), input.inputListener:Function("OnKeyInput"))
    end)

    ObserveBefore("PlayerPuppet", "OnDetach", function()
        Game.GetCallbackSystem():UnregisterCallback("Input/Key", input.inputListener:Target())
    end)

    Game.GetCallbackSystem():RegisterCallback("Input/Key", input.inputListener:Target(), input.inputListener:Function("OnKeyInput"))
end

function input.onUpdate(deltaTime)
    for key, time in pairs(input.activeKeys) do -- Update hold times
        input.activeKeys[key] = time + deltaTime
    end

    for _, binding in pairs(input.bindings) do
        local allPressed = true
        for _, keyInfo in pairs(binding.keys) do
            if not input.activeKeys[keyInfo[1]] or (input.activeKeys[keyInfo[1]] and keyInfo[2] and not (input.activeKeys[keyInfo[1]] > holdTime)) then
                allPressed = false
                break
            end
        end

        if allPressed then
            for _, key in pairs(binding.keys) do
                input.activeKeys[key[1]] = nil
            end
            binding.callback()
        end
    end
end

function input.onShutdown()
    Game.GetCallbackSystem():UnregisterCallback("Input/Key", input.inputListener:Target())
end

--- Create an info table to be filled, or from given parameters
---@param nativeSettingsPath string
---@param keybindLabel string
---@param isHoldLabel string
---@param keybindDescription string
---@param isHoldDescription string
---@param id string
---@param maxKeys number
---@param maxKeysLabel string
---@param maxKeysDescription string
---@param supportsHold boolean
---@param defaultOptions table
---@param savedOptions table
---@param callback function
---@param saveCallback function
---@return table
function input.createBindingInfo(nativeSettingsPath, keybindLabel, isHoldLabel, keybindDescription, isHoldDescription, id, maxKeys, maxKeysLabel, maxKeysDescription, supportsHold, defaultOptions, savedOptions, callback, saveCallback)
    local info = {
        nativeSettingsPath = nativeSettingsPath or "",
        keybindLabel = keybindLabel or "",
        isHoldLabel = isHoldLabel or "",
        keybindDescription = keybindDescription or "",
        isHoldDescription = isHoldDescription or "",
        id = id or "",
        maxKeys = maxKeys or 1,
        maxKeysLabel = maxKeysLabel or "",
        maxKeysDescription = maxKeysDescription or "",
        supportsHold = supportsHold or false,
        defaultOptions = defaultOptions or {},
        savedOptions = savedOptions or {},
        callback = callback,
        saveCallback = saveCallback
    }

    return info
end

local function addKeybind(info, index, nativeSettings) -- Add single keybind widget
    local numberText = info.maxKeys ~= 1 and " " .. index or ""
    local holdID = info.id .. "_hold_" .. index
    local numID = info.id .. "_" .. index

    if not info.savedOptions[numID] then info.savedOptions[numID] = info.defaultOptions[numID] end
    if not info.savedOptions[holdID] then info.savedOptions[holdID] = info.defaultOptions[holdID] end

    input.bindings[info.id]["keys"][index] = {
        [1] = info.savedOptions[numID], -- Key code
        [2] = info.savedOptions[holdID] -- Is hold
    }

    if info.supportsHold then
        input.nuiTables[holdID] = nativeSettings.addSwitch(info.nativeSettingsPath, info.isHoldLabel .. numberText, info.isHoldDescription, info.savedOptions[holdID], info.defaultOptions[holdID], function(state)
            input.nuiTables[numID].isHold = state -- Update isHold value for nui
            nativeSettings.setOption(input.nuiTables[numID], input.nuiTables[numID].value) -- Force update to see change visually
            input.bindings[info.id]["keys"][index][2] = state
            info.saveCallback(holdID, state)
        end)
    end

    input.nuiTables[numID] = nativeSettings.addKeyBinding(info.nativeSettingsPath, info.keybindLabel .. numberText, info.keybindDescription, info.savedOptions[numID], info.defaultOptions[numID], info.savedOptions[holdID], function(key)
        input.bindings[info.id]["keys"][index][1] = key
        info.saveCallback(numID, key)
    end)
end

function input.addNativeSettingsBinding(info) -- Add combined hotkey widget from info table
    local nativeSettings = GetMod("nativeSettings")

    if not nativeSettings.pathExists(info.nativeSettingsPath) then print("[InputManager] Invalid path for binding \"" .. info.id .. "\"") return end
    if not info.savedOptions then info.savedOptions = info.defaultOptions end -- Fallback to default options
    input.bindings[info.id] = {callback = info.callback, keys = {}} -- Binding information contains callback and keys with hold+key data

    local maxID = info.id .. "_keys"
    if not info.savedOptions[maxID] then info.savedOptions[maxID] = info.defaultOptions[maxID] end

    if info.maxKeys ~= 1 then -- Add slider to change amount of key widgets
        nativeSettings.addRangeInt(info.nativeSettingsPath, info.maxKeysLabel, info.maxKeysDescription, 1, info.maxKeys, 1, info.savedOptions[maxID], info.defaultOptions[maxID], function(value)
            info.saveCallback(maxID, value)

            for i = value + 1, info.maxKeys do -- Remove keys
                if input.nuiTables[info.id .. "_" .. i] then
                    nativeSettings.removeOption(input.nuiTables[info.id .. "_" .. i])
                    input.nuiTables[info.id .. "_" .. i] = nil
                    input.bindings[info.id]["keys"][i] = nil

                    if input.nuiTables[info.id .. "_hold_" .. i] then
                        nativeSettings.removeOption(input.nuiTables[info.id .. "_hold_" .. i])
                        input.nuiTables[info.id .. "_hold_" .. i] = nil
                    end
                end
            end

            for i = 1, value do -- Add keys
                if not input.nuiTables[info.id .. "_" .. i] then
                    addKeybind(info, i, nativeSettings)
                end
            end
        end)

    end

    for i = 1, info.savedOptions[maxID] do
        addKeybind(info, i, nativeSettings)
    end
end

return input