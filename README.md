


# Native Settings
A small mod for Cyberpunk 2077 that allows other mods to easily add settings options to a custom, fully native UI `Mods` settings menu. User-friendly and fully controller compatible.

![](https://cdn.jsdelivr.net/gh/justarandomguyintheinternet/keanuWheeze/nativeSettingsImages/main.gif)
### How to use:
1. CET Version 1.18.1+ is required
2. Either add this mod to your mod's requirement list ([Nexus page](https://www.nexusmods.com/cyberpunk2077/mods/3518)), or ship it with your mod (Credits to either this or the nexus page)
3. Import it into your mod:
	```lua
	nativeSettings = GetMod("nativeSettings")
	```

### Add a new tab:
![](https://cdn.jsdelivr.net/gh/justarandomguyintheinternet/keanuWheeze/nativeSettingsImages/tabs.gif)
- Multiple mods can share the same tab
- `path` should be a `/` followed by a simple keyword.
- `label` is what will be displayed
	```lua
	nativeSettings.addTab("/myMod", "My mod") -- Add a tab (path, label)
	```

### Add a new subcategory:
![](https://cdn.jsdelivr.net/gh/justarandomguyintheinternet/keanuWheeze/nativeSettingsImages/sub.PNG)
- Use subcategories to organize options
-  `path` should be your mods tab path (e.g. `/myMod`), followed by a `/`, followed by a simple keyword.
- `label` is what will be displayed
- `optionalIndex` is an optional `int` parameter to control the position of the subcategory (Default is same order as `addSubcategory`'s get called)
	```lua
	nativeSettings.addSubcategory("/myMod/sub", "A subcategory") -- Add a subcategory (path, label, optionalIndex)
	```
## Adding option widgets:
- All option widgets can be added to either a tab directly (Provide the tab path), or a tab's subcategory (Provide full path)

#### Parameters every widget has:
- `path` : Where the widget goes, e.g. `/myMod` or `/myMod/sub`
- `label` : What gets displayed to the left of the widget
- `desc` : A description of what the option does, gets displayed when hovered over
- `currentValue` : This is what the option's initial value (Type depends on the widget) is. Usually, this value would get read from a settings file / database inside`onInit`
- `defaultValue` : This is what the option's default value should be, gets set when the `Defaults` button is hit
- `callback` : Here, you pass a function `f(value)` that gets called when the options gets changed. It gets called with a single parameter, the updated value
- `optionalIndex` : Optional index parameter that can be used to control the order of the options (Default is same order as the `addOption`'s get called)
### Toggle:
![](https://cdn.jsdelivr.net/gh/justarandomguyintheinternet/keanuWheeze/nativeSettingsImages/switch.gif)
- This adds a basic true/false switch
- Datatype is `boolean`
	```lua
	-- Parameters: path, label, desc, currentValue, defaultValue, callback, optionalIndex

	nativeSettings.addSwitch("/myMod/sub", "Switch", "Description", true, true, function(state)
		print("Changed SWITCH to ", state)
		-- Add any logic you need in here, such as saving the changes to file / database
	end)
	```
### Slider Int:
![](https://cdn.jsdelivr.net/gh/justarandomguyintheinternet/keanuWheeze/nativeSettingsImages/int.gif)
- This adds a slider, that can only get set to whole numbers
- Datatype is `int`
- `min` : This is the minimum value of the slider
- `max` : This is the maximum value of the slider
- `step` : This is the minimum amount the slider can move
	```lua
	-- Parameters: path, label, desc, min, max, step, currentValue, defaultValue, callback, optionalIndex

	nativeSettings.addRangeInt("/myMod/sub", "Slider Int", "Description", 1, 100, 1, 50, 25, function(value)
		print("Changed SLIDER INT to ", value)
		-- Add any logic you need in here, such as saving the changes to file / database
	end)
	```
### Slider Float:
![](https://cdn.jsdelivr.net/gh/justarandomguyintheinternet/keanuWheeze/nativeSettingsImages/float.gif)
- This adds a slider, that can be set to any value
- Datatype is `float` (`int` also works)
- `min` : This is the minimum value of the slider
- `max` : This is the maximum value of the slider
- `step` : This is the minimum amount the slider can move
- `format` : This is a format string, to control how the value gets displayed (Works the same as lua's `string.format()`)
	```lua
	-- Parameters: path, label, desc, min, max, step, format, currentValue, defaultValue, callback, optionalIndex

	nativeSettings.addRangeFloat("/myMod/sub", "Slider Float", "Description", 1, 100, 0.25, "%.2f", 50, 1, function(value)
		print("Changed SLIDER FLOAT to ", value)
		-- Add any logic you need in here, such as saving the changes to file / database
	end)
	```
### String List:
![](https://cdn.jsdelivr.net/gh/justarandomguyintheinternet/keanuWheeze/nativeSettingsImages/list.gif)
- This adds a list of strings, that can be chosen of
- Datatype is `table`
- The table must be numerical indexed
- `currentValue` / `defaultValue` is the index of the selected element
	```lua
	-- Parameters: path, label, desc, elements, currentValue, defaultValue, callback, optionalIndex

	local  list = {[1] = "Option 1", [2] = "Option 2", [3] = "Option 3", [4] = "Option 4"} -- Create list of options, with numeric index

	nativeSettings.addSelectorString("/myMod/sub", "String List", "Description", list, 1, 3, function(value)
		print("Changed LIST STRING to ", list[value])
		-- Add any logic you need in here, such as saving the changes to file / database
	end)
	```
### Button:
![](https://cdn.jsdelivr.net/gh/justarandomguyintheinternet/keanuWheeze/nativeSettingsImages/button.gif)
- This adds a simple, interactable button which calls the `callback` function without any parameters when clicked
- Has no `currentValue` and `defaultValue` parameters
- `buttonText` is the text that gets displayed inside the button
- `textSize` is the size of the `buttonText` text
	```lua
	-- Parameters: path, label, desc, buttonText, textSize, callback, optionalIndex

	nativeSettings.addButton("/myMod/sub", "Button", "Description", "Button label", 45, function()
		print("User clicked BUTTON")
		-- Add any logic you need in here, such as calling a function from your mod
	end)
	```
## Removing options / subcategories:
- Option widgets as well as subcategories can be added or removed while the UI is active
- Use this in combination with the `optionalIndex` parameter of any `addOption` function to add and remove options where they are needed
### Subcategory:
- `optionTable` is what gets returned by any `addOption` function (switch/int/float/list/button)
- Call `refresh` once after removing an option, when removing many options at the same time, make sure to only call `refresh` once after all options have been removed
	```lua
	-- Parameters: optionTable
	nativeSettings.removeOption(optionTable)
	```
### Subcategory:
- `path` is the full path to the subcategory you want to remove
- Call `refresh` once after removing a subcategory
	```lua
	-- Parameters: path
	nativeSettings.removeSubcategory("/myMod/sub")
	```
	
## The `refresh` function:
- Refreshes the UI when active, to reflect changes made by adding (e.g. `addSwitch`) or removing (e.g. `removeOption`) option widgets or entire subcategories
- When adding or removing multiple option widgets or subcategories at once, make sure to only call `refresh` once, after all adding / removing operations are done
	```lua
	nativeSettings.refresh()
	```

## The `setOption` function:
- The nativeSettings mod only gets the settings values at the startup in form of the `currentValue`
- If you modify any settings / options from e.g. a secondary ImGui settings window, the values displayed by nativeSettings will be out of sync
- Use the `setOption(optionTable, value)` function if you change an option from outside the nativeSettings window, to make sure everything stays synced
- `optionTable` is what gets returned by any `addOption` function (switch/int/float/list)
- `value` is the value you want to set
- Example:
	```lua
	local settingsTables = {} -- An epmty tables to store the return from the addOption functions, in case we want to use setOption(), can be ignored otherwise
	local switchState = false -- Would usually get loaded from a config file / database
	local nativeSettings

	registerForEvent("onInit", function()
		nativeSettings = GetMod("nativeSettings") -- Get a reference to the nativeSettings mod

		if not nativeSettings then -- Make sure the mod is installed
			print("Error: NativeSettings not found!")
			return
		end

		nativeSettings.addTab("/myMod", "My mod") -- Add our mods tab (path, label)
		nativeSettings.addSubcategory("/myMod/sub", "A subcategory") -- Optional: Add a subcategory (path, label), you can add as many as you want

		settingsTables["switch"] = nativeSettings.addSwitch("/myMod/sub", "Switch", "Description", switchState, true, function(state)
			print("Changed SWITCH to ", state)
			switchState = state
		end)
	end)

	registerForEvent("onDraw", function()
		if ImGui.Begin("Alternative Settings Window", ImGuiWindowFlags.AlwaysAutoResize) then
			switchState, changed = ImGui.Checkbox("Switch", switchState)
			if changed then -- We changed the option value from somewhere else
				nativeSettings.setOption(settingsTables["switch"], switchState) -- Update the value for the nativeSettings mod
			end
		end
		ImGui.End()
	end)
	```
#### Credits:
- [psiberx](https://github.com/psiberx) for answering all my questions, as well as doing a lot of work on CET that makes this mod even work and creating `Cron.lua`.
- nim for hating ImGui