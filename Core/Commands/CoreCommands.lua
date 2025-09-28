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
    -- Reset position to default and clear saved position
    if addon.UI and addon.UI.mainFrame then
        -- Clear saved position from config
        addon.Config:Set("frameTop", nil)
        addon.Config:Set("frameLeft", nil)

        -- Reset frame position
        addon.UI.mainFrame:ClearAllPoints()
        addon.UI.mainFrame:SetPoint("CENTER", UIParent, "CENTER", 354, 134)
        addon.UI.mainFrame:SetUserPlaced(false)
        print("|cff00ff00CC Rotation Helper|r: Position reset to default")
    else
        print("|cff00ff00CC Rotation Helper|r: Cannot reset position - UI not initialized")
    end
end

function addon.CoreCommands:testteams()
    if addon.InterruptTeams then
        -- Print available group members for debugging
        local members = addon.InterruptTeams:GetAvailableGroupMembers()
        print("Available group members with interrupts:")
        for i, memberName in ipairs(members) do
            print("  " .. i .. ": " .. memberName)
        end
        print("Group info: IsInGroup=" .. tostring(IsInGroup()) .. ", NumMembers=" .. GetNumGroupMembers())

        -- Print all group members (even without interrupts)
        print("All group members:")
        for i = 1, GetNumGroupMembers() do
            local unit
            if IsInRaid() then
                unit = "raid" .. i
            else
                -- In party: i=1 is player, i=2 is party1, i=3 is party2, etc.
                if i == 1 then
                    unit = "player"
                else
                    unit = "party" .. (i - 1)
                end
            end
            local name = UnitName(unit)
            local _, class = UnitClass(unit)
            local interruptSpell = addon.InterruptTeams:GetPlayerInterruptSpell(name)
            print("  " .. i .. ": " .. (name or "nil") .. " (" .. (class or "nil") .. ") - Interrupt: " .. (interruptSpell or "none"))
        end

        addon.InterruptTeams:PrintTeams()

        -- Also print raw config data
        if addon.Config and addon.Config.db then
            print("Raw config data:")
            local teams = addon.Config.db.interruptTeams
            if teams then
                for i = 1, 8 do
                    if teams[i] and #teams[i] > 0 then
                        print("  Marker " .. i .. ": " .. table.concat(teams[i], ", "))
                    end
                end
            else
                print("  interruptTeams table is nil")
            end
        else
            print("  Config not available")
        end
    else
        print("CCR: InterruptTeams not available")
    end
end