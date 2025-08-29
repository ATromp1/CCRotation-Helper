local addonName, addon = ...

-- Debug-related commands: debug, debugnpc, resetdebug, icons, preview
addon.DebugCommands = {}

function addon.DebugCommands:debug()
    -- Toggle debug mode
    local currentDebug = addon.Config:Get("debugMode")
    addon.Config:Set("debugMode", not currentDebug)
    local newState = addon.Config:Get("debugMode") and "enabled" or "disabled"
    print("|cff00ff00CC Rotation Helper|r: Debug mode " .. newState)
end

function addon.DebugCommands:debugnpc()
    -- Toggle NPC debug frame
    if addon.UI then
        addon.UI:ToggleNPCDebug()
    else
        print("|cff00ff00CC Rotation Helper|r: UI not initialized")
    end
end

function addon.DebugCommands:resetdebug()
    -- Reset NPC debug frame position  
    if addon.UI then
        addon.UI:ResetNPCDebugPosition()
    else
        print("|cff00ff00CC Rotation Helper|r: UI not initialized")
    end
end

function addon.DebugCommands:icons()
    -- Show icon debug info and attempt recovery
    if addon.UI then
        addon.UI:ShowIconDebug()
    else
        print("|cff00ff00CC Rotation Helper|r: UI not initialized")
    end
end

function addon.DebugCommands:preview()
    -- Toggle config preview manually
    if addon.UI then
        if addon.UI.mainFrame and addon.UI.mainFrame.mainPreview and addon.UI.mainFrame.mainPreview:IsShown() then
            addon.UI:hideConfigPreview()
            print("|cff00ff00CC Rotation Helper|r: Config preview hidden")
        else
            addon.UI:showConfigPreview()
            print("|cff00ff00CC Rotation Helper|r: Config preview shown")
        end
    else
        print("|cff00ff00CC Rotation Helper|r: UI not initialized")
    end
end