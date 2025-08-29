local addonName, addon = ...

-- Profile-related commands: profile, profiles, resetdb
addon.ProfileCommands = {}

function addon.ProfileCommands:profile()
    -- Show current profile and available profiles
    local current = addon.Config:GetCurrentProfileName()
    local profiles = addon.Config:GetProfileNames()
    print("|cff00ff00CC Rotation Helper|r: Current profile: " .. current)
    print("Available profiles: " .. table.concat(profiles, ", "))
end

function addon.ProfileCommands:resetdb()
    -- Manual database reset for corrupted profiles
    _G["CCRotationDB"] = nil
    addon.Config.database = nil
    addon.Config:Initialize()
    print("|cff00ff00CC Rotation Helper|r: Database reset complete. All settings will be restored to defaults.")
end