-- Requires Codeware (https://github.com/psiberx/cp2077-codeware), config.lua and inputManager.lua to work

local config = require("config")

local multi = {
    settings = {},

    -- Settings tables:
    -- "id"_"numberOfKey" = The keycode of the binding with ID's key with said index
    -- "id"_hold_"numberOfKey" = Is the binding with this ID and the key with the number being a hold down key?
    -- "id"_keys = The number of keys that are being used for the binding of ID

    defaultSettings = { -- Default settings
        keyboard = {
            ["mkbBinding_1"] = "IK_F1", -- Key 1' keycode of the "mkbBinding"
            ["mkbBinding_2"] = "IK_F2",
            ["mkbBinding_hold_1"] = false, -- Is Key 1 of the "mkbBinding" a hold down key?
            ["mkbBinding_hold_2"] = false,
            ["mkbBinding_keys"] = 1 -- How many of the keys are currently being used for the binding "mkbBinding"?
        },
        pad = {
            ["padBinding_1"] = "IK_Pad_X_SQUARE",
            ["padBinding_2"] = "IK_Pad_LeftShoulder",
            ["padBinding_3"] = "IK_Pad_LeftThumb",
            ["padBinding_hold_1"] = false,
            ["padBinding_hold_2"] = false,
            ["padBinding_hold_3"] = false,
            ["padBinding_keys"] = 2
        }
    },
}

local function deepcopy(origin)
	local orig_type = type(origin)
    local copy
    if orig_type == 'table' then
        copy = {}
        for origin_key, origin_value in next, origin, nil do
            copy[deepcopy(origin_key)] = deepcopy(origin_value)
        end
        setmetatable(copy, deepcopy(getmetatable(origin)))
    else
        copy = origin
    end
    return copy
end

function multi:new()
    registerForEvent("onInit", function()
        config.tryCreateConfig("config.json", self.defaultSettings) -- Create config file
        self.settings = config.loadFile("config.json")

        if not Codeware then -- Required codeware for the inputs
            print("Error: Missing Codeware")
        end

        local nativeSettings = GetMod("nativeSettings")
        if not nativeSettings then print("Error: Missing Native Settings") end

        nativeSettings.addTab("/multKeys", "Multi Input Mod")
        nativeSettings.addSubcategory("/multKeys/keyboard", "Keyboard Binding")
        nativeSettings.addSubcategory("/multKeys/pad", "Gamepad Binding")

        self.inputManager = require("inputManager") -- Load input manager
        self.inputManager.onInit()

        -- Keyboard
        local info = self.inputManager.createBindingInfo() -- Create an info table that holds information for a binding, makes it easier to reuse later
        info.keybindLabel = "Key" -- Label of each key, will be followed by the key number, e.g. "Key 1"
        info.keybindDescription = "Bind a key that is part of the hotkey" -- Description that'll be displayed for all the bindings keys
        info.supportsHold = false -- Whether to show the hold switches for this bindings keys
        info.id = "mkbBinding" -- Unique id for the binding, used for the savedOptions/defaultOptions tables and the saveCallback. See above for more details
        info.maxKeys = 2 -- Maximum amount of keys for this binding, shows a slider if it is bigger than 1
        info.maxKeysLabel = "Hotkey Keys Amount" -- Label for the binding's key amount slider
        info.maxKeysDescription = "Changes how many keys this hotkey has, all of them have to pressed for the hotkey to be activated" -- Description for the binding's key amount slider
        info.nativeSettingsPath = "/multKeys/keyboard" -- Native settings path for where to add the bindigs options, if it is a multikey binding it has to be a seperate subcategory
        info.defaultOptions = self.defaultSettings.keyboard -- Table containing the default options
        info.savedOptions = self.settings.keyboard -- Table containing the current options

        info.saveCallback = function(name, value) -- Callback for when anything about the binding gets changed, gets the changed variable's generated name + the value
            self.settings.keyboard[name] = value -- Store changed value
            config.saveFile("config.json", self.settings) -- Save to file
        end
        info.callback = function() -- Callback for when the binding has been activated
            print("Keyboard binding was activated")
        end
        self.inputManager.addNativeSettingsBinding(info) -- Acutally create the bindings widgets etc.

        -- Gamepad
        info = deepcopy(info) -- Copy the previous info table, no reason to re-setup most of it
        info.supportsHold = true
        info.isHoldLabel = "Is Hold" -- Label for the binding's key's hold switches
        info.isHoldDescription = "Controls whether the bound key below needs to be held down for some time to be activated" -- Description that'll be displayed for all the bindings keys hold toggle
        info.id = "padBinding"
        info.maxKeys = 3
        info.nativeSettingsPath = "/multKeys/pad"
        info.defaultOptions = self.defaultSettings.pad
        info.savedOptions = self.settings.pad
        info.saveCallback = function(name, value)
            self.settings.pad[name] = value
            config.saveFile("config.json", self.settings)
        end
        info.callback = function()
            print("Gamepad binding was activated")
        end
        self.inputManager.addNativeSettingsBinding(info)
    end)

    registerForEvent("onShutdown", function ()
        self.inputManager.onShutdown()
    end)

    registerForEvent("onUpdate", function(dt)
        self.inputManager.onUpdate(dt)
    end)

    return self
end

return multi:new()