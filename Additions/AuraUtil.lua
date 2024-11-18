do
	local function ForEachAuraHelperByIndex(unit, maxCount, filter, func)
		for i = 1, maxCount do
			local done;
			local auraInfo = C_UnitAuras.GetAuraDataByIndex(unit, i, filter);

			if auraInfo then
				done = func(auraInfo)
			end
			if done then
				return i;
			end
		end
		return nil;
	end

	function AuraUtil.GetAuraIndexByAuraInstanceID(unit, filter, auraInstanceID)
		local func = function(aura)
			if aura.auraInstanceID == auraInstanceID then return aura end
		end
		return ForEachAuraHelperByIndex(unit, 32, filter, func);
	end
end
