local addonName, addon = ...

-- Get AceGUI reference
local AceGUI = LibStub("AceGUI-3.0")

addon.UI = {}
local UI = addon.UI

-- Icon pooling system (following OmniCD's approach)
local iconPool = {}
local activeIcons = {}
local numIconsCreated = 0

-- Initialize UI system
function UI:Initialize()
    if self.mainFrame then return end
    
    -- Create main frame using XML template
    self.mainFrame = CreateFrame("Frame", "CCRotationMainFrame", UIParent, "CCRotationTemplate")
    self:SetupMainFrame()
    
    -- Initialize icon pool
    self:InitializeIconPool()
    
    -- Start cooldown text update timer
    self:StartCooldownTextUpdates()
    
    -- Update position and visibility
    self:UpdatePosition()
    self:UpdateVisibility()
end

-- Setup main frame properties
function UI:SetupMainFrame()
    local frame = self.mainFrame
    local config = addon.Config
    
    -- Set initial size and position
    frame:SetSize(200, 64)
    frame:SetPoint("CENTER", UIParent, "CENTER", 
        config:Get("xOffset"), config:Get("yOffset"))
    
    -- Make frame movable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    
    frame:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relativePoint, x, y = self:GetPoint()
        addon.Config:Set("xOffset", x)
        addon.Config:Set("yOffset", y)
    end)
    
    -- Tooltip for moving
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("CC Rotation Helper")
        GameTooltip:AddLine("Shift + drag to move", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

-- Initialize icon pool system
function UI:InitializeIconPool()
    iconPool = {}
    activeIcons = {}
    numIconsCreated = 0
end

-- Get icon from pool or create new one (OmniCD approach)
function UI:GetIcon()
    local icon = table.remove(iconPool)
    if not icon then
        numIconsCreated = numIconsCreated + 1
        icon = CreateFrame("Button", "CCRotationIcon" .. numIconsCreated, UIParent, "CCRotationIconTemplate")
        
        -- Create working texture (XML template texture has issues)
        icon.displayTexture = icon:CreateTexture("DisplayTexture_" .. numIconsCreated, "OVERLAY")
        icon.displayTexture:SetAllPoints()
        icon.displayTexture:SetTexelSnappingBias(0.0)
        icon.displayTexture:SetSnapToPixelGrid(false)
        
        -- Hide the XML template icon texture
        if icon.icon then
            icon.icon:Hide()
        end
        
        -- Setup fonts using LibSharedMedia (cooldown font size will be set per icon)
        local config = addon.Config
        config:SetFontProperties(icon.spellName, config:Get("spellNameFont"), config:Get("spellNameFontSize"))
        config:SetFontProperties(icon.playerName, config:Get("playerNameFont"), config:Get("playerNameFontSize"))
        
        -- Set text colors
        icon.spellName:SetTextColor(unpack(config:Get("spellNameColor")))
        icon.playerName:SetTextColor(unpack(config:Get("spellNameColor")))
        icon.cooldownText:SetTextColor(unpack(config:Get("cooldownTextColor")))
        
        -- Hide countdown numbers from cooldown frame
        icon.cooldown:SetHideCountdownNumbers(true)
        
        -- Setup click handlers (optional)
        icon:SetScript("OnEnter", function(self)
            if self.spellInfo and self.unit then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(self.spellInfo.spellID)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Player: " .. (UnitName(self.unit) or "Unknown"), 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        
        icon:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end
    
    -- Set parent and reset state
    icon:SetParent(self.mainFrame.container)
    icon:ClearAllPoints()
    icon:Hide()
    
    -- Reset all visual state
    icon.spellName:SetText("")
    icon.playerName:SetText("")
    icon.cooldownText:SetText("")
    icon.displayTexture:SetTexture(nil)
    icon.displayTexture:Hide()
    icon.glow:Hide()
    icon.cooldown:Clear()
    icon.cooldown:Hide()
    
    -- Stop any animations
    if icon.animFrame.pulseAnim:IsPlaying() then
        icon.animFrame.pulseAnim:Stop()
    end
    
    return icon
end

-- Return icon to pool
function UI:ReleaseIcon(icon)
    if icon then
        icon:Hide()
        icon:SetParent(UIParent)
        icon:ClearAllPoints()
        
        -- Clear references
        icon.spellInfo = nil
        icon.unit = nil
        icon.queueData = nil
        
        table.insert(iconPool, icon)
        
        -- Remove from active icons
        for i, activeIcon in ipairs(activeIcons) do
            if activeIcon == icon then
                table.remove(activeIcons, i)
                break
            end
        end
    end
end

-- Start continuous cooldown text updates
function UI:StartCooldownTextUpdates()
    if self.cooldownUpdateTimer then
        self.cooldownUpdateTimer:Cancel()
    end
    
    local function updateCooldownText()
        self:UpdateCooldownText()
        self.cooldownUpdateTimer = C_Timer.After(0.1, updateCooldownText)
    end
    
    updateCooldownText()
end

-- Stop cooldown text updates
function UI:StopCooldownTextUpdates()
    if self.cooldownUpdateTimer then
        self.cooldownUpdateTimer:Cancel()
        self.cooldownUpdateTimer = nil
    end
end

-- Update only the cooldown text on visible icons
function UI:UpdateCooldownText()
    if not addon.Config:Get("showCooldownText") then
        return
    end
    
    local now = GetTime()
    
    for i, icon in ipairs(activeIcons) do
        if icon.queueData and icon:IsShown() then
            local cooldownData = icon.queueData
            local charges = cooldownData.charges or 0
            local isReady = charges > 0 or cooldownData.expirationTime <= now
            
            if isReady then
                icon.cooldownText:SetText("")
            else
                local timeLeft = cooldownData.expirationTime - now
                icon.cooldownText:SetText(self:FormatTime(timeLeft))
            end
        end
    end
end

-- Refresh display with current queue (forces immediate redraw)
function UI:RefreshDisplay()
    -- Update font properties for existing icons
    local config = addon.Config
    for i, icon in ipairs(activeIcons) do
        if icon then
            config:SetFontProperties(icon.spellName, config:Get("spellNameFont"), config:Get("spellNameFontSize"))
            config:SetFontProperties(icon.playerName, config:Get("playerNameFont"), config:Get("playerNameFontSize"))
            
            -- Calculate cooldown font size based on this icon's size
            local iconSize = config:Get("iconSize" .. i)
            local cooldownFontPercent = config:Get("cooldownFontSizePercent") or 25
            local cooldownFontSize = math.floor(iconSize * cooldownFontPercent / 100)
            config:SetFontProperties(icon.cooldownText, config:Get("cooldownFont"), cooldownFontSize)
        end
    end
    
    if addon.CCRotation and addon.CCRotation.cooldownQueue then
        self:UpdateDisplay(addon.CCRotation.cooldownQueue)
    end
end

-- Update display with current queue (main function)
function UI:UpdateDisplay(queue)
    if not self.mainFrame or not self.mainFrame.container then return end
    
    -- Add null check for queue
    if not queue then
        return
    end
    
    local config = addon.Config
    local maxIcons = config:Get("maxIcons")
    local spacing = config:Get("spacing")
    local now = GetTime()
    
    -- Release all current icons back to pool
    for i = #activeIcons, 1, -1 do
        self:ReleaseIcon(activeIcons[i])
    end
    wipe(activeIcons)
    
    -- Update frame visibility
    if not addon.CCRotation:ShouldBeActive() then
        self.mainFrame:Hide()
        return
    end
    
    self.mainFrame:Show()
    
    -- Create and position icons for current queue
    for i = 1, math.min(#queue, maxIcons) do
        local cooldownData = queue[i]
        if cooldownData then
            local icon = self:GetIcon()
            table.insert(activeIcons, icon)
            
            -- Set icon data
            icon.queueData = cooldownData
            icon.unit = addon.CCRotation.GUIDToUnit[cooldownData.GUID]
            icon.spellInfo = C_Spell.GetSpellInfo(cooldownData.spellID)
            
            if icon.spellInfo and icon.unit then
                -- Set icon texture using working approach
                icon.displayTexture:SetTexture(icon.spellInfo.iconID)
                icon.displayTexture:Show()
                
                -- Set spell name (using individual icon setting)
                if config:Get("showSpellName" .. i) then
                    local spellName = self:TruncateText(icon.spellInfo.name, config:Get("spellNameMaxLength"))
                    icon.spellName:SetText(spellName)
                    icon.spellName:Show()
                else
                    icon.spellName:Hide()
                end
                
                -- Set player name with class color (using individual icon setting)
                if config:Get("showPlayerName" .. i) then
                    local name = UnitName(icon.unit)
                    if name then
                        local truncatedName = self:TruncateText(name, config:Get("playerNameMaxLength"))
                        local classFileName = UnitClassBase(icon.unit)
                        local classColor = RAID_CLASS_COLORS[classFileName]
                        if classColor and classColor.colorStr then
                            icon.playerName:SetText(string.format("|c%s%s|r", classColor.colorStr, truncatedName))
                        else
                            icon.playerName:SetText(truncatedName)
                        end
                    else
                        icon.playerName:SetText("Unknown")
                    end
                    icon.playerName:Show()
                else
                    icon.playerName:Hide()
                end
                
                -- Set cooldown
                local charges = cooldownData.charges or 0
                local isReady = charges > 0 or cooldownData.expirationTime <= now
                
                if isReady then
                    icon.cooldown:Clear()
                    icon.cooldown:Hide()
                    icon.cooldownText:SetText("")
                else
                    icon.cooldown:SetCooldown(now, cooldownData.expirationTime - now)
                    icon.cooldown:Show()
                    if config:Get("showCooldownText") then
                        local timeLeft = cooldownData.expirationTime - now
                        icon.cooldownText:SetText(self:FormatTime(timeLeft))
                    else
                        icon.cooldownText:SetText("")
                    end
                end
                
                -- Handle glow effect for "next" spell (second in queue)
                if i == 2 and config:Get("highlightNext") then
                    icon.glow:SetAlpha(1)
                    icon.glow:Show()
                    icon.animFrame.pulseAnim:Play()
                else
                    icon.glow:Hide()
                    icon.glow:SetAlpha(0)
                    if icon.animFrame.pulseAnim:IsPlaying() then
                        icon.animFrame.pulseAnim:Stop()
                    end
                end
                
                -- Position and size icon using individual size
                local iconSize = config:Get("iconSize" .. i)
                icon:SetSize(iconSize, iconSize)
                
                -- Set cooldown font size based on icon size and percentage
                local cooldownFontPercent = config:Get("cooldownFontSizePercent") or 25
                local cooldownFontSize = math.floor(iconSize * cooldownFontPercent / 100)
                config:SetFontProperties(icon.cooldownText, config:Get("cooldownFont"), cooldownFontSize)
                
                if i == 1 then
                    icon:SetPoint("BOTTOMLEFT", self.mainFrame.container, "BOTTOMLEFT", 0, 0)
                else
                    icon:SetPoint("BOTTOMLEFT", activeIcons[i-1], "BOTTOMRIGHT", spacing, 0)
                end
                
                -- Set adaptive glow size (25% larger than icon)
                local glowSize = iconSize * 1.25
                icon.glow:SetSize(glowSize, glowSize)
                if icon.animFrame and icon.animFrame.glowAnim then
                    icon.animFrame.glowAnim:SetSize(glowSize, glowSize)
                end
                
                icon:Show()
            end
        end
    end
    
    -- Update main frame size
    self:UpdateFrameSize()
end

-- Truncate text to max length (simple cut-off)
function UI:TruncateText(text, maxLength)
    if not text or text == "" then
        return ""
    end
    
    if string.len(text) <= maxLength then
        return text
    else
        return string.sub(text, 1, maxLength)
    end
end

-- Format time for display (same as before)
function UI:FormatTime(seconds)
    if seconds <= 0 then
        return ""
    elseif seconds < addon.Config:Get("cooldownDecimalThreshold") then
        return string.format("%.1f", seconds)
    elseif seconds < 60 then
        return string.format("%.0f", seconds)
    else
        local minutes = math.floor(seconds / 60)
        local secs = seconds % 60
        return string.format("%d:%02d", minutes, secs)
    end
end

-- Update main frame size based on visible icons
function UI:UpdateFrameSize()
    local config = addon.Config
    local spacing = config:Get("spacing")
    local visibleIcons = #activeIcons
    
    if visibleIcons > 0 then
        local totalWidth = 0
        local maxHeight = 0
        
        -- Calculate total width and max height using individual icon sizes
        for i = 1, visibleIcons do
            local iconSize = config:Get("iconSize" .. i)
            totalWidth = totalWidth + iconSize
            if i > 1 then
                totalWidth = totalWidth + spacing
            end
            if iconSize > maxHeight then
                maxHeight = iconSize
            end
        end
        
        self.mainFrame:SetSize(totalWidth, maxHeight)
    else
        self.mainFrame:SetSize(1, 1)
    end
end

-- Update position from config
function UI:UpdatePosition()
    if not self.mainFrame then return end
    
    local config = addon.Config
    self.mainFrame:ClearAllPoints()
    self.mainFrame:SetPoint("CENTER", UIParent, "CENTER", 
        config:Get("xOffset"), config:Get("yOffset"))
end

-- Update visibility based on config and group status
function UI:UpdateVisibility()
    if not self.mainFrame then return end
    
    if addon.CCRotation:ShouldBeActive() then
        self.mainFrame:Show()
        self:StartCooldownTextUpdates()
    else
        self.mainFrame:Hide()
        self:StopCooldownTextUpdates()
    end
end

-- Show the UI
function UI:Show()
    if self.mainFrame then
        self.mainFrame:Show()
    end
    self:StartCooldownTextUpdates()
end

-- Hide the UI
function UI:Hide()
    if self.mainFrame then
        self.mainFrame:Hide()
    end
    self:StopCooldownTextUpdates()
end

-- Toggle the UI
function UI:Toggle()
    if self.mainFrame then
        if self.mainFrame:IsShown() then
            self:Hide()
        else
            self:Show()
        end
    end
end

-- AceGUI utility functions (keeping from previous implementation)
function UI:ShowNotification(title, message, callback)
    local notification = AceGUI:Create("Frame")
    notification:SetTitle(title)
    notification:SetWidth(300)
    notification:SetHeight(150)
    notification:SetLayout("Flow")
    notification:SetCallback("OnClose", function(widget)
        if callback then callback() end
        AceGUI:Release(widget)
    end)
    
    local label = AceGUI:Create("Label")
    label:SetText(message)
    label:SetFullWidth(true)
    notification:AddChild(label)
    
    local button = AceGUI:Create("Button")
    button:SetText("OK")
    button:SetWidth(100)
    button:SetCallback("OnClick", function()
        notification:Hide()
    end)
    notification:AddChild(button)
    
    return notification
end
