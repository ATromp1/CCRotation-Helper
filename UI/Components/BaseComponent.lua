-- BaseComponent.lua - Foundation for all UI components
-- Enforces architectural patterns and provides common functionality

local addonName, addon = ...

-- Get AceGUI reference for components
local AceGUI = LibStub("AceGUI-3.0")
if not AceGUI then
    error("AceGUI-3.0 not found! Components require AceGUI library.")
end

-- Base Component Class - enforces architectural patterns
local BaseComponent = {}
addon.BaseComponent = BaseComponent

-- Make AceGUI available to all components through BaseComponent
BaseComponent.AceGUI = AceGUI

function BaseComponent:new(container, callbacks, dataProvider)
    if not container then
        error("BaseComponent requires a container")
    end
    
    -- Validate container setup for proper visual separation
    self:validateContainer(container)
    
    local instance = {
        container = container,
        callbacks = callbacks or {},
        dataProvider = dataProvider,
        eventListeners = {}  -- Track registered event listeners for cleanup
    }
    setmetatable(instance, {__index = self})
    return instance
end

-- Validate container follows layout guidelines
function BaseComponent:validateContainer(container)
    -- Check if container is properly configured for visual separation
    if container.type == "InlineGroup" then
        -- InlineGroup is ideal for component separation
        if not container.frame:GetWidth() or container.frame:GetWidth() == 0 then
            print("Warning: Component container should use SetFullWidth(true) for proper layout")
        end
    elseif container.type == "SimpleGroup" then
        -- SimpleGroup is acceptable for internal organization
        -- No additional validation needed
    else
        print("Warning: Component container type '" .. (container.type or "unknown") .. "' may not provide proper visual separation. Consider using InlineGroup.")
    end
end

function BaseComponent:refresh()
    if not self.container then
        error("Component container is nil - component may have been destroyed")
    end
    
    self.container:ReleaseChildren()
    self:buildUI()
    
    -- Force container layout refresh to handle size changes
    if self.container.DoLayout then
        self.container:DoLayout()
    end
    
    -- Also refresh parent container if it exists
    if self.container.parent and self.container.parent.DoLayout then
        self.container.parent:DoLayout()
    end
end

function BaseComponent:buildUI()
    error("buildUI() must be implemented by component subclass")
end

-- Standardized event registration with automatic cleanup tracking
function BaseComponent:RegisterEventListener(eventName, callback)
    if not self.eventListeners[eventName] then
        self.eventListeners[eventName] = {}
    end
    
    -- Wrap callback to maintain 'self' reference
    local wrappedCallback = function(...)
        callback(self, ...)
    end
    
    addon.Config:RegisterEventListener(eventName, wrappedCallback)
    table.insert(self.eventListeners[eventName], wrappedCallback)
end

-- Cleanup method to unregister events
function BaseComponent:Cleanup()
    if self.eventListeners then
        for eventName, callbacks in pairs(self.eventListeners) do
            for _, callback in ipairs(callbacks) do
                -- Note: We'd need to add UnregisterEventListener to Config
                -- addon.Config:UnregisterEventListener(eventName, callback)
            end
        end
        self.eventListeners = {}
    end
end

function BaseComponent:triggerCallback(callbackName, ...)
    if self.callbacks[callbackName] then
        self.callbacks[callbackName](...)
    end
end

function BaseComponent:destroy()
    if self.container then
        self.container:ReleaseChildren()
    end
    self.container = nil
    self.callbacks = nil
    self.dataProvider = nil
end

-- Component validation helper
function BaseComponent:validateImplementation(componentName)
    if not self.buildUI or self.buildUI == BaseComponent.buildUI then
        error(componentName .. " must implement buildUI() method")
    end
end

-- Helper function to create InlineGroup containers with consistent setup
function BaseComponent:createInlineGroup(title, container)
    local group = self.AceGUI:Create("InlineGroup")
    if title then
        group:SetTitle(title)
    end
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    
    if container then
        container:AddChild(group)
    end
    
    return group
end

return BaseComponent