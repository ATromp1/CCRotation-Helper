local addonName, addon = ...

-- Get AceGUI reference
local AceGUI = LibStub("AceGUI-3.0")

addon.UI = {}
local UI = addon.UI

-- Icon pooling system (following OmniCD's approach)
local iconPool = {}
local activeIcons = {}
local numIconsCreated = 0

-- Unavailable queue icon pooling
local unavailableIconPool = {}
local activeUnavailableIcons = {}
local numUnavailableIconsCreated = 0

-- Initialize UI system with robust error handling
function UI:Initialize()
    if self.mainFrame then 
        addon.Config:DebugPrint("Initialize called but mainFrame already exists")
        return 
    end
    
    addon.Config:DebugPrint("Initializing UI system")
    
    -- Create main frame using XML template with error handling
    local success = pcall(function()
        self.mainFrame = CreateFrame("Frame", "CCRotationMainFrame", UIParent, "CCRotationTemplate")
    end)
    
    if not success or not self.mainFrame then
        addon.Config:DebugPrint("Failed to create mainFrame with template, creating basic frame")
        -- Fallback: create basic frame without template
        self.mainFrame = CreateFrame("Frame", "CCRotationMainFrame", UIParent)
        self.mainFrame:SetSize(200, 64)
        
        -- Create basic container
        self.mainFrame.container = CreateFrame("Frame", nil, self.mainFrame)
        self.mainFrame.container:SetAllPoints()
        
        -- Create visible debug anchor (the "red box")
        self.mainFrame.anchor = CreateFrame("Frame", nil, UIParent)  -- Parent to UIParent so it's always on top
        self.mainFrame.anchor:SetSize(20, 20)  -- Larger size
        self.mainFrame.anchor:SetFrameStrata("TOOLTIP")  -- High strata to appear on top
        self.mainFrame.anchor:SetFrameLevel(1000)  -- Very high frame level
        
        -- Create border texture
        local border = self.mainFrame.anchor:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints()
        border:SetColorTexture(1, 0, 0, 1.0)  -- Solid red border
        
        -- Create inner transparent area
        local inner = self.mainFrame.anchor:CreateTexture(nil, "BACKGROUND")
        inner:SetPoint("TOPLEFT", 2, -2)
        inner:SetPoint("BOTTOMRIGHT", -2, 2)
        inner:SetColorTexture(0, 0, 0, 0.3)  -- Semi-transparent black center
        
        -- Store references
        self.mainFrame.anchor.border = border
        self.mainFrame.anchor.inner = inner
        
        self.mainFrame.anchor:Hide()  -- Hidden by default
    end

    -- Always create debug anchor regardless of which frame creation method was used
    if not self.mainFrame.anchor then
        addon.Config:DebugPrint("Creating debug anchor")
        self.mainFrame.anchor = CreateFrame("Frame", "CCRotationDebugAnchor", UIParent)
        self.mainFrame.anchor:SetSize(20, 20)
        self.mainFrame.anchor:SetFrameStrata("TOOLTIP")
        self.mainFrame.anchor:SetFrameLevel(1000)
        
        -- Create border texture
        local border = self.mainFrame.anchor:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints()
        border:SetColorTexture(1, 0, 0, 1.0)  -- Solid red border
        
        -- Create inner transparent area
        local inner = self.mainFrame.anchor:CreateTexture(nil, "BACKGROUND")
        inner:SetPoint("TOPLEFT", 2, -2)
        inner:SetPoint("BOTTOMRIGHT", -2, 2)
        inner:SetColorTexture(0, 0, 0, 0.3)  -- Semi-transparent black center
        
        -- Store references
        self.mainFrame.anchor.border = border
        self.mainFrame.anchor.inner = inner
        
        self.mainFrame.anchor:Hide()  -- Hidden by default
        addon.Config:DebugPrint("Debug anchor created successfully")
    end

    -- Setup main frame properties
    local setupSuccess = pcall(function()
        self:SetupMainFrame()
    end)
    
    if not setupSuccess then
        addon.Config:DebugPrint("Failed to setup mainFrame properly")
        return
    end
    
    -- Initialize icon pool
    self:InitializeIconPool()
    
    -- Start cooldown text update timer
    self:StartCooldownTextUpdates()
    
    -- Show UI if should be active
    C_Timer.After(0.1, function()
        self:UpdateVisibility()
    end)
    
    addon.Config:DebugPrint("UI initialization complete")
end

-- Setup main frame properties
function UI:SetupMainFrame()
    local frame = self.mainFrame
    local config = addon.Config
    
    frame:SetSize(200, 64)

    -- Enable mouse if frame is unlocked OR tooltips are enabled
    frame:EnableMouse(not config:Get("anchorLocked") or config:Get("showTooltips"))
    
    -- Add drag functionality for Shift+click
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() and not config:Get("anchorLocked") then
            self:StartMoving()
        end
    end)
    
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Tell WoW that this frame has been moved by the user and should be saved
        self:SetUserPlaced(true)
    end)

    -- Create unavailable queue container
    frame.unavailableContainer = CreateFrame("Frame", nil, frame)
    frame.unavailableContainer:SetSize(1, 1)
    -- Position will be set dynamically in UpdateFrameSize based on content
end


-- Initialize icon pool system
function UI:InitializeIconPool()
    iconPool = {}
    activeIcons = {}
    numIconsCreated = 0
    unavailableIconPool = {}
    activeUnavailableIcons = {}
    numUnavailableIconsCreated = 0
end

-- Get icon from pool or create new one (OmniCD approach)
function UI:GetIcon()
    local icon = table.remove(iconPool)
    if not icon then
        numIconsCreated = numIconsCreated + 1
        icon = CreateFrame("Button", "CCRotationIcon" .. numIconsCreated, UIParent, "CCRotationIconTemplate")
        
        -- Enable clipping to properly mask zoomed textures (like WeakAuras)
        icon:SetClipsChildren(true)
        
        -- Create working texture (XML template texture has issues) - use ARTWORK layer
        icon.displayTexture = icon:CreateTexture("DisplayTexture_" .. numIconsCreated, "ARTWORK")
        icon.displayTexture:SetAllPoints()
        icon.displayTexture:SetTexelSnappingBias(0.0)
        icon.displayTexture:SetSnapToPixelGrid(false)
        
        -- Create status indicator textures
        icon.deadIndicator = icon:CreateTexture("DeadIndicator_" .. numIconsCreated, "OVERLAY", nil, 1)
        icon.deadIndicator:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        icon.deadIndicator:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -2, -2)
        icon.deadIndicator:Hide()
        
        icon.rangeIndicator = icon:CreateTexture("RangeIndicator_" .. numIconsCreated, "OVERLAY", nil, 1)
        icon.rangeIndicator:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
        icon.rangeIndicator:SetPoint("TOPLEFT", icon, "TOPLEFT", 2, -2)
        icon.rangeIndicator:Hide()
        
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
        
        -- Setup click handlers and drag passthrough
        -- Only enable mouse if tooltips are enabled
        icon:EnableMouse(addon.Config:Get("showTooltips"))
        
        icon:SetScript("OnEnter", function(self)
            if addon.Config:Get("showTooltips") and self.spellInfo and self.unit then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(self.spellInfo.spellID)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Player: " .. (UnitName(self.unit) or "Unknown"), 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        
        icon:SetScript("OnLeave", function(self)
            if addon.Config:Get("showTooltips") then
                GameTooltip:Hide()
            end
        end)
        
        -- Pass through drag events to main frame (for tooltip-enabled icons)
        icon:RegisterForDrag("LeftButton")
        icon:SetScript("OnDragStart", function(self)
            if IsShiftKeyDown() and not addon.Config:Get("anchorLocked") then
                -- Pass drag to main frame: icon -> container -> mainFrame
                local mainFrame = self:GetParent():GetParent()
                mainFrame:StartMoving()
            end
        end)
        
        icon:SetScript("OnDragStop", function(self)
            local mainFrame = self:GetParent():GetParent()
            mainFrame:StopMovingOrSizing()
            -- Tell WoW that this frame has been moved by the user and should be saved
            mainFrame:SetUserPlaced(true)
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
    icon.displayTexture:SetDesaturated(false)
    icon.displayTexture:Hide()
    icon.displayTexture:ClearAllPoints()
    icon.displayTexture:SetAllPoints(icon)
    icon.glow:Hide()
    icon.cooldown:Clear()
    icon.cooldown:Hide()
    icon.deadIndicator:Hide()
    icon.rangeIndicator:Hide()
    
    -- Stop any animations
    if icon.animFrame.pulseAnim:IsPlaying() then
        icon.animFrame.pulseAnim:Stop()
    end
    
    return icon
end

-- Get unavailable icon from pool or create new one
function UI:GetUnavailableIcon()
    local icon = table.remove(unavailableIconPool)
    if not icon then
        numUnavailableIconsCreated = numUnavailableIconsCreated + 1
        icon = CreateFrame("Button", "CCRotationUnavailableIcon" .. numUnavailableIconsCreated, UIParent, "CCRotationIconTemplate")
        
        -- Enable clipping to properly mask zoomed textures (like WeakAuras)
        icon:SetClipsChildren(true)
        
        -- Create working texture (smaller for unavailable queue) - use ARTWORK layer
        icon.displayTexture = icon:CreateTexture("DisplayTextureUnavailable_" .. numUnavailableIconsCreated, "ARTWORK")
        icon.displayTexture:SetAllPoints()
        icon.displayTexture:SetTexelSnappingBias(0.0)
        icon.displayTexture:SetSnapToPixelGrid(false)
        
        -- Create status indicator textures (same as main icons)
        icon.deadIndicator = icon:CreateTexture("DeadIndicatorUnavailable_" .. numUnavailableIconsCreated, "OVERLAY", nil, 1)
        icon.deadIndicator:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        icon.deadIndicator:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -1, -1)
        icon.deadIndicator:Hide()
        
        icon.rangeIndicator = icon:CreateTexture("RangeIndicatorUnavailable_" .. numUnavailableIconsCreated, "OVERLAY", nil, 1)
        icon.rangeIndicator:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
        icon.rangeIndicator:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
        icon.rangeIndicator:Hide()
        
        -- Hide the XML template icon texture
        if icon.icon then
            icon.icon:Hide()
        end
        
        -- Setup smaller fonts for unavailable icons
        local config = addon.Config
        local fontSize = math.max(8, config:Get("unavailableIconSize") * 0.2)
        config:SetFontProperties(icon.spellName, config:Get("spellNameFont"), fontSize)
        config:SetFontProperties(icon.playerName, config:Get("playerNameFont"), fontSize)
        config:SetFontProperties(icon.cooldownText, config:Get("cooldownFont"), fontSize)
        
        -- Set text colors
        icon.spellName:SetTextColor(unpack(config:Get("spellNameColor")))
        icon.playerName:SetTextColor(unpack(config:Get("spellNameColor")))
        icon.cooldownText:SetTextColor(unpack(config:Get("cooldownTextColor")))
        
        -- Hide countdown numbers from cooldown frame
        icon.cooldown:SetHideCountdownNumbers(true)
        
        -- Setup click handlers and drag passthrough (minimal for unavailable)
        -- Only enable mouse if tooltips are enabled
        icon:EnableMouse(addon.Config:Get("showTooltips"))
        
        icon:SetScript("OnEnter", function(self)
            if addon.Config:Get("showTooltips") and self.spellInfo and self.unit then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(self.spellInfo.spellID)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Player: " .. (UnitName(self.unit) or "Unknown"), 1, 1, 1)
                if self.queueData and self.queueData.isDead then
                    GameTooltip:AddLine("Status: Dead", 1, 0, 0)
                elseif self.queueData and not self.queueData.inRange then
                    GameTooltip:AddLine("Status: Out of Range", 1, 1, 0)
                end
                GameTooltip:Show()
            end
        end)
        
        icon:SetScript("OnLeave", function(self)
            if addon.Config:Get("showTooltips") then
                GameTooltip:Hide()
            end
        end)
        
        -- Pass through drag events to main frame (for tooltip-enabled unavailable icons)
        icon:RegisterForDrag("LeftButton")
        icon:SetScript("OnDragStart", function(self)
            if IsShiftKeyDown() and not addon.Config:Get("anchorLocked") then
                -- Pass drag to main frame: icon -> unavailableContainer -> mainFrame
                local mainFrame = self:GetParent():GetParent()
                mainFrame:StartMoving()
            end
        end)
        
        icon:SetScript("OnDragStop", function(self)
            local mainFrame = self:GetParent():GetParent()
            mainFrame:StopMovingOrSizing()
            -- Tell WoW that this frame has been moved by the user and should be saved
            mainFrame:SetUserPlaced(true)
        end)
        
    end
    
    -- Set parent and reset state
    icon:SetParent(self.mainFrame.unavailableContainer)
    icon:ClearAllPoints()
    icon:Hide()
    
    -- Reset all visual state
    icon.spellName:SetText("")
    icon.playerName:SetText("")
    icon.cooldownText:SetText("")
    icon.displayTexture:SetTexture(nil)
    icon.displayTexture:SetDesaturated(true)  -- Always desaturated for unavailable
    icon.displayTexture:Hide()
    icon.displayTexture:ClearAllPoints()
    icon.displayTexture:SetAllPoints(icon)
    icon.glow:Hide()
    icon.cooldown:Clear()
    icon.cooldown:Hide()
    icon.deadIndicator:Hide()
    icon.rangeIndicator:Hide()
    
    -- Stop any animations
    if icon.animFrame.pulseAnim:IsPlaying() then
        icon.animFrame.pulseAnim:Stop()
    end
    
    return icon
end

-- Helper function to clear icon text elements
function UI:ClearIconText(icon)
    if not icon then return end
    
    if icon.spellName then
        icon.spellName:Hide()
        icon.spellName:SetText("")
    end
    if icon.playerName then
        icon.playerName:Hide()
        icon.playerName:SetText("")
    end
    if icon.cooldownText then
        icon.cooldownText:SetText("")
    end
end

-- Return icon to pool
function UI:ReleaseIcon(icon)
    if icon then
        -- Clear text elements first
        self:ClearIconText(icon)
        
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

-- Return unavailable icon to pool
function UI:ReleaseUnavailableIcon(icon)
    if icon then
        -- Clear text elements first
        self:ClearIconText(icon)
        
        icon:Hide()
        icon:SetParent(UIParent)
        icon:ClearAllPoints()
        
        -- Clear references
        icon.spellInfo = nil
        icon.unit = nil
        icon.queueData = nil
        
        table.insert(unavailableIconPool, icon)
        
        -- Remove from active unavailable icons
        for i, activeIcon in ipairs(activeUnavailableIcons) do
            if activeIcon == icon then
                table.remove(activeUnavailableIcons, i)
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
        self:UpdateDisplay(addon.CCRotation.cooldownQueue, addon.CCRotation.unavailableQueue)
    end
end

-- Update display with current queue (main function)
function UI:UpdateDisplay(queue, unavailableQueue)
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
    
    -- Release all current unavailable icons back to pool
    for i = #activeUnavailableIcons, 1, -1 do
        self:ReleaseUnavailableIcon(activeUnavailableIcons[i])
    end
    wipe(activeUnavailableIcons)
    
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
            icon.spellConfig = addon.Config:GetSpellInfo(cooldownData.spellID)
            
            if icon.spellInfo and icon.unit then
                -- Set icon texture using working approach
                icon.displayTexture:SetTexture(icon.spellInfo.iconID)
                icon.displayTexture:Show()
                
                -- Desaturate if not effective against current NPCs
                icon.displayTexture:SetDesaturated(not cooldownData.isEffective)
                
                -- Set spell name (only on first icon, using global setting)
                if i == 1 and config:Get("showSpellName") then
                    -- Use custom spell name if available, otherwise fall back to game spell name
                    local spellName = (icon.spellConfig and icon.spellConfig.name) or icon.spellInfo.name
                    local truncatedName = self:TruncateText(spellName, config:Get("spellNameMaxLength"))
                    icon.spellName:SetText(truncatedName)
                    -- Re-set font properties to ensure correct size
                    config:SetFontProperties(icon.spellName, config:Get("spellNameFont"), config:Get("spellNameFontSize"))
                    -- Position spell name above the icon - parent to container to avoid clipping
                    icon.spellName:SetParent(self.mainFrame.container)
                    icon.spellName:ClearAllPoints()
                    icon.spellName:SetPoint("BOTTOM", icon, "TOP", 0, 2)
                    icon.spellName:SetAlpha(1)
                    icon.spellName:Show()
                else
                    icon.spellName:Hide()
                end
                
                -- Set player name with class color (using both global and individual icon settings)
                local globalPlayerName = config:Get("showPlayerName")
                local individualPlayerName = config:Get("showPlayerName" .. i)
                if globalPlayerName and individualPlayerName then
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
                    -- Re-set font properties to ensure correct size
                    config:SetFontProperties(icon.playerName, config:Get("playerNameFont"), config:Get("playerNameFontSize"))
                    -- Position player name below the icon - parent to container to avoid clipping
                    icon.playerName:SetParent(self.mainFrame.container)
                    icon.playerName:ClearAllPoints()
                    icon.playerName:SetPoint("TOP", icon, "BOTTOM", 0, -2)
                    icon.playerName:SetAlpha(1)
                    icon.playerName:Show()
                else
                    icon.playerName:Hide()
                end
                
                -- Set cooldown
                local charges = cooldownData.charges or 0
                local isReady = charges > 0 or cooldownData.expirationTime <= now
                
                if isReady then
                    -- Don't clear if cooldown animation is still running - let it finish naturally
                    if icon.cooldown:IsShown() and (cooldownData.expirationTime - now) > -0.5 then
                        -- Let both swipe and text finish naturally
                        if config:Get("showCooldownText") then
                            local timeLeft = math.max(0, cooldownData.expirationTime - now)
                            icon.cooldownText:SetText(timeLeft > 0 and self:FormatTime(timeLeft) or "")
                        else
                            icon.cooldownText:SetText("")
                        end
                    else
                        icon.cooldown:Clear()
                        icon.cooldown:Hide()
                        icon.cooldownEndTime = nil
                        icon.cooldownText:SetText("")
                    end
                else
                    -- Only set cooldown if it's not already running with the same end time
                    if not icon.cooldown:IsShown() or math.abs((icon.cooldownEndTime or 0) - cooldownData.expirationTime) > 0.1 then
                        icon.cooldown:SetCooldown(now, cooldownData.expirationTime - now)
                        icon.cooldownEndTime = cooldownData.expirationTime
                        icon.cooldown:Show()
                    end
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
                
                -- Add status indicators for dead/out-of-range
                self:UpdateStatusIndicators(icon, cooldownData)
                
                -- Position and size icon using individual size (frame size unchanged)
                local iconSize = config:Get("iconSize" .. i)
                icon:SetSize(iconSize, iconSize)
                
                -- Apply texture zoom within the frame (like WeakAuras)
                local iconZoom = config:Get("iconZoom") or 1.0
                icon.displayTexture:ClearAllPoints()
                if iconZoom ~= 1.0 then
                    local textureSize = iconSize * iconZoom
                    icon.displayTexture:SetSize(textureSize, textureSize)
                    icon.displayTexture:SetPoint("CENTER", icon, "CENTER", 0, 0)
                else
                    icon.displayTexture:SetAllPoints(icon)
                end
                
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
    
    -- Create and position unavailable queue icons
    if config:Get("showUnavailableQueue") and unavailableQueue and #unavailableQueue > 0 then
        local maxUnavailableIcons = config:Get("maxUnavailableIcons")
        local unavailableSpacing = config:Get("unavailableSpacing")
        local unavailableIconSize = config:Get("unavailableIconSize")
        
        local iconIndex = 0
        for i = 1, #unavailableQueue do
            local cooldownData = unavailableQueue[i]
            if cooldownData then
                -- Filter: only show if cooldown < 3s or ready
                local charges = cooldownData.charges or 0
                local isReady = charges > 0 or cooldownData.expirationTime <= now
                local timeLeft = cooldownData.expirationTime - now
                if isReady or timeLeft < 3 then
                    iconIndex = iconIndex + 1
                    if iconIndex > maxUnavailableIcons then break end
                    
                    local icon = self:GetUnavailableIcon()
                    table.insert(activeUnavailableIcons, icon)
                    
                    -- Set icon data
                    icon.queueData = cooldownData
                    icon.unit = addon.CCRotation.GUIDToUnit[cooldownData.GUID]
                    icon.spellInfo = C_Spell.GetSpellInfo(cooldownData.spellID)
                    icon.spellConfig = addon.Config:GetSpellInfo(cooldownData.spellID)
                    
                    if icon.spellInfo and icon.unit then
                        -- Set icon texture
                        icon.displayTexture:SetTexture(icon.spellInfo.iconID)
                        icon.displayTexture:Show()
                    
                        -- Apply texture zoom within the frame (like WeakAuras)
                        local iconZoom = config:Get("iconZoom") or 1.0
                        icon.displayTexture:ClearAllPoints()
                        if iconZoom ~= 1.0 then
                            local textureSize = unavailableIconSize * iconZoom
                            icon.displayTexture:SetSize(textureSize, textureSize)
                            icon.displayTexture:SetPoint("CENTER", icon, "CENTER", 0, 0)
                        else
                            icon.displayTexture:SetAllPoints(icon)
                        end
                    
                        -- Hide text for small unavailable icons
                        icon.spellName:Hide()
                        icon.playerName:Hide()
                    
                        -- Set cooldown (minimal display)
                        local charges = cooldownData.charges or 0
                        local isReady = charges > 0 or cooldownData.expirationTime <= now
                        
                        if isReady then
                            -- Don't clear if cooldown animation is still running - let it finish naturally
                            if icon.cooldown:IsShown() and (cooldownData.expirationTime - now) > -0.5 then
                                -- Let swipe finish naturally, no text for unavailable icons anyway
                                icon.cooldownText:SetText("")
                            else
                                icon.cooldown:Clear()
                                icon.cooldown:Hide()
                                icon.cooldownEndTime = nil
                                icon.cooldownText:SetText("")
                            end
                        else
                            -- Only set cooldown if it's not already running with the same end time
                            if not icon.cooldown:IsShown() or math.abs((icon.cooldownEndTime or 0) - cooldownData.expirationTime) > 0.1 then
                                icon.cooldown:SetCooldown(now, cooldownData.expirationTime - now)
                                icon.cooldownEndTime = cooldownData.expirationTime
                                icon.cooldown:Show()
                            end
                            icon.cooldownText:SetText("")  -- No text for small icons
                        end
                    
                        -- Add status indicators
                        self:UpdateStatusIndicators(icon, cooldownData)
                        
                        -- Position and size icon
                        icon:SetSize(unavailableIconSize, unavailableIconSize)
                        
                        if iconIndex == 1 then
                            icon:SetPoint("TOPLEFT", self.mainFrame.unavailableContainer, "TOPLEFT", 0, 0)
                        else
                            icon:SetPoint("TOPLEFT", activeUnavailableIcons[iconIndex-1], "TOPRIGHT", unavailableSpacing, 0)
                        end
                        
                        icon:Show()
                    end
                end
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
    local visibleUnavailableIcons = #activeUnavailableIcons
    
    local totalWidth = 0
    local totalHeight = 0
    
    -- Calculate main queue dimensions (keep frame size same as before)
    if visibleIcons > 0 then
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
        
        totalHeight = maxHeight
    end
    
    -- Position unavailable container below main container but don't affect main frame size
    if visibleUnavailableIcons > 0 and config:Get("showUnavailableQueue") then
        local unavailableIconSize = config:Get("unavailableIconSize")
        local offset = config:Get("unavailableQueueOffset")
        
        -- Position unavailable container below the main container
        self.mainFrame.unavailableContainer:ClearAllPoints()
        self.mainFrame.unavailableContainer:SetPoint("TOP", self.mainFrame.container, "BOTTOM", 0, -offset)
    end
    
    -- Set minimum size (keep main frame size unchanged)
    if totalWidth == 0 then totalWidth = 1 end
    if totalHeight == 0 then totalHeight = 1 end
    
    self.mainFrame:SetSize(totalWidth, totalHeight)
end

-- Update visibility based on config and group status with robust checking
function UI:UpdateVisibility()
    if not self:ValidateFrameState() then
        addon.Config:DebugPrint("Cannot update visibility - frame state invalid")
        return
    end
    
    local shouldBeActive = addon.CCRotation and addon.CCRotation:ShouldBeActive()
    local config = addon.Config
    
    addon.Config:DebugPrint("UpdateVisibility - ShouldBeActive:", shouldBeActive, 
                           "Enabled:", config:Get("enabled"), 
                           "InGroup:", IsInGroup(), 
                           "ShowInSolo:", config:Get("showInSolo"))
    
    if shouldBeActive then
        self.mainFrame:Show()
        self:StartCooldownTextUpdates()
        addon.Config:DebugPrint("Frame shown and updates started")
    else
        self.mainFrame:Hide()
        self:StopCooldownTextUpdates()
        addon.Config:DebugPrint("Frame hidden and updates stopped")
    end
end

-- Show the UI with validation
function UI:Show()
    if not self:ValidateFrameState() then
        addon.Config:DebugPrint("Cannot show UI - frame state invalid")
        return
    end
    
    self.mainFrame:Show()
    self:StartCooldownTextUpdates()
    
    -- Position and show debug anchor if in debug mode
    if addon.Config and addon.Config:Get("debugMode") and self.mainFrame.anchor then
        -- Position anchor at the center of the main frame
        self.mainFrame.anchor:ClearAllPoints()
        self.mainFrame.anchor:SetPoint("CENTER", self.mainFrame, "CENTER")
        self.mainFrame.anchor:Show()
    end
    
    addon.Config:DebugPrint("UI shown manually")
end

-- Hide the UI
function UI:Hide()
    if self.mainFrame then
        self.mainFrame:Hide()
        if self.mainFrame.anchor then
            self.mainFrame.anchor:Hide()
        end
    end
    self:StopCooldownTextUpdates()
    addon.Config:DebugPrint("UI hidden manually")
end

-- Toggle the UI
function UI:Toggle()
    if not self:ValidateFrameState() then
        addon.Config:DebugPrint("Cannot toggle UI - frame state invalid")
        return
    end
    
    if self.mainFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- Debug function to show detailed icon state and attempt recovery
function UI:ShowIconDebug()
    print("|cff00ff00CC Rotation Helper Icon Debug:|r")
    
    if not self.mainFrame then
        print("|cffff0000  ERROR: No mainFrame!|r")
        return
    end
    
    print("  Active Icons: " .. tostring(#activeIcons))
    for i, icon in ipairs(activeIcons) do
        if icon then
            print("    Icon " .. i .. ": shown=" .. tostring(icon:IsShown()) .. 
                  ", parent=" .. tostring(icon:GetParent() and icon:GetParent():GetName() or "nil"))
        else
            print("    Icon " .. i .. ": NIL")
        end
    end
    
    print("  Icon Pool Size: " .. tostring(#iconPool))
    print("  Icons Created: " .. tostring(numIconsCreated))
    
    -- Check rotation system
    if addon.CCRotation then
        print("  CCRotation exists: true")
        if addon.CCRotation.cooldownQueue then
            print("  Queue length: " .. tostring(#addon.CCRotation.cooldownQueue))
            
            -- Show first few queue items
            for i = 1, math.min(3, #addon.CCRotation.cooldownQueue) do
                local cd = addon.CCRotation.cooldownQueue[i]
                if cd then
                    local spellInfo = C_Spell.GetSpellInfo(cd.spellID)
                    print("    Queue " .. i .. ": " .. (spellInfo and spellInfo.name or "Unknown") .. " (" .. cd.spellID .. ")")
                end
            end
        else
            print("|cffff0000  ERROR: No cooldown queue!|r")
        end
    else
        print("|cffff0000  ERROR: No CCRotation!|r")
    end
    
    -- Attempt to force refresh
    print("  Attempting to force refresh...")
    if addon.CCRotation and addon.CCRotation:ShouldBeActive() then
        self:RefreshDisplay()
        print("  Refresh attempted")
    else
        print("  Cannot refresh - addon not active")
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

-- Update status indicators for dead/out-of-range players
function UI:UpdateStatusIndicators(icon, cooldownData)
    if not icon or not cooldownData then return end
    
    -- Calculate indicator size (20% of icon size)
    local iconSize = icon:GetWidth()
    local indicatorSize = math.max(16, iconSize * 0.2)
    
    local hasStatusIndicator = false
    
    -- Update dead indicator
    if cooldownData.isDead then
        icon.deadIndicator:SetSize(indicatorSize, indicatorSize)
        icon.deadIndicator:Show()
        hasStatusIndicator = true
    else
        icon.deadIndicator:Hide()
    end
    
    -- Update range indicator (only show if alive but out of range)
    if not cooldownData.isDead and not cooldownData.inRange then
        icon.rangeIndicator:SetSize(indicatorSize, indicatorSize)
        icon.rangeIndicator:Show()
        hasStatusIndicator = true
    else
        icon.rangeIndicator:Hide()
    end
    
    -- Desaturate icon if any status indicator is shown OR if not effective
    local shouldDesaturate = hasStatusIndicator or (not cooldownData.isEffective)
    icon.displayTexture:SetDesaturated(shouldDesaturate)
end

-- Update mouse settings based on tooltip config
function UI:UpdateMouseSettings()
    if not self.mainFrame then return end
    
    local config = addon.Config
    local showTooltips = config:Get("showTooltips")
    local anchorLocked = config:Get("anchorLocked")
    
    -- Update main frame mouse settings: enable if unlocked OR tooltips are enabled
    self.mainFrame:EnableMouse(not anchorLocked or showTooltips)
    
    -- Update active icon mouse settings: only enable if tooltips are enabled
    for _, icon in ipairs(activeIcons) do
        icon:EnableMouse(showTooltips)
    end
    
    -- Update active unavailable icon mouse settings: only enable if tooltips are enabled
    for _, icon in ipairs(activeUnavailableIcons) do
        icon:EnableMouse(showTooltips)
    end
end

-- Validate frame state and recover if necessary
function UI:ValidateFrameState()
    if not self.mainFrame then
        addon.Config:DebugPrint("MainFrame is nil, attempting to recreate")
        self:Initialize()
        return self.mainFrame ~= nil
    end
    
    -- Check if frame is still valid
    local isValid = pcall(function() return self.mainFrame:GetParent() end)
    if not isValid then
        addon.Config:DebugPrint("MainFrame is invalid, recreating")
        self.mainFrame = nil
        self:Initialize()
        return self.mainFrame ~= nil
    end
    
    -- Ensure frame has proper parent
    if self.mainFrame:GetParent() ~= UIParent then
        addon.Config:DebugPrint("MainFrame has wrong parent, fixing")
        self.mainFrame:SetParent(UIParent)
    end
    
    -- Ensure containers exist
    if not self.mainFrame.container then
        addon.Config:DebugPrint("Missing container, recreating mainFrame")
        self.mainFrame = nil
        self:Initialize()
        return self.mainFrame ~= nil
    end
    
    return true
end

-- Update UI when configuration changes (called after profile switch)
function UI:UpdateFromConfig()
    addon.Config:DebugPrint("UpdateFromConfig started")
    
    -- Validate frame state first
    if not self:ValidateFrameState() then
        addon.Config:DebugPrint("Failed to validate/recover frame state")
        return
    end
    
    -- Store current visibility state
    local wasVisible = self.mainFrame:IsShown()
    
    -- First, clear all text elements before releasing icons
    for i = #activeIcons, 1, -1 do
        self:ClearIconText(activeIcons[i])
        self:ReleaseIcon(activeIcons[i])
    end
    wipe(activeIcons)
    
    for i = #activeUnavailableIcons, 1, -1 do
        self:ReleaseUnavailableIcon(activeUnavailableIcons[i])
    end
    wipe(activeUnavailableIcons)
    
    -- Update visibility based on new profile settings
    self:UpdateVisibility()
    
    -- Update mouse settings
    self:UpdateMouseSettings()
    
    -- Force refresh of all icon pools to apply new settings
    self:InitializeIconPool()
    
    -- Refresh display to apply new visual settings
    self:RefreshDisplay()
    
    -- Ensure frame is visible if it was before (and should be)
    if wasVisible and addon.CCRotation:ShouldBeActive() then
        self.mainFrame:Show()
    end
    
    -- Debug output to help troubleshoot
    local config = addon.Config
    config:DebugPrint("Profile switch complete - Position: Handled by SetUserPlaced" .. 
          " | Enabled: " .. tostring(config:Get("enabled")) .. 
          " | MaxIcons: " .. config:Get("maxIcons") .. 
          " | Visible: " .. tostring(self.mainFrame:IsShown()))
end
