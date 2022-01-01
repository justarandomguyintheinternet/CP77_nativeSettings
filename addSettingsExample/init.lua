registerForEvent("onInit", function()
    local nativeSettings = GetMod("nativeSettings") -- Get a reference to the nativeSettings mod

    if not nativeSettings then -- Make sure the mod is installed
        print("Error: NativeSettings not found!")
        return
    end

    nativeSettings.addTab("/myMod", "My mod") -- Add our mods tab (path, label)
    nativeSettings.addSubcategory("/myMod/sub", "A subcategory") -- Optional: Add a subcategory (path, label), you can add as many as you want

    nativeSettings.addSwitch("/myMod/sub", "Switch", "Description", true, true, function(state) -- path, label, desc, currentValue, defaultValue, callback
        print("Changed SWITCH to ", state)
        -- Add in any logic you need in here, such as saving the changed to file / database
    end)

    nativeSettings.addRangeInt("/myMod", "Slider Int", "Description", 1, 100, 1, 50, 25, function(value) -- path, label, desc, min, max, step, currentValue, defaultValue, callback
        print("Changed SLIDER INT to ", value)
        -- Add in any logic you need in here, such as saving the changed to file / database
    end)

    nativeSettings.addRangeFloat("/myMod/sub", "Slider Float", "Description", 1, 100, 0.25, "%.2f", 50, 1, function(value) -- path, label, desc, min, max, step, format, currentValue, defaultValue, callback
        print("Changed SLIDER FLOAT to ", value)
        -- Add in any logic you need in here, such as saving the changed to file / database
    end)

    local list = {[1] = "Option 1", [2] = "Option 2", [3] = "Option 3", [4] = "Option 4"} -- Create list of options, with numeric index

    nativeSettings.addSelectorString("/myMod/sub", "String List", "Description", list, 1, 4, function(value) -- path, label, desc, elements, currentValue, defaultValue, callback
        print("Changed LIST STRING to ", list[value])
        -- Add in any logic you need in here, such as saving the changed to file / database
    end)

    nativeSettings.addButton("/myMod/sub", "Button", "Description", "Button label", 45, function()
        print("User clicked BUTTON")
        -- Add any logic you need in here, such as calling a function from your mod
    end)
end)