-- GlowManager.lua - Centralized glow effect management
-- Handles all glow-related functionality for icons

local addonName, addon = ...

local GlowManager = {}
local LCG = LibStub("LibCustomGlow-1.0")

function GlowManager:new()
    local instance = {}
    setmetatable(instance, {__index = self})
    return instance
end

-- Initialize glow system for an icon
function GlowManager:initializeIconGlow(icon)
    icon.glowing = false
    icon.glowType = nil

    function icon:StartGlow(config)
        local glowType = config:Get("glowType")
        local glowColor = config:Get("glowColor")

        if self.glowing and glowType == self.glowType then return end

        -- If we swapped glowtype, then stop the existing glow before creating new
        if glowType ~= self.glowType then
            self:StopGlow()
        end

        -- Start the appropriate glow type
        if glowType == "Pixel" then
            LCG.PixelGlow_Start(
                self,
                glowColor,
                config:Get("glowLines"),
                config:Get("glowFrequency"),
                config:Get("glowLength"),
                config:Get("glowThickness"),
                config:Get("glowXOffset"),
                config:Get("glowYOffset"),
                config:Get("glowBorder")
            )
        elseif glowType == "ACShine" then
            LCG.AutoCastGlow_Start(
                self,
                glowColor,
                config:Get("glowParticleGroups"),
                config:Get("glowACFrequency"),
                config:Get("glowScale"),
                config:Get("glowACXOffset"),
                config:Get("glowACYOffset")
            )
        elseif glowType == "Proc" then
            LCG.ProcGlow_Start(self, glowColor)
        end

        self.glowing = true
        self.glowType = glowType
    end

    function icon:StopGlow()
        -- If we're not glowing, we don't need to stop glowing
        if not self.glowing then return end

        LCG.ButtonGlow_Stop(self)
        LCG.PixelGlow_Stop(self)
        LCG.AutoCastGlow_Stop(self)
        LCG.ProcGlow_Stop(self)

        self.glowing = false
    end
end

-- Start glow effect on an icon
function GlowManager:startGlow(icon, config, cooldownData)
    if icon and icon.StartGlow then
        -- Simple glow with normal config - no color changes for now
        icon:StartGlow(config)
    end
end

-- Stop glow effect on an icon
function GlowManager:stopGlow(icon)
    if icon and icon.StopGlow then
        icon:StopGlow()
    end
end

-- Stop all glow effects on an icon (for cleanup)
function GlowManager:stopAllGlows(icon)
    if not icon then return end
    
    LCG.ButtonGlow_Stop(icon)
    LCG.PixelGlow_Stop(icon)
    LCG.AutoCastGlow_Stop(icon)
    LCG.ProcGlow_Stop(icon)
    
    icon.glowing = false
    icon.glowType = nil
end

-- Check if glow should be active for an icon
function GlowManager:shouldGlow(iconIndex, unit, config, cooldownData)
    -- Glow if it's the first icon, it's the player, and glow is enabled
    return iconIndex == 1 and 
           config:Get("highlightNext") and 
           UnitIsUnit(unit, "player") and
           (not config:Get("glowOnlyInCombat") or InCombatLockdown())
end

function GlowManager:getGlowColor(cooldownData, config)
    -- Check if this ability can stop an active dangerous cast
    if cooldownData and cooldownData.dangerousCasts and #cooldownData.dangerousCasts > 0 then
        -- Blue glow for dangerous cast stopping
        return {0.2, 0.5, 1.0}
    else
        -- Normal glow color from config
        return config:Get("glowColor")
    end
end

-- Register component
if not addon.Components then
    addon.Components = {}
end
addon.Components.GlowManager = GlowManager

return GlowManager