function GameTooltip.SetUnitBuffByAuraInstanceID(self, unit, auraInstanceID, filter)
    filter = filter or "HELPFUL"
    GameTooltip:SetUnitBuff(unit, AuraUtil.GetAuraIndexByAuraInstanceID(unit, filter, auraInstanceID), filter)
end

function GameTooltip.SetUnitDebuffByAuraInstanceID(self, unit, auraInstanceID, filter)
    filter = filter or "HARMFUL"
    GameTooltip:SetUnitDebuff(unit, AuraUtil.GetAuraIndexByAuraInstanceID(unit, filter, auraInstanceID), filter)
end
