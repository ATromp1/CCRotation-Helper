local addonName, addon = ...

-- Core addon commands: config, toggle, reset
addon.CoreCommands = {}

function addon.CoreCommands:config()
    if addon.UI and addon.UI.ShowConfigFrame then
        addon.UI:ShowConfigFrame()
    else
        print("|cff00ff00CC Rotation Helper|r: Configuration UI not available")
    end
end

function addon.CoreCommands:toggle()
    local enabled = addon.Config:Get("enabled")
    addon.Config:Set("enabled", not enabled)
    print("|cff00ff00CC Rotation Helper|r: " .. (enabled and "Disabled" or "Enabled"))
    
    if addon.UI then
        if enabled then
            addon.UI:Hide()
        else
            addon.UI:Show()
        end
    end
end

function addon.CoreCommands:reset()
    -- Reset position to default and clear WoW's saved position
    if addon.UI and addon.UI.mainFrame then
        addon.UI.mainFrame:ClearAllPoints()
        addon.UI.mainFrame:SetPoint("CENTER", UIParent, "CENTER", 354, 134)
        -- Clear WoW's saved position so it uses our default
        addon.UI.mainFrame:SetUserPlaced(false)
        print("|cff00ff00CC Rotation Helper|r: Position reset to default")
    else
        print("|cff00ff00CC Rotation Helper|r: Cannot reset position - UI not initialized")
    end
end