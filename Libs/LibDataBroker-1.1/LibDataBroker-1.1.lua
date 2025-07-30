--[[
Name: LibDataBroker-1.1
Revision: $Rev: 104 $
Author: tekkub (tekkub@gmail.com)
Website: http://www.wowace.com/projects/libdatabroker-1-1/
Description: A centralized registration and notification system for minimap icons.
Dependencies: LibStub
License: Public Domain
]]

assert(LibStub, "LibDataBroker-1.1 requires LibStub")
assert(LibStub:GetLibrary("CallbackHandler-1.0", true), "LibDataBroker-1.1 requires CallbackHandler-1.0")

local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4)
if not lib then return end

oldminor = oldminor or 0

lib.callbacks = lib.callbacks or LibStub:GetLibrary("CallbackHandler-1.0"):New(lib)
lib.attributestorage = lib.attributestorage or {}
lib.namestorage = lib.namestorage or {}
lib.proxystorage = lib.proxystorage or {}
local attributestorage = lib.attributestorage
local namestorage = lib.namestorage
local callbacks = lib.callbacks
local proxystorage = lib.proxystorage

if oldminor < 2 then
	lib.domt = {
		__metatable = "access denied",
		__index = function(self, key)
			if attributestorage[self] and attributestorage[self][key] then
				return attributestorage[self][key]
			end
		end,
		__newindex = function(self, key, value)
			if not attributestorage[self] then attributestorage[self] = {} end
			if attributestorage[self][key] == value then return end
			attributestorage[self][key] = value
			local name = namestorage[self]
			if not name then return end
			callbacks:Fire("LibDataBroker_AttributeChanged", name, key, value, self)
			callbacks:Fire("LibDataBroker_AttributeChanged_"..name, key, value, self)
			callbacks:Fire("LibDataBroker_AttributeChanged_"..name.."_"..key, value, self)
			callbacks:Fire("LibDataBroker_AttributeChanged__"..key, name, value, self)
		end,
	}
end

if oldminor < 3 then
	lib.domt.__pairs = function(self)
		local t = attributestorage[self]
		if t then
			return pairs(t)
		else
			return pairs({})
		end
	end
end

if oldminor < 4 then
	lib.domt.__tostring = function(self)
		return namestorage[self] or "LibDataBroker object"
	end
end

local function validatename(name)
	if type(name) ~= "string" then
		error("Usage: NewDataObject(name, table) - name must be a string", 2)
	elseif namestorage[name] then
		error("Usage: NewDataObject(name, table) - name '"..name.."' is already in use by another DataBroker object", 2)
	end
end

local function validatetable(t)
	if type(t) ~= "table" then
		error("Usage: NewDataObject(name, table) - table must be a table", 2)
	elseif t.type and type(t.type) ~= "string" then
		error("Usage: NewDataObject(name, table) - field 'type' must be a string", 2)
	elseif t.text and type(t.text) ~= "string" and type(t.text) ~= "function" then
		error("Usage: NewDataObject(name, table) - field 'text' must be a string or function", 2)
	elseif t.value and type(t.value) ~= "string" and type(t.value) ~= "function" then
		error("Usage: NewDataObject(name, table) - field 'value' must be a string or function", 2)
	elseif t.label and type(t.label) ~= "string" and type(t.label) ~= "function" then
		error("Usage: NewDataObject(name, table) - field 'label' must be a string or function", 2)
	elseif t.suffix and type(t.suffix) ~= "string" and type(t.suffix) ~= "function" then
		error("Usage: NewDataObject(name, table) - field 'suffix' must be a string or function", 2)
	elseif t.icon and type(t.icon) ~= "string" and type(t.icon) ~= "function" then
		error("Usage: NewDataObject(name, table) - field 'icon' must be a string or function", 2)
	elseif t.iconCoords and type(t.iconCoords) ~= "table" and type(t.iconCoords) ~= "function" then
		error("Usage: NewDataObject(name, table) - field 'iconCoords' must be a table or function", 2)
	elseif t.iconR and type(t.iconR) ~= "number" then
		error("Usage: NewDataObject(name, table) - field 'iconR' must be a number", 2)
	elseif t.iconG and type(t.iconG) ~= "number" then
		error("Usage: NewDataObject(name, table) - field 'iconG' must be a number", 2)
	elseif t.iconB and type(t.iconB) ~= "number" then
		error("Usage: NewDataObject(name, table) - field 'iconB' must be a number", 2)
	elseif t.OnClick and type(t.OnClick) ~= "function" then
		error("Usage: NewDataObject(name, table) - field 'OnClick' must be a function", 2)
	elseif t.OnReceiveDrag and type(t.OnReceiveDrag) ~= "function" then
		error("Usage: NewDataObject(name, table) - field 'OnReceiveDrag' must be a function", 2)
	elseif t.OnTooltipShow and type(t.OnTooltipShow) ~= "function" then
		error("Usage: NewDataObject(name, table) - field 'OnTooltipShow' must be a function", 2)
	elseif t.OnEnter and type(t.OnEnter) ~= "function" then
		error("Usage: NewDataObject(name, table) - field 'OnEnter' must be a function", 2)
	elseif t.OnLeave and type(t.OnLeave) ~= "function" then
		error("Usage: NewDataObject(name, table) - field 'OnLeave' must be a function", 2)
	elseif t.tocname and type(t.tocname) ~= "string" then
		error("Usage: NewDataObject(name, table) - field 'tocname' must be a string", 2)
	end
end

function lib:NewDataObject(name, dataobj)
	validatename(name)
	validatetable(dataobj)

	local obj = setmetatable({}, lib.domt)
	attributestorage[obj] = {}
	namestorage[obj] = name
	proxystorage[name] = obj

	for i, v in pairs(dataobj) do
		attributestorage[obj][i] = v
	end

	callbacks:Fire("LibDataBroker_DataObjectCreated", name, obj)
	return obj, name
end

function lib:DataObjectIterator()
	return pairs(proxystorage)
end

function lib:GetDataObjectByName(dataobjectname)
	return proxystorage[dataobjectname]
end

function lib:GetNameByDataObject(dataobject)
	return namestorage[dataobject]
end