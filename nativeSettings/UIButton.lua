-- Copyright (c) 2021 psiberx

local Ref = require('Ref')
local EventProxy = require('EventProxy')

---@return inkCanvasWidget
local function createWidget(name, text)
	local button = inkCanvas.new()
	button:SetName(name)
	button:SetSize(150.0, 100.0)
	button:SetAnchorPoint(Vector2.new({ X = 0.5, Y = 0.5 }))
	button:SetInteractive(true)

	local bg = inkImage.new()
	bg:SetName('bg')
	bg:SetAtlasResource(ResRef.FromName('base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas'))
	bg:SetTexturePart('cell_bg')
	bg:SetTintColor(HDRColor.new({ Red = 0.054902, Green = 0.054902, Blue = 0.090196, Alpha = 1.0 }))
	bg:SetOpacity(0.8)
	bg:SetAnchor(inkEAnchor.Fill)
	bg.useNineSliceScale = true
	bg.nineSliceScale = inkMargin.new({ left = 0.0, top = 0.0, right = 10.0, bottom = 0.0 })
	bg:SetInteractive(false)
	bg:Reparent(button, -1)

	local fill = inkImage.new()
	fill:SetName('fill')
	fill:SetAtlasResource(ResRef.FromName('base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas'))
	fill:SetTexturePart('cell_bg')
	fill:SetTintColor(HDRColor.new({ Red = 1.1761, Green = 0.3809, Blue = 0.3476, Alpha = 1.0 }))
	fill:SetOpacity(0.0)
	fill:SetAnchor(inkEAnchor.Fill)
	fill.useNineSliceScale = true
	fill.nineSliceScale = inkMargin.new({ left = 0.0, top = 0.0, right = 10.0, bottom = 0.0 })
	fill:SetInteractive(false)
	fill:Reparent(button, -1)

	local frame = inkImage.new()
	frame:SetName('frame')
	frame:SetAtlasResource(ResRef.FromName('base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas'))
	frame:SetTexturePart('cell_fg')
	frame:SetTintColor(HDRColor.new({ Red = 0.368627, Green = 0.964706, Blue = 1.0, Alpha = 1.0 }))
	frame:SetOpacity(0.3)
	frame:SetAnchor(inkEAnchor.Fill)
	frame.useNineSliceScale = true
	frame.nineSliceScale = inkMargin.new({ left = 0.0, top = 0.0, right = 10.0, bottom = 0.0 })
	frame:SetInteractive(false)
	frame:Reparent(button, -1)

	local label = inkText.new()
	label:SetName('label')
	label:SetFontFamily('base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily')
	label:SetFontStyle('Medium')
	label:SetFontSize(50)
	label:SetLetterCase(textLetterCase.UpperCase)
	label:SetTintColor(HDRColor.new({ Red = 1.1761, Green = 0.3809, Blue = 0.3476, Alpha = 1.0 }))
	label:SetAnchor(inkEAnchor.Fill)
	label:SetHorizontalAlignment(textHorizontalAlignment.Center)
	label:SetVerticalAlignment(textVerticalAlignment.Center)
	label:SetText(text)
	label:SetInteractive(false)
	label:Reparent(button, -1)

	return button
end

---@param _ IScriptable
---@param evt inkPointerEvent
local function onHoverOver(_, evt)
	local buttonWidget = evt:GetCurrentTarget()

	buttonWidget:GetWidget('fill'):SetOpacity(0.1)
	buttonWidget:GetWidget('frame'):SetOpacity(1.0)
end

---@param _ IScriptable
---@param evt inkPointerEvent
local function onHoverOut(_, evt)
	local buttonWidget = evt:GetCurrentTarget()

	buttonWidget:GetWidget('fill'):SetOpacity(0.0)
	buttonWidget:GetWidget('frame'):SetOpacity(0.3)
end

---@param button inkCanvasWidget
local function regisrerCallbacks(button)
	EventProxy.RegisterCallback(button, 'OnEnter', onHoverOver)
	EventProxy.RegisterCallback(button, 'OnLeave', onHoverOut)
end

---@param button inkCanvasWidget
local function unregisrerCallbacks(button)
	EventProxy.UnregisterCallback(button, 'OnEnter', onHoverOver)
	EventProxy.UnregisterCallback(button, 'OnLeave', onHoverOut)
end

---@class UIButton
---@field root inkCanvasWidget
local UIButton = {}
UIButton.__index = UIButton

---@param name CName
---@param text string
---@return UIButton, inkCanvasWidget
function UIButton.Create(name, text)
	local root = createWidget(name, text)

	regisrerCallbacks(root)

	return setmetatable({ root = Ref.Weak(root) }, UIButton), root
end

---@return inkCanvasWidget
function UIButton:GetRootWidget()
	return self.root
end

---@return inkTextWidget
function UIButton:GetLabelWidget()
	return self.root:GetWidgetByPathName('label')
end

---@param event string
---@param callback function
function UIButton:RegisterCallback(event, callback)
	EventProxy.RegisterCallback(self.root, event, callback)
end

---@param event string
---@param callback function
function UIButton:UnregisterCallback(event, callback)
	EventProxy.UnregisterCallback(self.root, event, callback)
end

---@param parent inkCompoundWidget
---@param index Int32
function UIButton:Reparent(parent, index)
	if Ref.IsDefined(self.root) then
		self.root:Reparent(parent, index or -1)
	end
end

function UIButton:Destroy()
	if Ref.IsDefined(self.root) then
		unregisrerCallbacks(self.root)

		self.root = nil
	end
end

return UIButton