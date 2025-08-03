-- ConfigDataProvider.lua - Data abstraction layer for configuration components
-- Provides clean interface between components and configuration system

local addonName, addon = ...

local ConfigDataProvider = {}

-- Get configuration value
function ConfigDataProvider:get(key)
    local value = addon.Config:Get(key)
    -- Handle defaults for values that might not exist in older configs
    if key == "cooldownFontSizePercent" and value == nil then
        return 25
    end
    return value
end

-- Set configuration value
function ConfigDataProvider:set(key, value)
    addon.Config:Set(key, value)
end

-- Refresh display after configuration changes
function ConfigDataProvider:refreshDisplay()
    if addon.UI.RefreshDisplay then
        addon.UI:RefreshDisplay()
    end
end

-- Update visibility (for enabled/showInSolo settings)
function ConfigDataProvider:updateVisibility()
    if addon.UI.UpdateVisibility then
        addon.UI:UpdateVisibility()
    end
end

-- Update mouse settings (for tooltips/anchor lock)
function ConfigDataProvider:updateMouseSettings()
    if addon.UI.UpdateMouseSettings then
        addon.UI:UpdateMouseSettings()
    end
end

-- Rebuild queue (for settings that affect rotation logic)
function ConfigDataProvider:rebuildQueue()
    if addon.CCRotation and addon.CCRotation.RebuildQueue then
        addon.CCRotation:RebuildQueue()
    end
end

-- Register in addon namespace
if not addon.DataProviders then
    addon.DataProviders = {}
end
addon.DataProviders.Config = ConfigDataProvider

return ConfigDataProvider