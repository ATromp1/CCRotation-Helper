local addonName, addon = ...

-- Get AceGUI reference
local AceGUI = LibStub("AceGUI-3.0")

addon.UI.Component = {}

--- Create a horizontal spacer
--- @param width number
function addon.UI.Component:HorizontalSpacer(width)
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetWidth(width)

    return spacer
end

--- Create a horizontal spacer
--- @param height number
function addon.UI.Component:VerticalSpacer(height)
    local spacer = AceGUI:Create("Label")
    spacer:SetText("")
    spacer:SetFullWidth(true)
    spacer:SetHeight(height)

    return spacer
end

--- Create a profile dropdown
--- @param label string
--- @param OnChange function
function addon.UI.Component:ProfilesDropdown(label, OnChange)
    local dropdown = AceGUI:Create("Dropdown")
    dropdown:SetLabel(label)
    dropdown:SetWidth(200)
    local profiles = addon.Config:GetProfileNames()
    dropdown:SetList(profiles)

    if OnChange then
        dropdown:SetCallback("OnValueChanged", function (widget, _event, index) OnChange(profiles[index], widget) end)
    end

    function dropdown:RefreshProfiles()
        profiles = addon.Config:GetProfileNames()
        dropdown:SetList(profiles)
    end

    return dropdown
end

--- Open a confirmation dialog
--- @param name string - Unique string for dialog
--- @param prompt string
--- @param confirmText string
--- @param onConfirm function
--- @param declineText[opt=nil] string
--- @param onDecline[opt=nil] function
function addon.UI.Component:ConfirmationDialog(name, prompt, confirmText, onConfirm, declineText, onDecline)
    DIALOG_PREFIX = "CCRH_CONFIRMATION_DIALOG_"
    StaticPopupDialogs[DIALOG_PREFIX..name] = {
        text = prompt,
        button1 = confirmText,
        button2 = declineText,
        OnAccept = onConfirm,
        OnCancel = onDecline,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopup_Show(DIALOG_PREFIX..name)
end