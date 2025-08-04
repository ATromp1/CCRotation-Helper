-- NPCDebugFrame.lua - NPC debug information display component
-- Shows active NPC information above the main rotation frame

local addonName, addon = ...

local NPCDebugFrame = {}

function NPCDebugFrame:new()
    local instance = {
        frame = nil,
        textWidget = nil,
        isVisible = false,
        updateTimer = nil
    }
    setmetatable(instance, {__index = self})
    return instance
end

function NPCDebugFrame:Initialize(parentFrame)
    if self.frame then
        return
    end
    
    self.parentFrame = parentFrame
    self:createFrame()
    self:registerEvents()
end

function NPCDebugFrame:createFrame()
    self.frame = CreateFrame("Frame", "CCRotationDebugFrame", UIParent, "BackdropTemplate")
    self.frame:SetSize(300, 60)
    self.frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    self.frame:SetBackdropColor(0, 0, 0, 0.8)
    self.frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Make frame movable
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    
    -- Drag functionality
    self.frame:SetScript("OnDragStart", function(frame)
        if IsShiftKeyDown() then
            frame:StartMoving()
        end
    end)
    
    self.frame:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        frame:SetUserPlaced(true)
    end)
    
    -- Add tooltip for drag instructions
    self.frame:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:SetText("NPC Debug Frame", 1, 1, 1, 1, true)
        GameTooltip:AddLine("Shift+drag to move", 0.5, 0.5, 0.5, true)
        GameTooltip:Show()
    end)
    
    self.frame:SetScript("OnLeave", function(frame)
        GameTooltip:Hide()
    end)
    
    -- Create text display
    self.textWidget = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.textWidget:SetPoint("TOPLEFT", 8, -8)
    self.textWidget:SetPoint("BOTTOMRIGHT", -8, 8)
    self.textWidget:SetJustifyH("LEFT")
    self.textWidget:SetJustifyV("TOP")
    self.textWidget:SetText("Debug: No active NPCs")
    
    -- Set default position (WoW will restore saved position automatically)
    self:setDefaultPosition()
    
    -- Initially hide
    self.frame:Hide()
end

function NPCDebugFrame:registerEvents()
    -- Listen for queue updates to refresh debug info
    if addon.CCRotation then
        addon.CCRotation:RegisterEventListener("QUEUE_UPDATED", function()
            self:updateDebugInfo()
        end)
    end
    
    -- Create event frame to listen for combat events
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entered combat
        self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Left combat
        
        self.eventFrame:SetScript("OnEvent", function(frame, event)
            -- Update debug info when combat state changes
            self:updateDebugInfo()
        end)
    end
end

function NPCDebugFrame:updateDebugInfo()
    if not self.frame or not self.textWidget or not self.isVisible then
        return
    end
    
    local activeNPCs = self:getActiveNPCInfo()
    local debugText = self:formatDebugText(activeNPCs)
    self.textWidget:SetText(debugText)
    
    -- Auto-resize frame based on text
    self:resizeFrame(debugText)
end

function NPCDebugFrame:getActiveNPCInfo()
    local npcInfo = {}
    
    -- Clear if not in combat
    if not InCombatLockdown() then
        return npcInfo
    end
    
    if not addon.CCRotation or not addon.CCRotation.activeNPCs then
        return npcInfo
    end
    
    -- Get NPC names and count actual nameplates - only for NPCs in our database
    local npcCounts = {}
    
    -- Scan all visible nameplates to count active NPCs
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.UnitFrame.unit
        if UnitAffectingCombat(unit) and UnitIsEnemy("player", unit) then
            local guid = UnitGUID(unit)
            local npcID = self:getNPCIDFromGUID(guid)
            if npcID then
                -- Use data provider to check if NPC exists and is enabled
                if addon.DataProviders and addon.DataProviders.NPCs then
                    local effectiveness = addon.DataProviders.NPCs:getNPCEffectiveness(npcID)
                    if effectiveness then -- Only enabled NPCs return effectiveness
                        local npcName = self:getNPCName(npcID)
                        if npcName then
                            npcCounts[npcName] = (npcCounts[npcName] or 0) + 1
                        end
                    end
                end
            end
        end
    end
    
    -- Convert to sorted array
    for npcName, count in pairs(npcCounts) do
        table.insert(npcInfo, {name = npcName, count = count})
    end
    
    -- Sort by name for consistent display
    table.sort(npcInfo, function(a, b) return a.name < b.name end)
    
    return npcInfo
end

function NPCDebugFrame:getNPCIDFromGUID(guid)
    if not guid then return end
    local _, _, _, _, _, npcID = strsplit("-", guid)
    return tonumber(npcID)
end

function NPCDebugFrame:getNPCName(npcID)
    -- Try data provider first
    if addon.DataProviders and addon.DataProviders.NPCs then
        local dungeonGroups = addon.DataProviders.NPCs:getNPCsByDungeon()
        for _, dungeonGroup in ipairs(dungeonGroups) do
            for id, npcData in pairs(dungeonGroup.data.npcs) do
                if tonumber(id) == tonumber(npcID) then
                    return npcData.mobName or npcData.name
                end
            end
        end
    end
    
    -- Fallback to database
    if addon.Database and addon.Database.defaultNPCs and addon.Database.defaultNPCs[npcID] then
        local npcData = addon.Database.defaultNPCs[npcID]
        local _, _, mobName = addon.Database:ExtractDungeonInfo(npcData.name)
        return mobName or npcData.name
    end
    
    -- Fallback to NPC ID
    return "NPC " .. tostring(npcID)
end


function NPCDebugFrame:formatDebugText(npcInfo)
    if #npcInfo == 0 then
        if InCombatLockdown() then
            return "Debug: No tracked NPCs in combat"
        else
            return "Debug: Not in combat"
        end
    end
    
    local lines = {"Debug - Active NPCs:"}
    for _, npc in ipairs(npcInfo) do
        local displayName = npc.count > 1 and (npc.count .. "x " .. npc.name) or npc.name
        table.insert(lines, "  " .. displayName)
    end
    
    return table.concat(lines, "\n")
end

function NPCDebugFrame:setDefaultPosition()
    if not self.frame then return end
    
    -- Try to position above main frame if available
    if self.parentFrame and self.parentFrame:IsVisible() then
        self.frame:SetPoint("BOTTOM", self.parentFrame, "TOP", 0, 5)
    else
        -- Default to center-top of screen
        self.frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
    end
end

function NPCDebugFrame:resetPosition()
    if not self.frame then return end
    
    -- Reset to default position and clear WoW's saved position
    self.frame:ClearAllPoints()
    self:setDefaultPosition()
    self.frame:SetUserPlaced(false)
end

function NPCDebugFrame:resizeFrame(text)
    if not self.frame or not self.textWidget then
        return
    end
    
    -- Calculate required height based on text lines
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    
    local lineHeight = 14
    local padding = 16
    local newHeight = (#lines * lineHeight) + padding
    
    -- Set minimum and maximum heights
    newHeight = math.max(newHeight, 40)
    newHeight = math.min(newHeight, 200)
    
    self.frame:SetHeight(newHeight)
end

function NPCDebugFrame:Show()
    if not self.frame then
        return
    end
    
    self.isVisible = true
    self.frame:Show()
    self:updateDebugInfo()
    
    -- Start periodic updates while visible
    self:startUpdateTimer()
end

function NPCDebugFrame:Hide()
    if not self.frame then
        return
    end
    
    self.isVisible = false
    self.frame:Hide()
    self:stopUpdateTimer()
end

function NPCDebugFrame:Toggle()
    if self.isVisible then
        self:Hide()
    else
        self:Show()
    end
end

function NPCDebugFrame:startUpdateTimer()
    self:stopUpdateTimer()
    
    self.updateTimer = C_Timer.NewTicker(1, function()
        self:updateDebugInfo()
    end)
end

function NPCDebugFrame:stopUpdateTimer()
    if self.updateTimer then
        self.updateTimer:Cancel()
        self.updateTimer = nil
    end
end

function NPCDebugFrame:Cleanup()
    self:stopUpdateTimer()
    
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
        self.eventFrame = nil
    end
    
    if self.frame then
        self.frame:Hide()
        self.frame:SetParent(nil)
        self.frame = nil
    end
    
    self.textWidget = nil
    self.parentFrame = nil
end

-- Make component available globally
addon.Components = addon.Components or {}
addon.Components.NPCDebugFrame = NPCDebugFrame

return NPCDebugFrame