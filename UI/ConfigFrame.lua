local addonName, addon = ...

-- Get AceGUI reference
local AceGUI = LibStub("AceGUI-3.0")

-- Configuration frame using AceGUI
function addon.UI:CreateConfigFrame()
    if self.configFrame then 
        self.configFrame:Show()
        return 
    end
    
    -- Create main frame using AceGUI
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("CC Rotation Helper - Configuration")
    frame:SetStatusText("Configure your CC rotation settings")
    frame:SetWidth(900)
    frame:SetHeight(800)
    frame:SetLayout("Fill")
    
    -- Create tab group for organized settings
    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    tabGroup:SetTabs({
        {text="Display", value="display"},
        {text="Text", value="text"}, 
        {text="Icons", value="icons"},
        {text="Spells", value="spells"},
        {text="Npcs", value="npcs"},
        {text="Players", value="players"},
        {text="Profiles", value="profiles"}
    })
    tabGroup:SetCallback("OnGroupSelected", function(container, event, group)
        function container:RefreshCurrentTab()
            tabGroup:SelectTab(group)
        end

        container:ReleaseChildren()
        if group == "profiles" then
            -- Use ProfilesTab module for component-based implementation
            if not addon.UI.ProfilesTab then
                -- Load ProfilesTab module if not already loaded
                local ProfilesTab = addon.ProfilesTabModule or {}
                if not ProfilesTab.create then
                    error("ProfilesTab module not found or invalid")
                end
                addon.UI.ProfilesTab = ProfilesTab
            end
            addon.UI.ProfilesTab.create(container)
        elseif group == "display" then
            self:CreateDisplayTab(container)
        elseif group == "text" then
            self:CreateTextTab(container)
        elseif group == "icons" then
            self:CreateIconsTab(container)
        elseif group == "spells" then
            -- Use SpellsTab module for component-based implementation
            if not addon.UI.SpellsTab then
                -- Load SpellsTab module if not already loaded
                local SpellsTab = addon.SpellsTabModule or {}
                if not SpellsTab.create then
                    error("SpellsTab module not found or invalid")
                end
                addon.UI.SpellsTab = SpellsTab
            end
            addon.UI.SpellsTab.create(container)
        elseif group == "npcs" then
            if not addon.UI.NPCsTab then
                local NPCsTab = addon.NPCsTabModule or {}
                addon.UI.NPCsTab = NPCsTab
            end
            
            if addon.UI.NPCsTab.create then
                addon.UI.NPCsTab.create(container)
            else
                error("NPCsTab module not loaded. Check that UI/Tabs/NPCsTab.lua is loaded.")
            end
        elseif group == "players" then
            if not addon.UI.PlayersTab then
                local PlayersTab = addon.PlayersTabModule or {}
                addon.UI.PlayersTab = PlayersTab
            end
            
            if addon.UI.PlayersTab.create then
                addon.UI.PlayersTab.create(container)
            else
                error("PlayersTab module not loaded. Check that UI/Tabs/PlayersTab.lua is loaded.")
            end
        end
    end)
    tabGroup:SelectTab("profiles")
    frame:AddChild(tabGroup)
    
    -- Store reference
    self.configFrame = frame
    
    -- Handle frame closing
    frame:SetCallback("OnClose", function(widget)
        widget:Hide()
    end)
end


-- Create Display tab content
function addon.UI:CreateDisplayTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Main enabled checkbox
    local enabledCheck = AceGUI:Create("CheckBox")
    enabledCheck:SetLabel("Enable CC Rotation Helper")
    enabledCheck:SetValue(addon.Config:Get("enabled"))
    enabledCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("enabled", value)
        if addon.UI.UpdateVisibility then
            addon.UI:UpdateVisibility()
        end
    end)
    enabledCheck:SetFullWidth(true)
    scroll:AddChild(enabledCheck)
    
    -- Show in solo checkbox
    local soloCheck = AceGUI:Create("CheckBox")
    soloCheck:SetLabel("Show when not in group")
    soloCheck:SetValue(addon.Config:Get("showInSolo"))
    soloCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("showInSolo", value)
        
        -- Rebuild queue first in case visibility affects queue logic
        if addon.CCRotation and addon.CCRotation.RebuildQueue then
            addon.CCRotation:RebuildQueue()
        end
        
        -- Update visibility (this shows/hides the frame)
        if addon.UI.UpdateVisibility then
            addon.UI:UpdateVisibility()
        end
        
        -- Force display refresh to show the rebuilt queue
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    soloCheck:SetFullWidth(true)
    scroll:AddChild(soloCheck)
    
    -- Show spell names
    local spellNameCheck = AceGUI:Create("CheckBox")
    spellNameCheck:SetLabel("Show spell names")
    spellNameCheck:SetValue(addon.Config:Get("showSpellName"))
    spellNameCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("showSpellName", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    spellNameCheck:SetFullWidth(true)
    scroll:AddChild(spellNameCheck)
    
    -- Show player names
    local playerNameCheck = AceGUI:Create("CheckBox")
    playerNameCheck:SetLabel("Show player names")
    playerNameCheck:SetValue(addon.Config:Get("showPlayerName"))
    playerNameCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("showPlayerName", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    playerNameCheck:SetFullWidth(true)
    scroll:AddChild(playerNameCheck)
    
    -- Show cooldown text
    local cooldownTextCheck = AceGUI:Create("CheckBox")
    cooldownTextCheck:SetLabel("Show cooldown numbers")
    cooldownTextCheck:SetValue(addon.Config:Get("showCooldownText"))
    cooldownTextCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("showCooldownText", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    cooldownTextCheck:SetFullWidth(true)
    scroll:AddChild(cooldownTextCheck)
    
    -- Show tooltips
    local tooltipCheck = AceGUI:Create("CheckBox")
    tooltipCheck:SetLabel("Show tooltips on hover")
    tooltipCheck:SetValue(addon.Config:Get("showTooltips"))
    tooltipCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("showTooltips", value)
        -- Update mouse settings to enable/disable click-through
        if addon.UI.UpdateMouseSettings then
            addon.UI:UpdateMouseSettings()
        end
    end)
    tooltipCheck:SetFullWidth(true)
    scroll:AddChild(tooltipCheck)
    
    -- Highlight next spell
    local highlightCheck = AceGUI:Create("CheckBox")
    highlightCheck:SetLabel("Highlight next spell")
    highlightCheck:SetValue(addon.Config:Get("highlightNext"))
    highlightCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("highlightNext", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    highlightCheck:SetFullWidth(true)
    scroll:AddChild(highlightCheck)
    
    -- Cooldown decimal threshold slider
    local decimalThresholdSlider = AceGUI:Create("Slider")
    decimalThresholdSlider:SetLabel("Show decimals below (seconds)")
    decimalThresholdSlider:SetSliderValues(0, 10, 1)
    decimalThresholdSlider:SetValue(addon.Config:Get("cooldownDecimalThreshold"))
    decimalThresholdSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("cooldownDecimalThreshold", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    decimalThresholdSlider:SetFullWidth(true)
    scroll:AddChild(decimalThresholdSlider)
    
    -- Anchor lock checkbox
    local anchorLockCheck = AceGUI:Create("CheckBox")
    anchorLockCheck:SetLabel("Lock frame position (prevents Shift+drag movement)")
    anchorLockCheck:SetValue(addon.Config:Get("anchorLocked"))
    anchorLockCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("anchorLocked", value)
        -- Update mouse settings to enable/disable click-through
        if addon.UI.UpdateMouseSettings then
            addon.UI:UpdateMouseSettings()
        end
    end)
    anchorLockCheck:SetFullWidth(true)
    scroll:AddChild(anchorLockCheck)
    
    -- Debug mode checkbox
    local debugCheck = AceGUI:Create("CheckBox")
    debugCheck:SetLabel("Debug mode (shows detailed debug messages)")
    debugCheck:SetValue(addon.Config:Get("debugMode"))
    debugCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("debugMode", value)
        local state = value and "enabled" or "disabled"
        print("|cff00ff00CC Rotation Helper|r: Debug mode " .. state)
    end)
    debugCheck:SetFullWidth(true)
    scroll:AddChild(debugCheck)
    
    
end

-- Create Text tab content
function addon.UI:CreateTextTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Spell name font size slider
    local spellNameFontSlider = AceGUI:Create("Slider")
    spellNameFontSlider:SetLabel("Spell Name Font Size")
    spellNameFontSlider:SetSliderValues(8, 24, 1)
    spellNameFontSlider:SetValue(addon.Config:Get("spellNameFontSize"))
    spellNameFontSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("spellNameFontSize", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    spellNameFontSlider:SetFullWidth(true)
    scroll:AddChild(spellNameFontSlider)
    
    -- Spell name max length slider
    local spellNameLengthSlider = AceGUI:Create("Slider")
    spellNameLengthSlider:SetLabel("Spell Name Max Length")
    spellNameLengthSlider:SetSliderValues(5, 50, 1)
    spellNameLengthSlider:SetValue(addon.Config:Get("spellNameMaxLength"))
    spellNameLengthSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("spellNameMaxLength", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    spellNameLengthSlider:SetFullWidth(true)
    scroll:AddChild(spellNameLengthSlider)
    
    -- Player name font size slider
    local playerNameFontSlider = AceGUI:Create("Slider")
    playerNameFontSlider:SetLabel("Player Name Font Size")
    playerNameFontSlider:SetSliderValues(8, 24, 1)
    playerNameFontSlider:SetValue(addon.Config:Get("playerNameFontSize"))
    playerNameFontSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("playerNameFontSize", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    playerNameFontSlider:SetFullWidth(true)
    scroll:AddChild(playerNameFontSlider)
    
    -- Player name max length slider
    local playerNameLengthSlider = AceGUI:Create("Slider")
    playerNameLengthSlider:SetLabel("Player Name Max Length")
    playerNameLengthSlider:SetSliderValues(3, 30, 1)
    playerNameLengthSlider:SetValue(addon.Config:Get("playerNameMaxLength"))
    playerNameLengthSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("playerNameMaxLength", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    playerNameLengthSlider:SetFullWidth(true)
    scroll:AddChild(playerNameLengthSlider)
    
    -- Cooldown font size percentage slider
    local cooldownFontSlider = AceGUI:Create("Slider")
    cooldownFontSlider:SetLabel("Cooldown Font Size (% of icon)")
    cooldownFontSlider:SetSliderValues(10, 50, 1)
    cooldownFontSlider:SetValue(addon.Config:Get("cooldownFontSizePercent") or 25)
    cooldownFontSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("cooldownFontSizePercent", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    cooldownFontSlider:SetFullWidth(true)
    scroll:AddChild(cooldownFontSlider)
end

-- Create Icons tab content
function addon.UI:CreateIconsTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    container:AddChild(scroll)
    
    -- Icon zoom slider
    local iconZoomSlider = AceGUI:Create("Slider")
    iconZoomSlider:SetLabel("Icon Zoom (Texture scale within frame)")
    iconZoomSlider:SetSliderValues(0.3, 3.0, 0.1)
    iconZoomSlider:SetValue(addon.Config:Get("iconZoom"))
    iconZoomSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("iconZoom", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    iconZoomSlider:SetFullWidth(true)
    scroll:AddChild(iconZoomSlider)
    
    -- Max icons slider
    local maxIconsSlider = AceGUI:Create("Slider")
    maxIconsSlider:SetLabel("Max Icons")
    maxIconsSlider:SetSliderValues(1, 5, 1)
    maxIconsSlider:SetValue(addon.Config:Get("maxIcons"))
    
    -- Individual icon controls
    local iconSizeSliders = {}
    local iconSpellNameChecks = {}
    local iconPlayerNameChecks = {}
    
    for i = 1, 5 do
        -- Icon size slider
        local iconSlider = AceGUI:Create("Slider")
        iconSlider:SetLabel("Icon " .. i .. " Size")
        iconSlider:SetSliderValues(16, 128, 1)
        iconSlider:SetValue(addon.Config:Get("iconSize" .. i))
        iconSlider:SetCallback("OnValueChanged", function(widget, event, value)
            addon.Config:Set("iconSize" .. i, value)
            if addon.UI.RefreshDisplay then
                addon.UI:RefreshDisplay()
            end
        end)
        iconSlider:SetFullWidth(true)
        scroll:AddChild(iconSlider)
        iconSizeSliders[i] = iconSlider
        
        
        -- Initially hide controls beyond maxIcons
        if i > addon.Config:Get("maxIcons") then
            iconSlider.frame:Hide()
        end
    end
    
    -- Add callback and widget for max icons slider
    maxIconsSlider:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("maxIcons", value)
        
        -- Show/hide icon controls based on maxIcons
        for i = 1, 5 do
            if iconSizeSliders[i] then
                if i <= value then
                    iconSizeSliders[i].frame:Show()
                else
                    iconSizeSliders[i].frame:Hide()
                end
            end
        end
        
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    maxIconsSlider:SetFullWidth(true)
    scroll:AddChild(maxIconsSlider)
    
    -- Create dynamic glow settings
    self:CreateGlowSettings(scroll)
end

-- Create dynamic glow settings that show/hide based on selected type
function addon.UI:CreateGlowSettings(scroll)
    -- Glow Settings Section
    local glowHeader = AceGUI:Create("Heading")
    glowHeader:SetText("Glow Settings")
    glowHeader:SetFullWidth(true)
    scroll:AddChild(glowHeader)
    
    -- Highlight Next checkbox
    local highlightNextCheck = AceGUI:Create("CheckBox")
    highlightNextCheck:SetLabel("Highlight Player's First Spell")
    highlightNextCheck:SetValue(addon.Config:Get("highlightNext"))
    highlightNextCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("highlightNext", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    highlightNextCheck:SetFullWidth(true)
    scroll:AddChild(highlightNextCheck)
    
    -- Glow Only In Combat checkbox
    local glowOnlyInCombatCheck = AceGUI:Create("CheckBox")
    glowOnlyInCombatCheck:SetLabel("Only Show Glow In Combat")
    glowOnlyInCombatCheck:SetValue(addon.Config:Get("glowOnlyInCombat"))
    glowOnlyInCombatCheck:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("glowOnlyInCombat", value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
    glowOnlyInCombatCheck:SetFullWidth(true)
    scroll:AddChild(glowOnlyInCombatCheck)
    
    -- Glow Type dropdown
    local glowTypeDropdown = AceGUI:Create("Dropdown")
    glowTypeDropdown:SetLabel("Glow Type")
    glowTypeDropdown:SetList({
        Pixel = "Pixel Glow",
        ACShine = "Autocast Shine",
        Proc = "Proc Glow"
    })
    glowTypeDropdown:SetValue(addon.Config:Get("glowType"))
    scroll:AddChild(glowTypeDropdown)
    
    -- Container for dynamic controls
    local dynamicContainer = AceGUI:Create("SimpleGroup")
    dynamicContainer:SetFullWidth(true)
    dynamicContainer:SetLayout("Flow")
    scroll:AddChild(dynamicContainer)
    
    -- Function to rebuild controls for selected glow type
    local function rebuildGlowControls(glowType)
        -- Clear existing controls
        dynamicContainer:ReleaseChildren()
        
        -- Color picker (all types except Proc)
        if glowType ~= "Proc" then
            local glowColorPicker = AceGUI:Create("ColorPicker")
            glowColorPicker:SetLabel("Glow Color")
            local currentColor = addon.Config:Get("glowColor")
            glowColorPicker:SetColor(currentColor[1], currentColor[2], currentColor[3], currentColor[4])
            glowColorPicker:SetCallback("OnValueChanged", function(widget, event, r, g, b, a)
                addon.Config:Set("glowColor", {r, g, b, a})
                if addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
            end)
            glowColorPicker:SetFullWidth(true)
            dynamicContainer:AddChild(glowColorPicker)
        end
        
        -- Type-specific controls
        if glowType == "Pixel" then
            -- Frequency for Pixel glow
            local glowFrequencySlider = AceGUI:Create("Slider")
            glowFrequencySlider:SetLabel("Frequency/Speed")
            glowFrequencySlider:SetSliderValues(-2, 2, 0.05)
            glowFrequencySlider:SetValue(addon.Config:Get("glowFrequency"))
            glowFrequencySlider:SetCallback("OnValueChanged", function(widget, event, value)
                addon.Config:Set("glowFrequency", value)
                if addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
            end)
            glowFrequencySlider:SetFullWidth(true)
            dynamicContainer:AddChild(glowFrequencySlider)
            
            local pixelControls = {
                {key = "glowLines", label = "Number of Lines", min = 1, max = 30, step = 1},
                {key = "glowLength", label = "Line Length", min = 1, max = 20, step = 1},
                {key = "glowThickness", label = "Line Thickness", min = 1, max = 20, step = 1},
                {key = "glowXOffset", label = "X Offset", min = -20, max = 20, step = 1},
                {key = "glowYOffset", label = "Y Offset", min = -20, max = 20, step = 1}
            }
            
            for _, controlData in ipairs(pixelControls) do
                local slider = AceGUI:Create("Slider")
                slider:SetLabel(controlData.label)
                slider:SetSliderValues(controlData.min, controlData.max, controlData.step)
                slider:SetValue(addon.Config:Get(controlData.key))
                slider:SetCallback("OnValueChanged", function(widget, event, value)
                    addon.Config:Set(controlData.key, value)
                    if addon.UI.RefreshDisplay then
                        addon.UI:RefreshDisplay()
                    end
                end)
                slider:SetFullWidth(true)
                dynamicContainer:AddChild(slider)
            end
            
            local glowBorderCheck = AceGUI:Create("CheckBox")
            glowBorderCheck:SetLabel("Add Border")
            glowBorderCheck:SetValue(addon.Config:Get("glowBorder"))
            glowBorderCheck:SetCallback("OnValueChanged", function(widget, event, value)
                addon.Config:Set("glowBorder", value)
                if addon.UI.RefreshDisplay then
                    addon.UI:RefreshDisplay()
                end
            end)
            glowBorderCheck:SetFullWidth(true)
            dynamicContainer:AddChild(glowBorderCheck)
            
        elseif glowType == "ACShine" then
            local acControls = {
                {key = "glowParticleGroups", label = "Particle Groups (N)", min = 1, max = 10, step = 1},
                {key = "glowACFrequency", label = "Frequency (negative = reverse)", min = -2, max = 2, step = 0.025},
                {key = "glowScale", label = "Scale", min = 0.1, max = 3.0, step = 0.1},
                {key = "glowACXOffset", label = "X Offset", min = -20, max = 20, step = 1},
                {key = "glowACYOffset", label = "Y Offset", min = -20, max = 20, step = 1}
            }
            
            for _, controlData in ipairs(acControls) do
                local slider = AceGUI:Create("Slider")
                slider:SetLabel(controlData.label)
                slider:SetSliderValues(controlData.min, controlData.max, controlData.step)
                slider:SetValue(addon.Config:Get(controlData.key))
                slider:SetCallback("OnValueChanged", function(widget, event, value)
                    addon.Config:Set(controlData.key, value)
                    if addon.UI.RefreshDisplay then
                        addon.UI:RefreshDisplay()
                    end
                end)
                slider:SetFullWidth(true)
                dynamicContainer:AddChild(slider)
            end
        end
        -- Proc glow has no additional settings
    end
    
    -- Set initial controls
    rebuildGlowControls(addon.Config:Get("glowType"))
    
    -- Update dropdown callback to rebuild controls
    glowTypeDropdown:SetCallback("OnValueChanged", function(widget, event, value)
        addon.Config:Set("glowType", value)
        rebuildGlowControls(value)
        if addon.UI.RefreshDisplay then
            addon.UI:RefreshDisplay()
        end
    end)
end

-- Function to renumber spell priorities to eliminate gaps
function addon.UI:RenumberSpellPriorities()
    -- Get all active spells
    local allSpells = {}
    
    -- Add database spells (if not inactive)
    for spellID, data in pairs(addon.Database.defaultSpells) do
        if not addon.Config.db.inactiveSpells[spellID] then
            allSpells[spellID] = {
                name = data.name,
                ccType = data.ccType,
                priority = data.priority,
                source = "database"
            }
        end
    end
    
    -- Add custom spells (if not inactive, override database if same ID)
    for spellID, data in pairs(addon.Config.db.customSpells) do
        if not addon.Config.db.inactiveSpells[spellID] then
            allSpells[spellID] = {
                name = data.name,
                ccType = data.ccType,
                priority = data.priority,
                source = "custom"
            }
        end
    end
    
    -- Sort spells by current priority
    local sortedSpells = {}
    for spellID, data in pairs(allSpells) do
        table.insert(sortedSpells, {spellID = spellID, data = data})
    end
    table.sort(sortedSpells, function(a, b) return a.data.priority < b.data.priority end)
    
    -- Renumber priorities starting from 1
    for i, spell in ipairs(sortedSpells) do
        local newPriority = i
        
        if spell.data.source == "custom" then
            -- Update custom spell priority
            addon.Config.db.customSpells[spell.spellID].priority = newPriority
        else
            -- Create custom entry to override database spell
            addon.Config.db.customSpells[spell.spellID] = {
                name = spell.data.name,
                ccType = spell.data.ccType,
                priority = newPriority
            }
        end
    end
end

-- Function to move spell priority up or down
function addon.UI:MoveSpellPriority(spellID, spellData, direction, sortedSpells, currentIndex)
    local targetIndex = direction == "up" and currentIndex - 1 or currentIndex + 1
    
    if targetIndex < 1 or targetIndex > #sortedSpells then
        return -- Can't move beyond bounds
    end
    
    local targetSpell = sortedSpells[targetIndex]
    local currentPriority = spellData.priority
    local targetPriority = targetSpell.data.priority
    
    -- Swap priorities
    if spellData.source == "custom" then
        -- Update custom spell priority
        addon.Config.db.customSpells[spellID].priority = targetPriority
    else
        -- Create custom entry to override database spell
        addon.Config.db.customSpells[spellID] = {
            name = spellData.name,
            ccType = spellData.ccType,
            priority = targetPriority
        }
    end
    
    if targetSpell.data.source == "custom" then
        -- Update target custom spell priority
        addon.Config.db.customSpells[targetSpell.spellID].priority = currentPriority
    else
        -- Create custom entry to override target database spell
        addon.Config.db.customSpells[targetSpell.spellID] = {
            name = targetSpell.data.name,
            ccType = targetSpell.data.ccType,
            priority = currentPriority
        }
    end
    
    -- Immediately update tracked cooldowns cache and rebuild queue
    if addon.CCRotation then
        -- Update the tracked cooldowns cache with new priorities
        addon.CCRotation.trackedCooldowns = addon.Config:GetTrackedSpells()
        -- Force immediate synchronous rebuild instead of debounced rebuild
        if addon.CCRotation.DoRebuildQueue then
            addon.CCRotation:DoRebuildQueue()
        elseif addon.CCRotation.RebuildQueue then
            addon.CCRotation:RebuildQueue()
        end
    end
end




-- Show configuration frame
function addon.UI:ShowConfigFrame()
    if not AceGUI then
        print("|cffff0000CC Rotation Helper:|r AceGUI-3.0 not found! Please install Ace3 libraries.")
        return
    end
    
    self:CreateConfigFrame()
    self.configFrame:Show()
end
