-- IconRenderer.lua - Icon display and update logic
-- Handles rendering, positioning, and updating of icons

local addonName, addon = ...

local IconRenderer = {}

function IconRenderer:new(iconPool, glowManager, dataManager)
    local instance = {
        iconPool = iconPool,
        glowManager = glowManager,
        dataManager = dataManager or addon.Components.DataManager,
        shouldShowSecondary = false -- Hidden by default, controlled by events
    }
    setmetatable(instance, {__index = self})
    return instance
end

-- Helper method to clean up excess main icons
function IconRenderer:cleanupExcessMainIcons(startIndex, activeIcons)
    -- Release excess icons in reverse order
    for i = #activeIcons, startIndex, -1 do
        if activeIcons[i] then
            self.iconPool:releaseMainIcon(activeIcons[i])
            table.remove(activeIcons, i)
        end
    end
end

-- Helper method to clean up excess unavailable icons
function IconRenderer:cleanupExcessUnavailableIcons(startIndex, activeUnavailableIcons)
    -- Release excess icons in reverse order
    for i = #activeUnavailableIcons, startIndex, -1 do
        if activeUnavailableIcons[i] then
            self.iconPool:releaseUnavailableIcon(activeUnavailableIcons[i])
            table.remove(activeUnavailableIcons, i)
        end
    end
end

-- Helper method to clean up stale icons that are no longer in their respective queue
function IconRenderer:cleanupStaleIcons(activeIcons, queue, maxQueueSize, iconType)
    local indicesToRemove = {}
    
    for i = 1, #activeIcons do
        local icon = activeIcons[i]
        if icon and icon.queueData then
            local stillInQueue = false
            for j = 1, maxQueueSize do
                local queueData = queue[j]
                if queueData and queueData.GUID == icon.queueData.GUID and queueData.spellID == icon.queueData.spellID then
                    stillInQueue = true
                    break
                end
            end
            -- If this icon's data is no longer in the queue, mark for removal
            if not stillInQueue then
                if iconType == "main" then
                    self.iconPool:releaseMainIcon(icon)
                else
                    self.iconPool:releaseUnavailableIcon(icon)
                end
                table.insert(indicesToRemove, i)
            end
        end
    end
    
    -- Remove indices in reverse order to maintain array integrity
    for i = #indicesToRemove, 1, -1 do
        table.remove(activeIcons, indicesToRemove[i])
    end
end

-- Update existing icons without recreating them
function IconRenderer:updateMainIcons(queue, now, mainFrame)
    local config = addon.Config
    local maxIcons = config:Get("maxIcons")
    local spacing = config:Get("spacing")
    local activeIcons = self.iconPool:getActiveMainIcons()
    
    -- Clean up any icons that are no longer in the queue
    self:cleanupStaleIcons(activeIcons, queue, math.min(#queue, maxIcons), "main")
    
    -- Release icons that are no longer needed (beyond queue size)
    self:cleanupExcessMainIcons(math.min(#queue, maxIcons) + 1, activeIcons)
    
    -- Update or create icons for current queue
    for i = 1, math.min(#queue, maxIcons) do
        local cooldownData = queue[i]
        if cooldownData then
            -- Reuse existing icon or get new one
            local icon = activeIcons[i]
            if not icon then
                icon = self.iconPool:getMainIcon()
                activeIcons[i] = icon
            end
            
            -- Update icon data only if it changed
            local needsUpdate = not icon.queueData or 
                               icon.queueData.GUID ~= cooldownData.GUID or 
                               icon.queueData.spellID ~= cooldownData.spellID or
                               math.abs((icon.queueData.expirationTime or 0) - cooldownData.expirationTime) > 0.1
            
            icon.queueData = cooldownData
            icon.unit = addon.CCRotation.GUIDToUnit[cooldownData.GUID]
            
            if needsUpdate then
                icon.spellInfo = C_Spell.GetSpellInfo(cooldownData.spellID)
                icon.spellConfig = addon.Config:GetSpellInfo(cooldownData.spellID)
            end
            
            if icon.spellInfo and icon.unit then
                self:updateIconDisplay(icon, i, cooldownData, needsUpdate, now, config, mainFrame)
                self:positionMainIcon(icon, i, activeIcons, config)
                icon:Show()
            end
        end
    end
end

-- Update existing unavailable icons without recreating them
function IconRenderer:updateUnavailableIcons(unavailableQueue, now, mainFrame)
    local config = addon.Config
    local activeUnavailableIcons = self.iconPool:getActiveUnavailableIcons()
    
    if not config:Get("showUnavailableQueue") or not unavailableQueue or #unavailableQueue == 0 then
        -- Release all unavailable icons if not showing queue
        self:cleanupExcessUnavailableIcons(1, activeUnavailableIcons)
        return
    end
    
    -- Check if secondary queue should be hidden (controlled by event)
    if not self.shouldShowSecondary then
        self:cleanupExcessUnavailableIcons(1, activeUnavailableIcons)
        return
    end
    
    -- Clean up any icons that are no longer in the unavailable queue
    self:cleanupStaleIcons(activeUnavailableIcons, unavailableQueue, #unavailableQueue, "unavailable")
    
    if #unavailableQueue > 0 then
        local maxUnavailableIcons = config:Get("maxUnavailableIcons")
        local unavailableSpacing = config:Get("unavailableSpacing")
        local unavailableIconSize = config:Get("unavailableIconSize")
        
        -- Calculate valid icon count (only show if cooldown < 3s or ready)
        local validIconCount = 0
        for i = 1, #unavailableQueue do
            local cooldownData = unavailableQueue[i]
            if cooldownData then
                local charges = cooldownData.charges or 0
                local isReady = charges > 0 or cooldownData.expirationTime <= now
                local timeLeft = cooldownData.expirationTime - now
                if isReady or timeLeft < 3 then
                    validIconCount = validIconCount + 1
                    if validIconCount > maxUnavailableIcons then break end
                end
            end
        end
        
        -- Release icons that are no longer needed
        self:cleanupExcessUnavailableIcons(validIconCount + 1, activeUnavailableIcons)
        
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
                    
                    -- Reuse existing icon or get new one
                    local icon = activeUnavailableIcons[iconIndex]
                    if not icon then
                        icon = self.iconPool:getUnavailableIcon()
                        activeUnavailableIcons[iconIndex] = icon
                    end
                    
                    -- Update icon data only if it changed
                    local needsUpdate = not icon.queueData or 
                                       icon.queueData.GUID ~= cooldownData.GUID or 
                                       icon.queueData.spellID ~= cooldownData.spellID or
                                       math.abs((icon.queueData.expirationTime or 0) - cooldownData.expirationTime) > 0.1
                    
                    icon.queueData = cooldownData
                    icon.unit = addon.CCRotation.GUIDToUnit[cooldownData.GUID]
                    
                    if needsUpdate then
                        icon.spellInfo = C_Spell.GetSpellInfo(cooldownData.spellID)
                        icon.spellConfig = addon.Config:GetSpellInfo(cooldownData.spellID)
                    end
                    
                    if icon.spellInfo and icon.unit then
                        self:updateUnavailableIconDisplay(icon, cooldownData, needsUpdate, now, config)
                        self:positionUnavailableIcon(icon, iconIndex, activeUnavailableIcons, config, mainFrame)
                        icon:Show()
                    end
                end
            end
        end
    end
end

-- Update main icon display properties
function IconRenderer:updateIconDisplay(icon, iconIndex, cooldownData, needsUpdate, now, config, mainFrame)
    -- Update texture only if spell changed
    if needsUpdate then
        icon.displayTexture:SetTexture(icon.spellInfo.iconID)
        icon.displayTexture:Show()
        
        -- Clear any lingering cooldown animation when spell changes
        icon.cooldown:Clear()
        icon.cooldown:Hide()
        icon.cooldownEndTime = nil
    end
    
    -- Calculate if spell is ready (not on cooldown)
    local isReady = true
    if cooldownData.expirationTime and cooldownData.expirationTime > now then
        isReady = false
    elseif cooldownData.charges and cooldownData.charges == 0 then
        isReady = false
    end
    
    -- Desaturate only when spell is on cooldown
    local shouldDesaturate = not isReady
    
    
    icon.displayTexture:SetDesaturated(shouldDesaturate)
    
    -- Set spell name (only on first icon, using global setting)
    if iconIndex == 1 and config:Get("showSpellName") then
        -- Prioritize live spell name over database name to handle talent modifications like Gravity Lapse
        local spellName = icon.spellInfo.name or (icon.spellConfig and icon.spellConfig.name)
        local truncatedName = self:truncateText(spellName, config:Get("spellNameMaxLength"))
        icon.spellName:SetText(truncatedName)
        config:SetFontProperties(icon.spellName, config:Get("spellNameFont"), config:Get("spellNameFontSize"))
        icon.spellName:SetParent(mainFrame.container)
        icon.spellName:ClearAllPoints()
        icon.spellName:SetPoint("BOTTOM", icon, "TOP", 0, 2)
        icon.spellName:SetAlpha(1)
        icon.spellName:Show()
    else
        icon.spellName:Hide()
    end
    
    -- Set player name with class color
    local globalPlayerName = config:Get("showPlayerName")
    local individualPlayerName = config:Get("showPlayerName" .. iconIndex)
    if globalPlayerName and individualPlayerName then
        local name = UnitName(icon.unit)
        if name then
            local truncatedName = self:truncateText(name, config:Get("playerNameMaxLength"))
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
        config:SetFontProperties(icon.playerName, config:Get("playerNameFont"), config:Get("playerNameFontSize"))
        icon.playerName:SetParent(mainFrame.container)
        icon.playerName:ClearAllPoints()
        icon.playerName:SetPoint("TOP", icon, "BOTTOM", 0, -2)
        icon.playerName:SetAlpha(1)
        icon.playerName:Show()
    else
        icon.playerName:Hide()
    end
    
    -- Update cooldown
    self:updateIconCooldown(icon, cooldownData, now, config)
    
    -- Handle glow effect for the first spell
    if self.glowManager:shouldGlow(iconIndex, icon.unit, config, cooldownData) then
        self.glowManager:startGlow(icon, config)
    else
        self.glowManager:stopGlow(icon)
    end
    
    -- Add status indicators for dead/out-of-range
    self:updateStatusIndicators(icon, cooldownData, now)
    
    -- Position and size icon using individual size
    local iconSize = config:Get("iconSize" .. iconIndex)
    icon:SetSize(iconSize, iconSize)
    
    -- Apply texture zoom within the frame
    self:applyTextureZoom(icon, iconSize, config)
    
    -- Set cooldown font size based on icon size and percentage
    local cooldownFontPercent = config:Get("cooldownFontSizePercent") or 25
    local cooldownFontSize = math.floor(iconSize * cooldownFontPercent / 100)
    config:SetFontProperties(icon.cooldownText, config:Get("cooldownFont"), cooldownFontSize)
end

-- Update unavailable icon display properties
function IconRenderer:updateUnavailableIconDisplay(icon, cooldownData, needsUpdate, now, config)
    -- Update texture only if spell changed
    if needsUpdate then
        icon.displayTexture:SetTexture(icon.spellInfo.iconID)
        icon.displayTexture:Show()
    end

    -- Apply texture zoom within the frame
    local unavailableIconSize = config:Get("unavailableIconSize")
    self:applyTextureZoom(icon, unavailableIconSize, config)

    -- Hide text for small unavailable icons
    icon.spellName:Hide()
    icon.playerName:Hide()

    -- Update cooldown
    self:updateIconCooldown(icon, cooldownData, now, config, true)

    -- Add status indicators
    self:updateStatusIndicators(icon, cooldownData, now)
    
    -- Position and size icon
    icon:SetSize(unavailableIconSize, unavailableIconSize)
end

-- Apply texture zoom effect
function IconRenderer:applyTextureZoom(icon, iconSize, config)
    local iconZoom = config:Get("iconZoom") or 1.0
    icon.displayTexture:ClearAllPoints()
    if iconZoom ~= 1.0 then
        local textureSize = iconSize * iconZoom
        icon.displayTexture:SetSize(textureSize, textureSize)
        icon.displayTexture:SetPoint("CENTER", icon, "CENTER", 0, 0)
    else
        icon.displayTexture:SetAllPoints(icon)
    end
end

-- Position main icon
function IconRenderer:positionMainIcon(icon, iconIndex, activeIcons, config)
    local spacing = config:Get("spacing")
    
    if iconIndex == 1 then
        -- Main icon stays fixed at the same position
        icon:ClearAllPoints()
        icon:SetPoint("BOTTOMLEFT", addon.UI.mainFrame.container, "BOTTOMLEFT", 0, 0)
        
    else
        -- Position subsequent icons relative to the main icon (icon 1)
        local mainIcon = activeIcons[1]
        if mainIcon then
            -- Calculate cumulative offset from main icon
            local totalOffset = 0
            for i = 1, iconIndex - 1 do
                local iconSize = config:Get("iconSize" .. i)
                totalOffset = totalOffset + iconSize
                if i > 1 then
                    totalOffset = totalOffset + spacing
                end
            end
            
            icon:ClearAllPoints()
            icon:SetPoint("BOTTOMLEFT", mainIcon, "BOTTOMLEFT", totalOffset + spacing, 0)
        end
    end
end

-- Position unavailable icon
function IconRenderer:positionUnavailableIcon(icon, iconIndex, activeUnavailableIcons, config, mainFrame)
    local unavailableSpacing = config:Get("unavailableSpacing")
    
    if iconIndex == 1 then
        icon:SetPoint("TOPLEFT", mainFrame.unavailableContainer, "TOPLEFT", 0, 0)
    elseif activeUnavailableIcons[iconIndex-1] then
        icon:SetPoint("TOPLEFT", activeUnavailableIcons[iconIndex-1], "TOPRIGHT", unavailableSpacing, 0)
    end
end

-- Update individual icon cooldown
function IconRenderer:updateIconCooldown(icon, cooldownData, now, config, isUnavailable)
    
    local charges = cooldownData.charges or 0
    local isReady = (charges > 0) and (cooldownData.expirationTime <= now)
    
    if isReady then
        -- Don't clear if cooldown animation is still running - let it finish naturally
        if icon.cooldown:IsShown() and (cooldownData.expirationTime - now) > -0.5 then
            if config:Get("showCooldownText") and not isUnavailable then
                local timeLeft = math.max(0, cooldownData.expirationTime - now)
                local formattedText = timeLeft > 0 and self:formatTime(timeLeft) or ""
                icon.cooldownText:SetText(formattedText)
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
        if not icon.cooldown:IsShown() or math.abs((icon.cooldownEndTime or 0) - cooldownData.expirationTime) > 0.5 then
            local remainingTime = math.max(0, cooldownData.expirationTime - now)
            local duration = cooldownData.duration or remainingTime
            local startTime = cooldownData.expirationTime - duration
            icon.cooldown:SetCooldown(startTime, duration)
            icon.cooldownEndTime = cooldownData.expirationTime
            icon.cooldown:Show()
        end
        if config:Get("showCooldownText") and not isUnavailable then
            local timeLeft = cooldownData.expirationTime - now
            local formattedText = self:formatTime(timeLeft)
            icon.cooldownText:SetText(formattedText)
        else
            icon.cooldownText:SetText("")
        end
    end
end

-- Update status indicators for dead/out-of-range players
function IconRenderer:updateStatusIndicators(icon, cooldownData, now)
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
    
    -- Desaturation is handled in updateIconDisplay, don't override it here
end

-- Truncate text to max length
function IconRenderer:truncateText(text, maxLength)
    if not text or text == "" then
        return ""
    end
    
    if string.len(text) <= maxLength then
        return text
    else
        return string.sub(text, 1, maxLength)
    end
end

-- Format time for display
function IconRenderer:formatTime(seconds)
    if seconds <= 0 then
        return ""
    elseif seconds < self.dataManager.config:get("cooldownDecimalThreshold") then
        return string.format("%.1f", seconds)
    elseif seconds < 60 then
        return string.format("%.0f", seconds)
    else
        local minutes = math.floor(seconds / 60)
        local secs = seconds % 60
        return string.format("%d:%02d", minutes, secs)
    end
end

-- Register component
if not addon.Components then
    addon.Components = {}
end
addon.Components.IconRenderer = IconRenderer

return IconRenderer