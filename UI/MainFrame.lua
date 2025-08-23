local addonName, addon = ...

-- Get AceGUI reference
local AceGUI = LibStub("AceGUI-3.0")

addon.UI = {}
local UI = addon.UI

-- Initialize UI system with component-based architecture
function UI:Initialize()
    if self.mainFrame then 
        addon.Config:DebugPrint("Initialize called but mainFrame already exists")
        return 
    end
    
    -- Prevent recursive initialization during sync events
    if self.initializing then
        addon.Config:DebugPrint("Already initializing, skipping")
        return
    end
    self.initializing = true
    
    addon.Config:DebugPrint("Initializing UI system")
    
    -- Initialize components
    self.dataManager = addon.Components.DataManager
    self.iconPool = addon.Components.IconPool:new(self.dataManager)
    self.glowManager = addon.Components.GlowManager:new()
    self.iconRenderer = addon.Components.IconRenderer:new(self.iconPool, self.glowManager, self.dataManager)
    self.npcDebugFrame = addon.Components.NPCDebugFrame:new()
    
    -- Create main frame
    self:createMainFrame()
    
    -- Initialize component systems
    self.iconPool:initialize()
    self.npcDebugFrame:Initialize(self.mainFrame)
    
    -- Register for queue update events from RotationCore
    if addon.CCRotation then
        addon.CCRotation:RegisterEventListener("QUEUE_UPDATED", function(queue, unavailableQueue)
            self:UpdateDisplay(queue, unavailableQueue)
        end)
        
        -- Register for secondary queue state changes
        addon.CCRotation:RegisterEventListener("SECONDARY_QUEUE_STATE_CHANGED", function(shouldShow)
            self.iconRenderer.shouldShowSecondary = shouldShow
        end)
    end
    
    -- Register for profile change events from Config
    if addon.Config then
        addon.Config:RegisterEventListener("PROFILE_CHANGED", function()
            self:UpdateFromConfig()
        end)
    end
    
    -- Start cooldown text update timer
    self:startCooldownTextUpdates()
    
    -- Show UI if should be active
    C_Timer.After(0.1, function()
        self:UpdateVisibility()
    end)
    
    -- Clear initialization flag
    self.initializing = false
    
    addon.Config:DebugPrint("UI initialization complete")
end

-- Create main frame with error handling
function UI:createMainFrame()
    -- Always destroy existing frame first to prevent conflicts
    if _G["CCRotationMainFrame"] then
        _G["CCRotationMainFrame"]:Hide()
        _G["CCRotationMainFrame"] = nil
    end
    
    local success = pcall(function()
        self.mainFrame = CreateFrame("Frame", "CCRotationMainFrame", UIParent, "CCRotationTemplate")
    end)
    
    if not success or not self.mainFrame then
        addon.Config:DebugPrint("Failed to create mainFrame with template, creating basic frame")
        self:createBasicFrame()
    end
    
    -- Ensure frame is properly parented
    if self.mainFrame and self.mainFrame:GetParent() ~= UIParent then
        addon.Config:DebugPrint("Frame created with wrong parent, fixing immediately")
        self.mainFrame:SetParent(UIParent)
    end

    -- Setup main frame properties
    self:setupMainFrame()
end

-- Create basic frame fallback
function UI:createBasicFrame()
    -- Ensure no conflicting frame exists
    if _G["CCRotationMainFrame"] then
        _G["CCRotationMainFrame"]:Hide()
        _G["CCRotationMainFrame"] = nil
    end
    
    self.mainFrame = CreateFrame("Frame", "CCRotationMainFrame", UIParent)
    self.mainFrame:SetSize(200, 64)
    
    -- Ensure proper parenting
    if self.mainFrame:GetParent() ~= UIParent then
        self.mainFrame:SetParent(UIParent)
    end
    
    -- Create basic container
    self.mainFrame.container = CreateFrame("Frame", nil, self.mainFrame)
    self.mainFrame.container:SetAllPoints()
end

-- Setup main frame properties
function UI:setupMainFrame()
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
        self:SetUserPlaced(true)
    end)

    -- Create unavailable queue container
    frame.unavailableContainer = CreateFrame("Frame", nil, frame)
    frame.unavailableContainer:SetSize(1, 1)
    frame.unavailableContainer:SetMovable(true)
    frame.unavailableContainer:SetClampedToScreen(true)
    
    -- Create preview frames for config mode (initially hidden)
    self:createPreviewFrames(frame)
end

-- Start continuous cooldown text updates
function UI:startCooldownTextUpdates()
    if self.cooldownUpdateTimer then
        self.cooldownUpdateTimer:Cancel()
    end
    
    local function updateCooldownText()
        self:updateCooldownText()
        self.cooldownUpdateTimer = C_Timer.After(0.1, updateCooldownText)
    end
    
    updateCooldownText()
end

-- Stop cooldown text updates
function UI:stopCooldownTextUpdates()
    if self.cooldownUpdateTimer then
        self.cooldownUpdateTimer:Cancel()
        self.cooldownUpdateTimer = nil
    end
end

-- Update only the cooldown text on visible icons
function UI:updateCooldownText()
    if not addon.Config:Get("showCooldownText") then
        return
    end
    
    local now = GetTime()
    local activeIcons = self.iconPool:getActiveMainIcons()
    
    for i, icon in ipairs(activeIcons) do
        if icon.queueData and icon:IsShown() then
            local cooldownData = icon.queueData
            local charges = cooldownData.charges or 0
            local isReady = (charges > 0) and (cooldownData.expirationTime <= now)
            
            if isReady then
                icon.cooldownText:SetText("")
            else
                local timeLeft = cooldownData.expirationTime - now
                icon.cooldownText:SetText(self.iconRenderer:formatTime(timeLeft))
            end
        end
    end
end

-- Refresh display with current queue (forces immediate redraw)
function UI:RefreshDisplay()
    -- Update font properties for existing icons
    local config = addon.Config
    local activeIcons = self.iconPool:getActiveMainIcons()
    
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
    
    -- Update preview frames if config is open
    if self.configPreviewActive then
        self:updatePreviewIconSizes()
    end
end

-- Update display with current queue (main function)
function UI:UpdateDisplay(queue, unavailableQueue)
    if not self.mainFrame or not self.mainFrame.container then 
        return
    end
    
    if not queue then
        return
    end
    
    local now = GetTime()
    
    -- Debug: Show what spells are being sent to iconRenderer
    for i, spell in ipairs(queue) do
        if i <= 2 then -- Only show first 2
            local remaining = spell.expirationTime - now
            local isReady = (spell.charges > 0) and (spell.expirationTime <= now)
        end
    end

    -- Use component-based rendering (this should be safe during combat)
    self.iconRenderer:updateMainIcons(queue, now, self.mainFrame)
    self.iconRenderer:updateUnavailableIcons(unavailableQueue or {}, now, self.mainFrame)
    
    -- Update frame visibility
    if not addon.CCRotation:ShouldBeActive() then
        self.mainFrame:Hide()
        return
    end
    
    self.mainFrame:Show()
    
    -- Update main frame size
    self:updateFrameSize()
end

-- Update main frame size based on visible icons
function UI:updateFrameSize()
    local config = addon.Config
    local spacing = config:Get("spacing")
    local activeIcons = self.iconPool:getActiveMainIcons()
    local activeUnavailableIcons = self.iconPool:getActiveUnavailableIcons()
    local visibleIcons = #activeIcons
    local visibleUnavailableIcons = #activeUnavailableIcons
    
    -- Calculate maximum possible width to prevent frame shifting
    local maxIcons = config:Get("maxIcons")
    local maxTotalWidth = 0
    local maxHeight = 0
    
    -- Calculate maximum width based on all possible icons
    for i = 1, maxIcons do
        local iconSize = config:Get("iconSize" .. i)
        maxTotalWidth = maxTotalWidth + iconSize
        if i > 1 then
            maxTotalWidth = maxTotalWidth + spacing
        end
        if iconSize > maxHeight then
            maxHeight = iconSize
        end
    end
    
    -- Use the maximum dimensions to keep frame size consistent
    -- This prevents the frame from shifting when icons are added/removed
    local frameWidth = math.max(maxTotalWidth, 200) -- Minimum width of 200
    local frameHeight = math.max(maxHeight, 64) -- Minimum height of 64
    
    -- Position unavailable container
    if visibleUnavailableIcons > 0 and config:Get("showUnavailableQueue") then
        self:positionUnavailableContainer(config)
    end
    
    self.mainFrame:SetSize(frameWidth, frameHeight)
end

-- Position unavailable container based on config settings
function UI:positionUnavailableContainer(config)
    local container = self.mainFrame.unavailableContainer
    container:ClearAllPoints()
    
    local positioningMode = config:Get("unavailableQueuePositioning")
    
    if positioningMode == "independent" then
        -- Independent positioning - anchor to UIParent with saved coordinates
        local x = config:Get("unavailableQueueX")
        local y = config:Get("unavailableQueueY")
        local anchorPoint = config:Get("unavailableQueueAnchorPoint") or "TOPLEFT"
        
        container:SetPoint(anchorPoint, UIParent, anchorPoint, x, y)
    else
        -- Relative positioning - anchor relative to main container (default behavior)
        local x = config:Get("unavailableQueueX") or 0
        local y = config:Get("unavailableQueueY") or -30
        local anchorPoint = config:Get("unavailableQueueAnchorPoint") or "TOP"
        local relativePoint = config:Get("unavailableQueueRelativePoint") or "BOTTOM"
        
        -- Use legacy offset if Y is still using the old setting
        if y == -30 and config:Get("unavailableQueueOffset") then
            y = -config:Get("unavailableQueueOffset")
        end
        
        container:SetPoint(anchorPoint, self.mainFrame.container, relativePoint, x, y)
    end
end

-- Create preview frames for config positioning
function UI:createPreviewFrames(frame)
    -- Main queue preview frame
    frame.mainPreview = CreateFrame("Frame", nil, frame.container)
    frame.mainPreview:SetSize(200, 64)
    frame.mainPreview:SetPoint("BOTTOMLEFT", frame.container, "BOTTOMLEFT", 0, 0)
    frame.mainPreview:Hide()
    
    -- Main preview border
    frame.mainPreview.border = frame.mainPreview:CreateTexture(nil, "BACKGROUND")
    frame.mainPreview.border:SetAllPoints()
    frame.mainPreview.border:SetColorTexture(0, 1, 0, 0.3) -- Green with transparency
    
    -- Main preview label
    frame.mainPreview.label = frame.mainPreview:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.mainPreview.label:SetPoint("CENTER")
    frame.mainPreview.label:SetText("Main Queue")
    frame.mainPreview.label:SetTextColor(1, 1, 1, 1)
    
    -- No sample icons needed - just show the frame for positioning
    
    -- Unavailable queue preview frame
    frame.unavailablePreview = CreateFrame("Frame", nil, frame.unavailableContainer)
    frame.unavailablePreview:SetSize(100, 24)
    frame.unavailablePreview:SetPoint("TOPLEFT", frame.unavailableContainer, "TOPLEFT", 0, 0)
    frame.unavailablePreview:Hide()
    
    -- Unavailable preview border
    frame.unavailablePreview.border = frame.unavailablePreview:CreateTexture(nil, "BACKGROUND")
    frame.unavailablePreview.border:SetAllPoints()
    frame.unavailablePreview.border:SetColorTexture(1, 0.5, 0, 0.3) -- Orange with transparency
    
    -- Unavailable preview label
    frame.unavailablePreview.label = frame.unavailablePreview:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.unavailablePreview.label:SetPoint("CENTER")
    frame.unavailablePreview.label:SetText("Secondary Queue")
    frame.unavailablePreview.label:SetTextColor(1, 1, 1, 1)
    
    -- No sample icons needed - just show the frame for positioning
end

-- Show preview frames for config mode
function UI:showConfigPreview()
    -- Validate frame state first
    if not self:validateFrameState() then
        addon.Config:DebugPrint("Cannot show config preview - frame state invalid")
        -- Try to reinitialize if needed
        if not self.mainFrame then
            self:Initialize()
        end
        -- If still no frame, give up
        if not self.mainFrame then
            return
        end
    end
    
    -- Check if preview frames exist
    if not self.mainFrame.mainPreview or not self.mainFrame.unavailablePreview then
        addon.Config:DebugPrint("Preview frames missing, recreating...")
        self:createPreviewFrames(self.mainFrame)
    end
    
    -- Update positioning first
    local config = addon.Config
    self:positionUnavailableContainer(config)
    
    -- Hide real icons when showing preview
    self:hideRealIcons()
    
    -- Show preview frames with error handling
    if self.mainFrame.mainPreview then
        self.mainFrame.mainPreview:Show()
        addon.Config:DebugPrint("Main preview shown")
    else
        addon.Config:DebugPrint("ERROR: Main preview frame missing")
    end
    
    if self.mainFrame.unavailablePreview and config:Get("showUnavailableQueue") then
        self.mainFrame.unavailablePreview:Show()
        addon.Config:DebugPrint("Unavailable preview shown")
    else
        if self.mainFrame.unavailablePreview then
            self.mainFrame.unavailablePreview:Hide()
        end
        addon.Config:DebugPrint("Unavailable preview hidden (showUnavailableQueue = " .. tostring(config:Get("showUnavailableQueue")) .. ")")
    end
    
    -- Update sample icon sizes
    self:updatePreviewIconSizes()
    
    addon.Config:DebugPrint("Config preview mode enabled")
end

-- Hide preview frames
function UI:hideConfigPreview()
    if not self.mainFrame then return end
    
    self.mainFrame.mainPreview:Hide()
    self.mainFrame.unavailablePreview:Hide()
    
    -- Show real icons again when hiding preview
    self:showRealIcons()
    
    addon.Config:DebugPrint("Config preview mode disabled")
end

-- Hide real icons during preview mode
function UI:hideRealIcons()
    if not self.iconPool then return end
    
    -- Hide main queue real icons
    local activeIcons = self.iconPool:getActiveMainIcons()
    for _, icon in ipairs(activeIcons) do
        if icon then
            icon:Hide()
        end
    end
    
    -- Hide unavailable queue real icons
    local activeUnavailableIcons = self.iconPool:getActiveUnavailableIcons()
    for _, icon in ipairs(activeUnavailableIcons) do
        if icon then
            icon:Hide()
        end
    end
    
    addon.Config:DebugPrint("Real icons hidden for preview mode")
end

-- Show real icons when exiting preview mode
function UI:showRealIcons()
    if not self.iconPool then return end
    
    -- Show main queue real icons
    local activeIcons = self.iconPool:getActiveMainIcons()
    for _, icon in ipairs(activeIcons) do
        if icon then
            icon:Show()
        end
    end
    
    -- Show unavailable queue real icons  
    local activeUnavailableIcons = self.iconPool:getActiveUnavailableIcons()
    for _, icon in ipairs(activeUnavailableIcons) do
        if icon then
            icon:Show()
        end
    end
    
    addon.Config:DebugPrint("Real icons restored after preview mode")
end

-- Update preview frame sizes based on current config (no icons needed)
function UI:updatePreviewIconSizes()
    if not self.mainFrame or not self.mainFrame.mainPreview then return end
    
    local config = addon.Config
    
    -- Update main preview frame size based on max icon size
    local maxIconSize = math.max(
        config:Get("iconSize1") or 64,
        config:Get("iconSize2") or 32,
        config:Get("iconSize3") or 32
    )
    self.mainFrame.mainPreview:SetSize(math.max(200, maxIconSize * 3 + 20), maxIconSize + 10)
    
    -- Update unavailable preview frame size
    local unavailableSize = config:Get("unavailableIconSize") or 24
    self.mainFrame.unavailablePreview:SetSize(math.max(100, unavailableSize * 2 + 10), unavailableSize + 5)
end

-- Update visibility based on config and group status
function UI:UpdateVisibility()
    if not self:validateFrameState() then
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
        self:startCooldownTextUpdates()
        addon.Config:DebugPrint("Frame shown and updates started")
    else
        self.mainFrame:Hide()
        self:stopCooldownTextUpdates()
        addon.Config:DebugPrint("Frame hidden and updates stopped")
    end
end

-- Show the UI with validation
function UI:Show()
    if not self:validateFrameState() then
        addon.Config:DebugPrint("Cannot show UI - frame state invalid")
        return
    end
    
    
    self.mainFrame:Show()
    self:startCooldownTextUpdates()

    addon.Config:DebugPrint("UI shown manually")
end

-- Hide the UI
function UI:Hide()
    if self.mainFrame then
        self.mainFrame:Hide()
    end
    self:stopCooldownTextUpdates()
    addon.Config:DebugPrint("UI hidden manually")
end

-- Toggle the UI
function UI:Toggle()
    if not self:validateFrameState() then
        addon.Config:DebugPrint("Cannot toggle UI - frame state invalid")
        return
    end
    
    if self.mainFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- Toggle NPC debug frame
function UI:ToggleNPCDebug()
    if self.npcDebugFrame then
        self.npcDebugFrame:Toggle()
    end
end

-- Reset NPC debug frame position
function UI:ResetNPCDebugPosition()
    if self.npcDebugFrame then
        self.npcDebugFrame:resetPosition()
        print("|cff00ff00CC Rotation Helper|r: NPC debug frame position reset")
    end
end

-- Debug function to show detailed icon state
function UI:ShowIconDebug()
    print("|cff00ff00CC Rotation Helper Icon Debug:|r")
    
    if not self.mainFrame then
        print("|cffff0000  ERROR: No mainFrame!|r")
        return
    end
    
    local activeIcons = self.iconPool:getActiveMainIcons()
    print("  Active Icons: " .. tostring(#activeIcons))
    for i, icon in ipairs(activeIcons) do
        if icon then
            print("    Icon " .. i .. ": shown=" .. tostring(icon:IsShown()) .. 
                  ", parent=" .. tostring(icon:GetParent() and icon:GetParent():GetName() or "nil"))
        else
            print("    Icon " .. i .. ": NIL")
        end
    end
    
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

-- AceGUI utility functions
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

-- Update mouse settings based on tooltip config
function UI:UpdateMouseSettings()
    if not self.mainFrame then return end
    
    local config = addon.Config
    local showTooltips = config:Get("showTooltips")
    local anchorLocked = config:Get("anchorLocked")
    
    -- Update main frame mouse settings
    self.mainFrame:EnableMouse(not anchorLocked or showTooltips)
    
    -- Update icon mouse settings via IconPool
    if self.iconPool then
        self.iconPool:updateMouseSettings()
    end
end

-- Validate frame state and recover if necessary
function UI:validateFrameState()
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
    
    -- Only fix parent if it's actually wrong (not just different)
    local currentParent = self.mainFrame:GetParent()
    if currentParent and currentParent ~= UIParent then
        addon.Config:DebugPrint("MainFrame has wrong parent (" .. tostring(currentParent:GetName()) .. "), fixing to UIParent")
        -- Store position before reparenting
        local point, relativeTo, relativePoint, xOfs, yOfs = self.mainFrame:GetPoint()
        self.mainFrame:ClearAllPoints()
        self.mainFrame:SetParent(UIParent)
        -- Restore position if we had one
        if point then
            self.mainFrame:SetPoint(point, UIParent, relativePoint, xOfs, yOfs)
        end
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
    if not self:validateFrameState() then
        addon.Config:DebugPrint("Failed to validate/recover frame state")
        return
    end
    
    -- Store current visibility state
    local wasVisible = self.mainFrame:IsShown()
    
    -- Clear all icons using component system
    if self.iconPool then
        local activeIcons = self.iconPool:getActiveMainIcons()
        local activeUnavailableIcons = self.iconPool:getActiveUnavailableIcons()
        
        for i = #activeIcons, 1, -1 do
            self.iconPool:releaseMainIcon(activeIcons[i])
        end
        
        for i = #activeUnavailableIcons, 1, -1 do
            self.iconPool:releaseUnavailableIcon(activeUnavailableIcons[i])
        end
        
        -- Re-initialize icon pools
        self.iconPool:initialize()
        
        -- Re-initialize debug frame
        if self.npcDebugFrame then
            self.npcDebugFrame:Cleanup()
            self.npcDebugFrame:Initialize(self.mainFrame)
        end
    end
    
    -- Update visibility based on new profile settings
    self:UpdateVisibility()
    
    -- Update mouse settings
    self:UpdateMouseSettings()
    
    -- Refresh display to apply new visual settings
    self:RefreshDisplay()
    
    -- Ensure frame is visible if it was before (and should be)
    if wasVisible and addon.CCRotation:ShouldBeActive() then
        self.mainFrame:Show()
    end
    
    -- Debug output
    local config = addon.Config
    config:DebugPrint("Profile switch complete - Position: Handled by SetUserPlaced" .. 
          " | Enabled: " .. tostring(config:Get("enabled")) .. 
          " | MaxIcons: " .. config:Get("maxIcons") .. 
          " | Visible: " .. tostring(self.mainFrame:IsShown()))
end