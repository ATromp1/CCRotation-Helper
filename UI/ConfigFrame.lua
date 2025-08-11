local addonName, addon = ...

-- Get AceGUI reference
local AceGUI = LibStub("AceGUI-3.0")

-- Configuration frame using AceGUI
function addon.UI:CreateConfigFrame()
    if self.configFrame then 
        self.configFrame:Show()
        -- Show preview when reopening existing config frame
        C_Timer.After(0.1, function()
            if addon.UI and addon.UI.showConfigPreview then
                addon.UI:showConfigPreview()
            end
        end)
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
        {text="Profiles", value="profiles"},
        {text="About", value="about"}
    })
    -- Helper function to load and create tab modules
    local function loadTab(tabName, container)
        local tabModules = {
            profiles = addon.ProfilesTabModule,
            display = addon.DisplayTabModule,
            text = addon.TextTabModule,
            icons = addon.IconsTabModule,
            spells = addon.SpellsTabModule,
            npcs = addon.NPCsTabModule,
            players = addon.PlayersTabModule,
            about = addon.AboutTabModule
        }
        
        local moduleProperty = tabName:gsub("^%l", string.upper) .. "Tab"  -- e.g., "profiles" -> "ProfilesTab"
        local tabModule = tabModules[tabName]
        
        -- Load module if not already cached
        if not addon.UI[moduleProperty] then
            if not tabModule or not tabModule.create then
                error(moduleProperty .. " module not found or invalid")
            end
            addon.UI[moduleProperty] = tabModule
        end
        
        -- Create tab content
        addon.UI[moduleProperty].create(container)
    end

    -- Track the currently active tab
    local activeTab = "profiles" -- Default tab
    
    tabGroup:SetCallback("OnGroupSelected", function(container, event, group)
        activeTab = group -- Update active tab tracking
        
        -- Store active tab reference BEFORE releasing children to prevent race conditions
        if addon.UI then
            addon.UI.activeConfigTab = activeTab
        end
        
        function container:RefreshCurrentTab()
            tabGroup:SelectTab(group)
        end

        container:ReleaseChildren()
        loadTab(group, container)
    end)
    tabGroup:SelectTab("profiles")
    frame:AddChild(tabGroup)
    
    -- Initialize active tab tracking
    addon.UI.activeConfigTab = "profiles"
    
    -- Store reference
    self.configFrame = frame
    
    -- Handle frame closing
    frame:SetCallback("OnClose", function(widget)
        -- Hide config preview when closing
        if addon.UI and addon.UI.hideConfigPreview then
            addon.UI:hideConfigPreview()
        end
        widget:Hide()
    end)
    
    -- Show config preview when frame is created (with delay to ensure UI is ready)
    C_Timer.After(0.1, function()
        if addon.UI and addon.UI.showConfigPreview then
            addon.UI:showConfigPreview()
        end
    end)
end


-- Check if a specific config tab is currently active
function addon.UI:IsConfigTabActive(tabName)
    -- Return false if config frame doesn't exist or isn't shown
    if not self.configFrame or not self.configFrame:IsShown() then
        addon.Config:DebugPrint("IsConfigTabActive:", tabName, "- config frame not shown")
        return false
    end
    
    -- Check if the specified tab is currently active
    local isActive = self.activeConfigTab == tabName
    addon.Config:DebugPrint("IsConfigTabActive:", tabName, "- current tab:", self.activeConfigTab, "- result:", isActive)
    return isActive
end

-- Check if editing should be disabled due to party sync (user is follower, not leader)
function addon.UI:IsEditingDisabledByPartySync()
    if not addon.ProfileSync then
        return false
    end
    
    -- Disable editing if profile selection is locked (party sync active and not leader)
    return addon.ProfileSync:IsProfileSelectionLocked()
end

-- Show configuration frame
function addon.UI:ShowConfigFrame()
    if not AceGUI then
        print("|cffff0000CC Rotation Helper:|r AceGUI-3.0 not found! Please install Ace3 libraries.")
        return
    end
    
    -- Ensure main UI is initialized before showing config
    if not self.mainFrame then
        self:Initialize()
    end
    
    self:CreateConfigFrame()
    self.configFrame:Show()
end
