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
        addon.CCRotation:RegisterEventListener("QUEUE_UPDATED", function(queue)
            self:UpdateDisplay(queue)
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

-- Create main frame - simple approach
function UI:createMainFrame()
    -- Clean up existing frame
    if _G["CCRotationMainFrame"] then
        _G["CCRotationMainFrame"]:Hide()
        _G["CCRotationMainFrame"] = nil
    end
    
    -- Create frame directly
    self.mainFrame = CreateFrame("Frame", "CCRotationMainFrame", UIParent)
    self.mainFrame:SetSize(200, 64)
    
    -- Restore position from config or use default
    self:restoreFramePosition()
    
    -- Create container
    self.mainFrame.container = CreateFrame("Frame", nil, self.mainFrame)
    self.mainFrame.container:SetAllPoints()

    -- Setup main frame properties
    self:setupMainFrame()
end

-- Setup main frame properties
function UI:setupMainFrame()
    local frame = self.mainFrame
    local config = addon.Config
    
    frame:SetSize(200, 64)
    
    -- Make frame movable (required for SetUserPlaced)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

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
        -- Save position to config after drag
        if addon and addon.UI then
            addon.UI:saveFramePosition()
        end
    end)

    
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

-- Update only the cooldown text and dangerous cast text on visible icons
function UI:updateCooldownText()
    local now = GetTime()
    local activeIcons = self.iconPool:getActiveMainIcons()
    
    for i, icon in ipairs(activeIcons) do
        if icon.queueData and icon:IsShown() then
            local cooldownData = icon.queueData
            
            -- Update cooldown text if enabled
            if addon.Config:Get("showCooldownText") then
                local charges = cooldownData.charges or 0
                local isReady = charges > 0 or cooldownData.expirationTime <= now
                
                if isReady then
                    icon.cooldownText:SetText("")
                else
                    local timeLeft = cooldownData.expirationTime - now
                    icon.cooldownText:SetText(self.iconRenderer:formatTime(timeLeft))
                end
            end
            
            -- Update dangerous cast text (for smooth countdown)
            self.iconRenderer:updateDangerousCastText(icon, i, cooldownData, now)
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
        self:UpdateDisplay(addon.CCRotation.cooldownQueue)
    end
    
    -- Update preview frames if config is open
    if self.configPreviewActive then
        self:updatePreviewIconSizes()
    end
end

-- Update display with current queue (main function)
function UI:UpdateDisplay(queue)
    if not self.mainFrame or not self.mainFrame.container then return end
    
    if not queue then
        return
    end
    
    local now = GetTime()
    
    -- Use component-based rendering (this should be safe during combat)
    self.iconRenderer:updateMainIcons(queue, now, self.mainFrame)
    
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
    
    self.mainFrame:SetSize(frameWidth, frameHeight)
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
    if not self.mainFrame.mainPreview then
        addon.Config:DebugPrint("Preview frames missing, recreating...")
        self:createPreviewFrames(self.mainFrame)
    end
    
    -- Update positioning first
    local config = addon.Config
    
    -- Hide real icons when showing preview
    self:hideRealIcons()
    
    -- Show preview frames with error handling
    if self.mainFrame.mainPreview then
        self.mainFrame.mainPreview:Show()
        addon.Config:DebugPrint("Main preview shown")
    else
        addon.Config:DebugPrint("ERROR: Main preview frame missing")
    end
    
    
    -- Update sample icon sizes
    self:updatePreviewIconSizes()
    
    addon.Config:DebugPrint("Config preview mode enabled")
end

-- Hide preview frames
function UI:hideConfigPreview()
    if not self.mainFrame then return end
    
    self.mainFrame.mainPreview:Hide()
    
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
    if not self.mainFrame or not self.mainFrame.container then
        addon.Config:DebugPrint("MainFrame invalid, recreating")
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
    config:DebugPrint("Profile switch complete - Position: Saved in config" .. 
          " | Enabled: " .. tostring(config:Get("enabled")) .. 
          " | MaxIcons: " .. config:Get("maxIcons") .. 
          " | Visible: " .. tostring(self.mainFrame:IsShown()))
end

-- Save current frame position to config (using AceGUI approach)
function UI:saveFramePosition()
    if not self.mainFrame then 
        return 
    end
    
    -- Use AceGUI's approach: GetTop() and GetLeft()
    local top = self.mainFrame:GetTop()
    local left = self.mainFrame:GetLeft()
    
    if top and left then
        local config = addon.Config
        config:Set("frameTop", top)
        config:Set("frameLeft", left)
    end
end

-- Restore frame position from config (using AceGUI approach)
function UI:restoreFramePosition()
    if not self.mainFrame then return end
    
    local config = addon.Config
    local savedTop = config:Get("frameTop")
    local savedLeft = config:Get("frameLeft")
    
    if savedTop and savedLeft then
        -- Restore saved position using AceGUI's method
        self.mainFrame:ClearAllPoints()
        self.mainFrame:SetPoint("TOP", UIParent, "BOTTOM", 0, savedTop)
        self.mainFrame:SetPoint("LEFT", UIParent, "LEFT", savedLeft, 0)
        config:DebugPrint("Frame position restored:", savedTop, savedLeft)
    else
        -- Use default position
        self.mainFrame:SetPoint("CENTER", UIParent, "CENTER", 354, 134)
        config:DebugPrint("Frame position set to default")
    end
end