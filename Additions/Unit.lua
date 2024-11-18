function UnitGetTotalAbsorbs(unit)
    return 0
end

function UnitSelectionType(unit, useExtendedColors)
    if UnitIsFriend(unit, "player") then return 3 end
    if UnitIsEnemy(unit, "player") then return 0 end
    if UnitIsUnit(unit, "pet") or UnitIsOtherPlayersPet(unit) then return 4 end
    return 999
end