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
    
    addon.Config:DebugPrint("Initializing UI system")
    
    -- Initialize components
    self.iconPool = addon.Components.IconPool:new()
    self.glowManager = addon.Components.GlowManager:new()
    self.iconRenderer = addon.Components.IconRenderer:new(self.iconPool, self.glowManager)
    
    -- Create main frame
    self:createMainFrame()
    
    -- Initialize component systems
    self.iconPool:initialize()
    
    -- Register for queue update events from RotationCore
    if addon.CCRotation then
        addon.CCRotation:RegisterEventListener("QUEUE_UPDATED", function(queue, unavailableQueue)
            self:UpdateDisplay(queue, unavailableQueue)
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
    
    addon.Config:DebugPrint("UI initialization complete")
end

-- Create main frame with error handling
function UI:createMainFrame()
    local success = pcall(function()
        self.mainFrame = CreateFrame("Frame", "CCRotationMainFrame", UIParent, "CCRotationTemplate")
    end)
    
    if not success or not self.mainFrame then
        addon.Config:DebugPrint("Failed to create mainFrame with template, creating basic frame")
        self:createBasicFrame()
    end

    -- Always create debug anchor
    self:createDebugAnchor()
    
    -- Setup main frame properties
    self:setupMainFrame()
end

-- Create basic frame fallback
function UI:createBasicFrame()
    self.mainFrame = CreateFrame("Frame", "CCRotationMainFrame", UIParent)
    self.mainFrame:SetSize(200, 64)
    
    -- Create basic container
    self.mainFrame.container = CreateFrame("Frame", nil, self.mainFrame)
    self.mainFrame.container:SetAllPoints()
end

-- Create debug anchor
function UI:createDebugAnchor()
    if not self.mainFrame.anchor then
        addon.Config:DebugPrint("Creating debug anchor")
        self.mainFrame.anchor = CreateFrame("Frame", "CCRotationDebugAnchor", UIParent)
        self.mainFrame.anchor:SetSize(20, 20)
        self.mainFrame.anchor:SetFrameStrata("TOOLTIP")
        self.mainFrame.anchor:SetFrameLevel(1000)
        
        -- Create border texture
        local border = self.mainFrame.anchor:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints()
        border:SetColorTexture(1, 0, 0, 1.0)
        
        -- Create inner transparent area
        local inner = self.mainFrame.anchor:CreateTexture(nil, "BACKGROUND")
        inner:SetPoint("TOPLEFT", 2, -2)
        inner:SetPoint("BOTTOMRIGHT", -2, 2)
        inner:SetColorTexture(0, 0, 0, 0.3)
        
        -- Store references
        self.mainFrame.anchor.border = border
        self.mainFrame.anchor.inner = inner
        
        self.mainFrame.anchor:Hide()
        addon.Config:DebugPrint("Debug anchor created successfully")
    end
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
            local isReady = charges > 0 or cooldownData.expirationTime <= now
            
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
end

-- Update display with current queue (main function)
function UI:UpdateDisplay(queue, unavailableQueue)
    if not self.mainFrame or not self.mainFrame.container then return end
    
    if not queue then
        return
    end
    
    local now = GetTime()
    
    -- Use component-based rendering
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
    
    local totalWidth = 0
    local totalHeight = 0
    
    -- Calculate main queue dimensions
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
    
    -- Position unavailable container below main container
    if visibleUnavailableIcons > 0 and config:Get("showUnavailableQueue") then
        local offset = config:Get("unavailableQueueOffset")
        self.mainFrame.unavailableContainer:ClearAllPoints()
        self.mainFrame.unavailableContainer:SetPoint("TOP", self.mainFrame.container, "BOTTOM", 0, -offset)
    end
    
    -- Set minimum size
    if totalWidth == 0 then totalWidth = 1 end
    if totalHeight == 0 then totalHeight = 1 end
    
    self.mainFrame:SetSize(totalWidth, totalHeight)
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
    
    -- Position and show debug anchor if in debug mode
    if addon.Config and addon.Config:Get("debugMode") and self.mainFrame.anchor then
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