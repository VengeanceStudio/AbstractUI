local addon = CreateFrame("Frame")
local epoch = 0

local LOOT_DELAY = 0.3

addon:RegisterEvent("LOOT_READY")

addon:SetScript("OnEvent", function()
    if GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
        if (GetTime() - epoch) >= LOOT_DELAY then
            if TSMDestroyBtn and TSMDestroyBtn:IsShown() and TSMDestroyBtn:GetButtonState() == "DISABLED" then
                epoch = GetTime()
                return
            end
            for i = GetNumLootItems(), 1, -1 do
                LootSlot(i)
            end
            epoch = GetTime()
        end
    end
end)
