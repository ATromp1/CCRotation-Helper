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

    tabGroup:SetCallback("OnGroupSelected", function(container, event, group)
        function container:RefreshCurrentTab()
            tabGroup:SelectTab(group)
        end

        container:ReleaseChildren()
        loadTab(group, container)
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


-- Show configuration frame
function addon.UI:ShowConfigFrame()
    if not AceGUI then
        print("|cffff0000CC Rotation Helper:|r AceGUI-3.0 not found! Please install Ace3 libraries.")
        return
    end
    
    self:CreateConfigFrame()
    self.configFrame:Show()
end
