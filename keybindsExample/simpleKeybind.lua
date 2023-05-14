-- Requires Codeware (https://github.com/psiberx/cp2077-codeware) to work

local simpleInputMod = {
    inputListener = nil,
    listeningKeybindWidget = nil,
    boundKey = "IK_5"
}

function simpleInputMod:setupNativeSettingsUI()
    local nativeSettings = GetMod("nativeSettings")

    if not nativeSettings then return false end

    nativeSettings.addTab("/simpleInputMod", "Input Mod")

    nativeSettings.addKeyBinding("/simpleInputMod", "Keybind", "Description", self.boundKey, "IK_5", false, function(key)
        self.boundKey = key
    end)

    return true
end

local function handleInputWrapper(event) -- Closure for the callback function, so that self can be used
    simpleInputMod:handInput(event)
end

function simpleInputMod:handInput(event)
    local key = event:GetKey().value
    local action = event:GetAction().value

    if self.listeningKeybindWidget and key:find("IK_Pad") and action == "IACT_Release" then -- OnKeyBindingEvent has to be called manually for gamepad inputs, while there is a keybind widget listening for input
        self.listeningKeybindWidget:OnKeyBindingEvent(KeyBindingEvent.new({keyName = key}))
        self.listeningKeybindWidget = nil
    elseif self.listeningKeybindWidget and action == "IACT_Release" then -- Key was bound, by keyboard
        self.listeningKeybindWidget = nil
    end

    if action == "IACT_Release" then
        if key == self.boundKey then
            print("Bound key was pressed!")
        end
    end
end

function simpleInputMod:new()
    registerForEvent("onInit", function()
        if not Codeware then -- Required codeware for the inputs
            print("Error: Missing Codeware")
        end

        local success = self:setupNativeSettingsUI()
        if not success then print("Native Settings not installed") return end

        Observe("SettingsSelectorControllerKeyBinding", "ListenForInput", function(this) -- A keybind widget is listening for input, so should we (Since gamepad inputs are not sent to the native OnKeyBindingEvent by default)
            self.listeningKeybindWidget = this
        end)

        self.inputListener = NewProxy({
            OnKeyInput = { -- https://github.com/psiberx/cp2077-codeware/wiki#game-events
                args = {'whandle:KeyInputEvent'},
                callback = handleInputWrapper
            }
        })

        ObserveBefore("PlayerPuppet", "OnGameAttached", function()
            Game.GetCallbackSystem():RegisterCallback("Input/Key", self.inputListener:Target(), self.input.inputListener:Function("OnKeyInput"))
        end)

        ObserveBefore("PlayerPuppet", "OnDetach", function()
            Game.GetCallbackSystem():UnregisterCallback("Input/Key", self.input.inputListener:Target())
        end)
    end)

    registerForEvent("onShutdown", function()
        Game.GetCallbackSystem():UnregisterCallback("Input/Key", self.inputListener:Target()) -- Make sure to unregister the callback, to avoid them adding up with every mod reload
    end)

    return self
end

return simpleInputMod:new()