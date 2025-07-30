--[[
Name: LibDBIcon-1.0
Revision: $Rev: 187 $
Author:  Rabbit (rabbit.magtheridon@gmail.com)
Website: http://www.wowace.com/projects/libdbicon-1-0/
Description: Allows addons to easily create and manage Minimap icons using LibDataBroker.
Dependencies: LibStub, LibDataBroker-1.1
License: LGPL v2.1
]]

local MAJOR, MINOR = "LibDBIcon-1.0", 45
assert(LibStub, MAJOR.." requires LibStub")
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.objects = lib.objects or {}
lib.callbackRegistered = lib.callbackRegistered or nil
lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)
lib.notCreated = lib.notCreated or {}
lib.radius = lib.radius or 5
lib.tooltip = lib.tooltip or CreateFrame("GameTooltip", "LibDBIconTooltip", UIParent, "GameTooltipTemplate")

local next, Minimap = next, Minimap
local isDraggingButton = false

local function getAnchors(frame)
	local x, y = frame:GetCenter()
	if not x or not y then return "CENTER" end
	local hhalf = (x > UIParent:GetWidth() * 2 / 3) and "RIGHT" or (x < UIParent:GetWidth() / 3) and "LEFT" or ""
	local vhalf = (y > UIParent:GetHeight() / 2) and "TOP" or "BOTTOM"
	return vhalf .. hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP") .. hhalf
end

local function updatePosition(button, position)
	local angle = math.rad(position or 0)
	local x, y, q = math.cos(angle), math.sin(angle), 1
	if x < 0 then q = q + 1 end
	if y > 0 then q = q + 2 end
	local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
	local quadTable = minimapShape == "ROUND" and lib.minimapShapes["ROUND"][q] or lib.minimapShapes["SQUARE"][q]
	local w = (Minimap:GetWidth() / 2) + lib.radius
	local h = (Minimap:GetHeight() / 2) + lib.radius
	local diagRadiusW = math.sqrt(2*(w)^2) - 10
	local diagRadiusH = math.sqrt(2*(h)^2) - 10
	x = math.max(-w, math.min(x*quadTable[1]*diagRadiusW, w))
	y = math.max(-h, math.min(y*quadTable[2]*diagRadiusH, h))
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function onClick(self, b)
	if self.dataObject.OnClick then
		self.dataObject.OnClick(self, b)
	end
end

local function onMouseDown(self)
	self.isMouseDown = true
	self.icon:UpdateTexture()
end

local function onMouseUp(self)
	self.isMouseDown = false
	self.icon:UpdateTexture()
end

local function onEnter(self)
	if self.dataObject.OnTooltipShow then
		lib.tooltip:SetOwner(self, "ANCHOR_NONE")
		lib.tooltip:SetPoint(getAnchors(self))
		self.dataObject.OnTooltipShow(lib.tooltip)
		lib.tooltip:Show()
	elseif self.dataObject.OnEnter then
		self.dataObject.OnEnter(self)
	end
end

local function onLeave(self)
	lib.tooltip:Hide()
	if self.dataObject.OnLeave then
		self.dataObject.OnLeave(self)
	end
end

local function onDragStart(self)
	self:LockHighlight()
	self.isMoving = true
	isDraggingButton = true
end

local function onDragStop(self)
	self:UnlockHighlight()
	self.isMoving = false
	isDraggingButton = false
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	px, py = px / scale, py / scale
	local pos = 225
	if self.db then
		pos = math.deg(math.atan2(py - my, px - mx)) % 360
		self.db.minimapPos = pos
	end
	updatePosition(self, pos)
end

local function createButton(name, object, db)
	local button = CreateFrame("Button", "LibDBIcon10_" .. name, Minimap)
	button.dataObject = object
	button.db = db
	button:SetFrameStrata("MEDIUM")
	button:SetSize(31, 31)
	button:SetFrameLevel(8)
	button:RegisterForClicks("anyUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture(136477) --"Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
	local overlay = button:CreateTexture(nil, "OVERLAY")
	button.overlay = overlay
	overlay:SetSize(53, 53)
	overlay:SetTexture(136430) --"Interface\\Minimap\\MiniMap-TrackingBorder"
	overlay:SetPoint("TOPLEFT")
	local background = button:CreateTexture(nil, "BACKGROUND")
	button.background = background
	background:SetSize(20, 20)
	background:SetTexture(136467) --"Interface\\Minimap\\UI-Minimap-Background"
	background:SetPoint("TOPLEFT", 7, -5)
	local icon = button:CreateTexture(nil, "ARTWORK")
	button.icon = icon
	icon:SetSize(17, 17)
	icon:SetPoint("TOPLEFT", 7, -6)
	button.isMouseDown = false
	local function updateTexture()
		local texCoords = object.iconCoords or { 0.05, 0.95, 0.05, 0.95 }
		if button.isMouseDown then
			icon:SetTexCoord(texCoords[1] + 0.05, texCoords[2] - 0.05, texCoords[3] + 0.05, texCoords[4] - 0.05)
		else
			icon:SetTexCoord(texCoords[1], texCoords[2], texCoords[3], texCoords[4])
		end
	end
	icon.UpdateTexture = updateTexture
	button:SetScript("OnEnter", onEnter)
	button:SetScript("OnLeave", onLeave)
	button:SetScript("OnClick", onClick)
	button:SetScript("OnMouseDown", onMouseDown)
	button:SetScript("OnMouseUp", onMouseUp)
	button:SetScript("OnDragStart", onDragStart)
	button:SetScript("OnDragStop", onDragStop)
	button:Show()

	lib.objects[name] = button

	if lib.loggedIn then
		updatePosition(button, db and db.minimapPos)
		if not db or not db.hide then
			button:Show()
		else
			button:Hide()
		end
	end
	lib.callbacks:Fire("LibDBIcon_IconCreated", button, name)
end

-- Wait a bit with the initial positioning to let any GetMinimapShape addons load up.
if not lib.loggedIn then
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_LOGIN")
	f:SetScript("OnEvent", function(f)
		for _, button in next, lib.objects do
			updatePosition(button, button.db and button.db.minimapPos)
			if not button.db or not button.db.hide then
				button:Show()
			else
				button:Hide()
			end
		end
		lib.loggedIn = true
		f:UnregisterAllEvents()
	end)
end

local function getDatabase(name)
	return lib.notCreated[name] and lib.notCreated[name].db or lib.objects[name].db
end

function lib:Register(name, object, db)
	if not object.icon then error("LibDBIcon-1.0: object 'icon' must be set") end
	if lib.objects[name] or lib.notCreated[name] then error("LibDBIcon-1.0: object '" .. name .. "' is already registered") end
	if not db or not db.hide then
		createButton(name, object, db)
	else
		lib.notCreated[name] = { object = object, db = db }
	end
end

function lib:Hide(name)
	if not lib.objects[name] then
		lib.notCreated[name].db.hide = true
		return
	end
	lib.objects[name]:Hide()
end

function lib:Show(name)
	local db = getDatabase(name)
	db.hide = false
	if lib.notCreated[name] then
		createButton(name, lib.notCreated[name].object, lib.notCreated[name].db)
		lib.notCreated[name] = nil
	elseif lib.objects[name] then
		lib.objects[name]:Show()
	end
end

function lib:IsRegistered(name)
	return (lib.objects[name] and true) or (lib.notCreated[name] and true) or false
end

function lib:Refresh(name, db)
	local button = lib.objects[name]
	if db then
		button.db = db
	end
	updatePosition(button, button.db and button.db.minimapPos)
	if not button.db or not button.db.hide then
		button:Show()
	else
		button:Hide()
	end
end

function lib:GetMinimapButton(name)
	return lib.objects[name]
end

do
	local function OnMinimapEnter()
		if isDraggingButton then return end
		for _, button in next, lib.objects do
			if button.showOnMouseover then
				button.fadeOut:Stop()
				button:SetAlpha(button.db and button.db.alpha or 1)
			end
		end
	end
	local function OnMinimapLeave()
		if isDraggingButton then return end
		for _, button in next, lib.objects do
			if button.showOnMouseover then
				button.fadeOut:Play()
			end
		end
	end
	Minimap:HookScript("OnEnter", OnMinimapEnter)
	Minimap:HookScript("OnLeave", OnMinimapLeave)
end

lib.minimapShapes = lib.minimapShapes or {
	["ROUND"] = {
		[1] = { 1, 1 },
		[2] = { -1, 1 },
		[3] = { -1, -1 },
		[4] = { 1, -1 },
	},
	["SQUARE"] = {
		[1] = { 1, 1 },
		[2] = { -1, 1 },
		[3] = { -1, -1 },
		[4] = { 1, -1 },
	},
	["CORNER-TOPLEFT"] = {
		[1] = { 1, 1 },
		[2] = { -1, 1 },
		[3] = { -1, -1 },
		[4] = { 1, -1 },
	},
	["CORNER-TOPRIGHT"] = {
		[1] = { 1, 1 },
		[2] = { -1, 1 },
		[3] = { -1, -1 },
		[4] = { 1, -1 },
	},
	["CORNER-BOTTOMLEFT"] = {
		[1] = { 1, 1 },
		[2] = { -1, 1 },
		[3] = { -1, -1 },
		[4] = { 1, -1 },
	},
	["CORNER-BOTTOMRIGHT"] = {
		[1] = { 1, 1 },
		[2] = { -1, 1 },
		[3] = { -1, -1 },
		[4] = { 1, -1 },
	},
	["SIDE-LEFT"] = {
		[1] = { 1, 1 },
		[2] = { -1, 1 },
		[3] = { -1, -1 },
		[4] = { 1, -1 },
	},
	["SIDE-RIGHT"] = {
		[1] = { 1, 1 },
		[2] = { -1, 1 },
		[3] = { -1, -1 },
		[4] = { 1, -1 },
	},
	["SIDE-TOP"] = {
		[1] = { 1, 1 },
		[2] = { -1, 1 },
		[3] = { -1, -1 },
		[4] = { 1, -1 },
	},
	["SIDE-BOTTOM"] = {
		[1] = { 1, 1 },
		[2] = { -1, 1 },
		[3] = { -1, -1 },
		[4] = { 1, -1 },
	},
	["TRICORNER-TOPLEFT"] = {
		[1] = { 1, 1 },
		[2] = { -1, 1 },
		[3] = { -1, -1 },
		[4] = { 1, -1 },
	},
	["TRICORNER-TOPRIGHT"] = {
		[1] = { 1, 1 },
		[2] = { -1, 1 },
		[3] = { -1, -1 },
		[4] = { 1, -1 },
	},
	["TRICORNER-BOTTOMLEFT"] = {
		[1] = { 1, 1 },
		[2] = { -1, 1 },
		[3] = { -1, -1 },
		[4] = { 1, -1 },
	},
	["TRICORNER-BOTTOMRIGHT"] = {
		[1] = { 1, 1 },
		[2] = { -1, 1 },
		[3] = { -1, -1 },
		[4] = { 1, -1 },
	},
}

function lib:GetButtonList()
	local t = {}
	for name in next, lib.objects do
		t[name] = true
	end
	for name in next, lib.notCreated do
		t[name] = true
	end
	return t
end

function lib:SetButtonRadius(radius)
	if type(radius) == "number" then
		lib.radius = radius
		for _, button in next, lib.objects do
			updatePosition(button, button.db and button.db.minimapPos)
		end
	end
end

function lib:SetButtonToPosition(name, position)
	local button = lib.objects[name]
	if button and button.db then
		button.db.minimapPos = position
		updatePosition(button, position)
	end
end