local addonName, addon = ...

-- LibDBIcon for minimap button
local LibDBIcon = LibStub("LibDBIcon-1.0", true)
local LibDataBroker = LibStub("LibDataBroker-1.1", true)

addon.MinimapIcon = {}


function addon.MinimapIcon:Initialize()
    -- Only initialize if LibDBIcon is available
    if not LibDBIcon or not LibDataBroker then
        return
    end

    -- Create the LibDataBroker object
    local minimapLDB = LibDataBroker:NewDataObject("CCRotationHelper", {
        type = "launcher",
        text = "CCR",
        icon = "Interface\\AddOns\\CCRotationHelper\\media\\CCRotationHelper",
        OnClick = function(frame, button)
            if button == "LeftButton" then
                -- Left click - open config panel
                if addon.UI and addon.UI.ShowConfigFrame then
                    addon.UI:ShowConfigFrame()
                else
                    print("|cff00ff00CC Rotation Helper|r: Configuration UI not available")
                end
            elseif button == "RightButton" then
                -- Right click - toggle addon
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
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            tooltip:AddLine("CC Rotation Helper")
            tooltip:AddLine("|cffeda55fLeft Click:|r Open Configuration")
            tooltip:AddLine("|cffeda55fRight Click:|r Toggle Enable/Disable")
            tooltip:AddLine("|cffeda55fShift+Left Click:|r Toggle Frame Lock")
            
            -- Show current status
            local enabled = addon.Config:Get("enabled")
            local locked = addon.Config:Get("anchorLocked")
            if enabled then
                tooltip:AddLine("|cff00ff00Status: Enabled|r")
            else
                tooltip:AddLine("|cffff0000Status: Disabled|r")
            end
            tooltip:AddLine("|cffccccccFrame: " .. (locked and "Locked" or "Unlocked") .. "|r")
        end,
        OnReceiveDrag = function()
            -- Handle drag functionality if needed
        end,
    })

    -- Handle Shift+Left Click for anchor lock toggle
    local originalOnClick = minimapLDB.OnClick
    minimapLDB.OnClick = function(frame, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            -- Toggle anchor lock
            local currentLock = addon.Config:Get("anchorLocked")
            addon.Config:Set("anchorLocked", not currentLock)
            -- Update mouse settings when anchor lock changes
            if addon.UI and addon.UI.UpdateMouseSettings then
                addon.UI:UpdateMouseSettings()
            end
            print("|cff00ff00CC Rotation Helper|r: Frame " .. (currentLock and "unlocked" or "locked"))
        else
            originalOnClick(frame, button)
        end
    end

    -- Initialize LibDBIcon with saved variables
    if not addon.Config.db.minimap then
        addon.Config.db.minimap = {
            minimapPos = 220,
            radius = 80,
        }
    end

    -- Register the minimap icon
    LibDBIcon:Register("CCRotationHelper", minimapLDB, addon.Config.db.minimap)
end

