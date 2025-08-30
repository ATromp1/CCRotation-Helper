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

function addon.DebugCommands:debugframe()
    -- Show general debug frame with tabs
    if addon.DebugFrame then
        addon.DebugFrame:ShowFrame("General", "General Debug")
        -- Test messages for different categories
        addon.DebugFrame:Print("General", "SPELL", "=== SPELL DEBUG FRAME TEST ===")
        addon.DebugFrame:Print("General", "ERROR", "Error messages appear in ERROR tab")
        addon.DebugFrame:Print("General", "INIT", "Initialization messages appear in INIT tab")
        print("|cff00ff00CC Rotation Helper|r: General debug frame shown with tabs")
    else
        print("|cff00ff00CC Rotation Helper|r: DebugFrame not initialized")
    end
end