local addonName, addon = ...

-- Unified Event System for CCRotationHelper
-- Replaces duplicate event systems in Config.lua, RotationCore.lua, and BaseComponent.lua
addon.EventSystem = {}

-- Global event listeners storage
local eventListeners = {}

-- Register event listener
function addon.EventSystem:RegisterEventListener(event, callback)
    if not eventListeners[event] then
        eventListeners[event] = {}
    end
    table.insert(eventListeners[event], callback)
end

-- Fire event to all listeners
function addon.EventSystem:FireEvent(event, ...)
    if eventListeners[event] then
        for _, callback in ipairs(eventListeners[event]) do
            callback(...)
        end
    end
end

-- Unregister event listener (for cleanup)
function addon.EventSystem:UnregisterEventListener(event, callback)
    if not eventListeners[event] then
        return
    end
    
    for i, registeredCallback in ipairs(eventListeners[event]) do
        if registeredCallback == callback then
            table.remove(eventListeners[event], i)
            break
        end
    end
    
    -- Clean up empty event arrays
    if #eventListeners[event] == 0 then
        eventListeners[event] = nil
    end
end

-- Get count of listeners for debugging
function addon.EventSystem:GetListenerCount(event)
    if not eventListeners[event] then
        return 0
    end
    return #eventListeners[event]
end

-- Clear all listeners for an event (for debugging/cleanup)
function addon.EventSystem:ClearEventListeners(event)
    eventListeners[event] = nil
end

-- Debug function to list all registered events
function addon.EventSystem:GetRegisteredEvents()
    local events = {}
    for event, listeners in pairs(eventListeners) do
        table.insert(events, {
            event = event,
            listenerCount = #listeners
        })
    end
    return events
end