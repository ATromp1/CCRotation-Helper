-- IconPool.lua - Icon pooling and management system
-- Handles creation, pooling, and lifecycle of icon frames

local addonName, addon = ...

local IconPool = {}

function IconPool:new(dataManager)
    local instance = {
        -- Main icon pools
        mainIconPool = {},
        activeMainIcons = {},
        numMainIconsCreated = 0,
        
        -- Unavailable icon pools
        unavailableIconPool = {},
        activeUnavailableIcons = {},
        numUnavailableIconsCreated = 0,
        
        -- Dependencies
        dataManager = dataManager or addon.Components.DataManager
    }
    
    setmetatable(instance, {__index = self})
    return instance
end

-- Initialize/reset the icon pools
function IconPool:initialize()
    self.mainIconPool = {}
    self.activeMainIcons = {}
    self.numMainIconsCreated = 0
    self.unavailableIconPool = {}
    self.activeUnavailableIcons = {}
    self.numUnavailableIconsCreated = 0
end

-- Get main icon from pool or create new one
function IconPool:getMainIcon()
    local icon = table.remove(self.mainIconPool)
    if not icon then
        icon = self:createMainIcon()
    end
    
    -- Reset state and prepare for use
    self:resetMainIcon(icon)
    return icon
end

-- Get unavailable icon from pool or create new one
function IconPool:getUnavailableIcon()
    local icon = table.remove(self.unavailableIconPool)
    if not icon then
        icon = self:createUnavailableIcon()
    end
    
    -- Reset state and prepare for use
    self:resetUnavailableIcon(icon)
    return icon
end

-- Create new main icon
function IconPool:createMainIcon()
    self.numMainIconsCreated = self.numMainIconsCreated + 1
    local icon = CreateFrame("Button", "CCRotationIcon" .. self.numMainIconsCreated, UIParent, "CCRotationIconTemplate")
    
    -- Enable clipping to properly mask zoomed textures
    icon:SetClipsChildren(true)
    
    -- Create working texture - use ARTWORK layer
    icon.displayTexture = icon:CreateTexture("DisplayTexture_" .. self.numMainIconsCreated, "ARTWORK")
    icon.displayTexture:SetAllPoints()
    icon.displayTexture:SetTexelSnappingBias(0.0)
    icon.displayTexture:SetSnapToPixelGrid(false)
    
    -- Create status indicator textures
    icon.deadIndicator = icon:CreateTexture("DeadIndicator_" .. self.numMainIconsCreated, "OVERLAY", nil, 1)
    icon.deadIndicator:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    icon.deadIndicator:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -2, -2)
    icon.deadIndicator:Hide()
    
    icon.rangeIndicator = icon:CreateTexture("RangeIndicator_" .. self.numMainIconsCreated, "OVERLAY", nil, 1)
    icon.rangeIndicator:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
    icon.rangeIndicator:SetPoint("TOPLEFT", icon, "TOPLEFT", 2, -2)
    icon.rangeIndicator:Hide()
    
    -- Hide the XML template icon texture
    if icon.icon then
        icon.icon:Hide()
    end
    
    -- Setup fonts using config
    local config = addon.Config
    config:SetFontProperties(icon.spellName, config:Get("spellNameFont"), config:Get("spellNameFontSize"))
    config:SetFontProperties(icon.playerName, config:Get("playerNameFont"), config:Get("playerNameFontSize"))
    
    -- Set text colors
    icon.spellName:SetTextColor(unpack(config:Get("spellNameColor")))
    icon.playerName:SetTextColor(unpack(config:Get("spellNameColor")))
    icon.cooldownText:SetTextColor(unpack(config:Get("cooldownTextColor")))
    
    -- Hide countdown numbers from cooldown frame
    icon.cooldown:SetHideCountdownNumbers(true)
    
    -- Create a separate frame for cooldown text that's definitely above everything
    icon.cooldownTextFrame = CreateFrame("Frame", nil, icon)
    icon.cooldownTextFrame:SetAllPoints(icon)
    icon.cooldownTextFrame:SetFrameLevel(icon:GetFrameLevel() + 10) -- Way above everything
    
    -- Ensure the cooldown text frame is visible
    icon.cooldownTextFrame:Show()
    
    -- Move the cooldown text to this new frame
    icon.cooldownText:SetParent(icon.cooldownTextFrame)
    icon.cooldownText:ClearAllPoints()
    icon.cooldownText:SetPoint("CENTER", icon.cooldownTextFrame, "CENTER")
    icon.cooldownText:Show()
    
    -- Initialize glow system via GlowManager
    if addon.Components and addon.Components.GlowManager then
        local glowManager = addon.Components.GlowManager:new()
        glowManager:initializeIconGlow(icon)
    end
    
    -- Setup event handlers
    self:setupMainIconEvents(icon)
    
    return icon
end

-- Create new unavailable icon
function IconPool:createUnavailableIcon()
    self.numUnavailableIconsCreated = self.numUnavailableIconsCreated + 1
    local icon = CreateFrame("Button", "CCRotationUnavailableIcon" .. self.numUnavailableIconsCreated, UIParent, "CCRotationIconTemplate")
    
    -- Enable clipping to properly mask zoomed textures
    icon:SetClipsChildren(true)
    
    -- Create working texture - use ARTWORK layer
    icon.displayTexture = icon:CreateTexture("DisplayTextureUnavailable_" .. self.numUnavailableIconsCreated, "ARTWORK")
    icon.displayTexture:SetAllPoints()
    icon.displayTexture:SetTexelSnappingBias(0.0)
    icon.displayTexture:SetSnapToPixelGrid(false)
    
    -- Create status indicator textures
    icon.deadIndicator = icon:CreateTexture("DeadIndicatorUnavailable_" .. self.numUnavailableIconsCreated, "OVERLAY", nil, 1)
    icon.deadIndicator:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    icon.deadIndicator:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -1, -1)
    icon.deadIndicator:Hide()
    
    icon.rangeIndicator = icon:CreateTexture("RangeIndicatorUnavailable_" .. self.numUnavailableIconsCreated, "OVERLAY", nil, 1)
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
    
    -- Setup event handlers
    self:setupUnavailableIconEvents(icon)
    
    return icon
end

-- Setup event handlers for main icons
function IconPool:setupMainIconEvents(icon)
    -- Only enable mouse if tooltips are enabled
    icon:EnableMouse(self.dataManager.config:get("showTooltips"))
    
    -- Capture pool instance for event handlers
    local poolInstance = self
    
    icon:SetScript("OnEnter", function(self)
        if poolInstance.dataManager.config:get("showTooltips") and self.spellInfo and self.unit then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellInfo.spellID)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Player: " .. (UnitName(self.unit) or "Unknown"), 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    
    icon:SetScript("OnLeave", function(self)
        if poolInstance.dataManager.config:get("showTooltips") then
            GameTooltip:Hide()
        end
    end)
    
    -- Pass through drag events to main frame
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() and not poolInstance.dataManager.config:get("anchorLocked") then
            -- Pass drag to main frame: icon -> container -> mainFrame
            local mainFrame = self:GetParent():GetParent()
            if mainFrame then
                mainFrame:StartMoving()
            end
        end
    end)
    
    icon:SetScript("OnDragStop", function(self)
        local mainFrame = self:GetParent():GetParent()
        if mainFrame then
            mainFrame:StopMovingOrSizing()
            mainFrame:SetUserPlaced(true)
        end
    end)
end

-- Setup event handlers for unavailable icons
function IconPool:setupUnavailableIconEvents(icon)
    -- Only enable mouse if tooltips are enabled
    icon:EnableMouse(self.dataManager.config:get("showTooltips"))
    
    -- Capture pool instance for event handlers
    local poolInstance = self
    
    icon:SetScript("OnEnter", function(self)
        if poolInstance.dataManager.config:get("showTooltips") and self.spellInfo and self.unit then
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
        if poolInstance.dataManager.config:get("showTooltips") then
            GameTooltip:Hide()
        end
    end)
    
    -- Pass through drag events - handle both main frame and unavailable container
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() and not poolInstance.dataManager.config:get("anchorLocked") then
            local config = addon.Config
            local container = self:GetParent() -- unavailableContainer
            local mainFrame = container:GetParent() -- mainFrame
            
            -- Check if we're in independent positioning mode
            if config:Get("unavailableQueuePositioning") == "independent" then
                -- Drag the unavailable container independently
                container:StartMoving()
                self.isDraggingUnavailable = true
            else
                -- Drag the main frame (default behavior)
                if mainFrame then
                    mainFrame:StartMoving()
                end
            end
        end
    end)
    
    icon:SetScript("OnDragStop", function(self)
        local config = addon.Config
        local container = self:GetParent() -- unavailableContainer
        local mainFrame = container:GetParent() -- mainFrame
        
        if self.isDraggingUnavailable then
            -- Save independent position
            container:StopMovingOrSizing()
            local point, _, _, x, y = container:GetPoint()
            config:Set("unavailableQueueX", x)
            config:Set("unavailableQueueY", y)
            config:Set("unavailableQueueAnchorPoint", point)
            self.isDraggingUnavailable = nil
        else
            -- Stop main frame dragging
            if mainFrame then
                mainFrame:StopMovingOrSizing()
                mainFrame:SetUserPlaced(true)
            end
        end
    end)
end


-- Reset main icon to clean state
function IconPool:resetMainIcon(icon)
    -- Set parent and reset state
    icon:SetParent(addon.UI.mainFrame.container)
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
    
    -- Stop all possible glow types
    icon:StopGlow()
    icon.cooldown:Clear()
    icon.cooldown:Hide()
    icon.deadIndicator:Hide()
    icon.rangeIndicator:Hide()
    
    -- Stop any animations
    if icon.animFrame and icon.animFrame.pulseAnim and icon.animFrame.pulseAnim:IsPlaying() then
        icon.animFrame.pulseAnim:Stop()
    end
end

-- Reset unavailable icon to clean state
function IconPool:resetUnavailableIcon(icon)
    -- Set parent and reset state
    icon:SetParent(addon.UI.mainFrame.unavailableContainer)
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
    
    -- Stop all possible glow types
    local LCG = LibStub("LibCustomGlow-1.0")
    LCG.ButtonGlow_Stop(icon)
    LCG.PixelGlow_Stop(icon)
    LCG.AutoCastGlow_Stop(icon)
    LCG.ProcGlow_Stop(icon)
    icon.cooldown:Clear()
    icon.cooldown:Hide()
    icon.deadIndicator:Hide()
    icon.rangeIndicator:Hide()
    
    -- Stop any animations
    if icon.animFrame and icon.animFrame.pulseAnim and icon.animFrame.pulseAnim:IsPlaying() then
        icon.animFrame.pulseAnim:Stop()
    end
end

-- Return main icon to pool
function IconPool:releaseMainIcon(icon)
    if icon then
        self:clearIconText(icon)
        
        icon:Hide()
        icon:SetParent(UIParent)
        icon:ClearAllPoints()
        
        -- Clear references
        icon.spellInfo = nil
        icon.unit = nil
        icon.queueData = nil
        
        -- Only add to pool if not already there
        local alreadyInPool = false
        for _, poolIcon in ipairs(self.mainIconPool) do
            if poolIcon == icon then
                alreadyInPool = true
                break
            end
        end
        
        if not alreadyInPool then
            table.insert(self.mainIconPool, icon)
        end
        
        -- Remove from active icons - let caller handle this to avoid race conditions
        -- This will be handled by cleanup functions in IconRenderer
    end
end

-- Return unavailable icon to pool
function IconPool:releaseUnavailableIcon(icon)
    if icon then
        self:clearIconText(icon)
        
        icon:Hide()
        icon:SetParent(UIParent)
        icon:ClearAllPoints()
        
        -- Clear references
        icon.spellInfo = nil
        icon.unit = nil
        icon.queueData = nil
        
        -- Only add to pool if not already there
        local alreadyInPool = false
        for _, poolIcon in ipairs(self.unavailableIconPool) do
            if poolIcon == icon then
                alreadyInPool = true
                break
            end
        end
        
        if not alreadyInPool then
            table.insert(self.unavailableIconPool, icon)
        end
        
        -- Remove from active icons - let caller handle this to avoid race conditions
        -- This will be handled by cleanup functions in IconRenderer
    end
end

-- Helper function to clear icon text elements
function IconPool:clearIconText(icon)
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

-- Update mouse settings for all active icons
function IconPool:updateMouseSettings()
    local showTooltips = self.dataManager.config:get("showTooltips")
    
    -- Update active main icon mouse settings
    for _, icon in ipairs(self.activeMainIcons) do
        icon:EnableMouse(showTooltips)
    end
    
    -- Update active unavailable icon mouse settings
    for _, icon in ipairs(self.activeUnavailableIcons) do
        icon:EnableMouse(showTooltips)
    end
end

-- Get active icon arrays (for external access)
function IconPool:getActiveMainIcons()
    return self.activeMainIcons
end

function IconPool:getActiveUnavailableIcons()
    return self.activeUnavailableIcons
end

-- Register component
if not addon.Components then
    addon.Components = {}
end
addon.Components.IconPool = IconPool

return IconPool