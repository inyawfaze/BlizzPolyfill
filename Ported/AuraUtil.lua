
do
	local function ForEachAuraHelper(unit, filter, func, usePackedAura, continuationToken, ...)
		-- continuationToken is the first return value of UnitAuraSlots()
		local n = select('#', ...);
		for i=1, n do
			local slot = select(i, ...);
			local done;
			local auraInfo = C_UnitAuras.GetAuraDataBySlot(unit, slot);

			-- Protect against GetAuraDataBySlot desyncing with GetAuraSlots
			if auraInfo then
				if usePackedAura then
					done = func(auraInfo);
				else
					done = func(AuraUtil.UnpackAuraData(auraInfo));
				end
			end
			if done then
				-- if func returns true then no further slots are needed, so don't return continuationToken
				return nil;
			end
		end
		return continuationToken;
	end

	function AuraUtil.ForEachAura(unit, filter, maxCount, func, usePackedAura)
		if maxCount and maxCount <= 0 then
			return;
		end
		local continuationToken;
		repeat
			-- continuationToken is the first return value of UnitAuraSltos
			continuationToken = ForEachAuraHelper(unit, filter, func, usePackedAura, C_UnitAuras.GetAuraSlots(unit, filter, maxCount, continuationToken));
		until continuationToken == nil;
	end
end

function AuraUtil.DefaultAuraCompare(a, b)
	local aFromPlayer = (a.sourceUnit ~= nil) and UnitIsUnit("player", a.sourceUnit) or false;
	local bFromPlayer = (b.sourceUnit ~= nil) and UnitIsUnit("player", b.sourceUnit) or false;
	if aFromPlayer ~= bFromPlayer then
		return aFromPlayer;
	end

	if a.canApplyAura ~= b.canApplyAura then
		return a.canApplyAura;
	end

	return a.auraInstanceID < b.auraInstanceID;
end

AuraUtil.AuraFilters =
{
	Helpful = "HELPFUL",
	Harmful = "HARMFUL",
	Raid = "RAID",
	IncludeNameplateOnly = "INCLUDE_NAME_PLATE_ONLY",
	Player = "PLAYER",
	Cancelable = "CANCELABLE",
	NotCancelable = "NOT_CANCELABLE",
	Maw = "MAW",
};

function AuraUtil.CreateFilterString(...)
	return table.concat({...}, '|');
end

AuraUtil.DispellableDebuffTypes =
{
	Magic = true,
	Curse = true,
	Disease = true,
	Poison = true
};

AuraUtil.AuraUpdateChangedType = EnumUtil.MakeEnum(
	"None",
	"Debuff",
	"Buff",
	"Dispel"
);

AuraUtil.UnitFrameDebuffType = EnumUtil.MakeEnum(
	"BossDebuff",
	"BossBuff",
	"PriorityDebuff",
	"NonBossRaidDebuff",
	"NonBossDebuff"
);

function AuraUtil.UnitFrameDebuffComparator(a, b)
	if a.debuffType ~= b.debuffType then
		return a.debuffType < b.debuffType;
	end

	return AuraUtil.DefaultAuraCompare(a, b);
end

function AuraUtil.ProcessAura(aura, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)
	if aura == nil then
		return AuraUtil.AuraUpdateChangedType.None;
	end

	if aura.isNameplateOnly then
		return AuraUtil.AuraUpdateChangedType.None;
	end

	if aura.isBossAura and not aura.isRaid and not ignoreDebuffs then
		aura.debuffType = aura.isHarmful and AuraUtil.UnitFrameDebuffType.BossDebuff or AuraUtil.UnitFrameDebuffType.BossBuff;
		return AuraUtil.AuraUpdateChangedType.Debuff;
	elseif aura.isHarmful and not aura.isRaid and not ignoreDebuffs then
		if AuraUtil.IsPriorityDebuff(aura.spellId) then
			aura.debuffType = AuraUtil.UnitFrameDebuffType.PriorityDebuff;
			return AuraUtil.AuraUpdateChangedType.Debuff;
		elseif not displayOnlyDispellableDebuffs and AuraUtil.ShouldDisplayDebuff(aura.sourceUnit, aura.spellId) then
			aura.debuffType = AuraUtil.UnitFrameDebuffType.NonBossDebuff;
			return AuraUtil.AuraUpdateChangedType.Debuff;
		end
	elseif aura.isHelpful and not ignoreBuffs and AuraUtil.ShouldDisplayBuff(aura.sourceUnit, aura.spellId, aura.canApplyAura) then
		aura.isBuff = true;
		return AuraUtil.AuraUpdateChangedType.Buff;
	elseif aura.isHarmful and aura.isRaid then
		if displayOnlyDispellableDebuffs and not ignoreDebuffs and not aura.isBossAura and AuraUtil.ShouldDisplayDebuff(aura.sourceUnit, aura.spellId) and not AuraUtil.IsPriorityDebuff(aura.spellId) then
			aura.debuffType = AuraUtil.UnitFrameDebuffType.NonBossRaidDebuff;
			return AuraUtil.AuraUpdateChangedType.Debuff;
		elseif not ignoreDispelDebuffs and AuraUtil.DispellableDebuffTypes[aura.dispelName] ~= nil then
			aura.debuffType = aura.isBossAura and AuraUtil.UnitFrameDebuffType.BossDebuff or AuraUtil.UnitFrameDebuffType.NonBossRaidDebuff;
			return AuraUtil.AuraUpdateChangedType.Dispel;
		end
	end
	
	return AuraUtil.AuraUpdateChangedType.None;
end

do
	-- Cache securecallfunction in case it changes in the global environment
	local securecallfunction = securecallfunction;

	local hasValidPlayer = false;
	EventRegistry:RegisterFrameEvent("PLAYER_ENTERING_WORLD");
	EventRegistry:RegisterFrameEvent("PLAYER_LEAVING_WORLD");
	EventRegistry:RegisterCallback("PLAYER_ENTERING_WORLD", function()
		hasValidPlayer = true;
	end, {});
	EventRegistry:RegisterCallback("PLAYER_LEAVING_WORLD", function()
		hasValidPlayer = false;
	end, {});

	local cachedVisualizationInfo = {};
	
	-- Visualization info is specific to the spec it was checked under
	EventRegistry:RegisterFrameEvent("PLAYER_SPECIALIZATION_CHANGED");
	EventRegistry:RegisterCallback("PLAYER_SPECIALIZATION_CHANGED", function()
		cachedVisualizationInfo = {};
	end, {});

	local function GetCachedVisibilityInfo(spellId)
		if cachedVisualizationInfo[spellId] == nil then
			local newInfo = {SpellGetVisibilityInfo(spellId, UnitAffectingCombat("player") and "RAID_INCOMBAT" or "RAID_OUTOFCOMBAT")};
			if not hasValidPlayer then
				-- Don't cache the info if the player is not valid since we didn't get a valid result
				return unpack(newInfo);
			end
			cachedVisualizationInfo[spellId] = newInfo;
		end

		local info = cachedVisualizationInfo[spellId];
		return unpack(info);
	end

	function AuraUtil.ShouldDisplayDebuff(unitCaster, spellId)
		local hasCustom, alwaysShowMine, showForMySpec = securecallfunction(GetCachedVisibilityInfo, spellId);
		if ( hasCustom ) then
			return showForMySpec or (alwaysShowMine and (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle") );	--Would only be "mine" in the case of something like forbearance.
		else
			return true;
		end
	end

	local cachedSelfBuffChecks = {};
	local function CheckIsSelfBuff(spellId)
		if cachedSelfBuffChecks[spellId] == nil then
			cachedSelfBuffChecks[spellId] = SpellIsSelfBuff(spellId);
		end

		return cachedSelfBuffChecks[spellId];
	end

	function AuraUtil.ShouldDisplayBuff(unitCaster, spellId, canApplyAura)
		local hasCustom, alwaysShowMine, showForMySpec = securecallfunction(GetCachedVisibilityInfo, spellId);
	
		if ( hasCustom ) then
			return showForMySpec or (alwaysShowMine and (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle"));
		else
			return (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle") and canApplyAura and not securecallfunction(CheckIsSelfBuff, spellId);
		end
	end

	local cachedPriorityChecks = {};
	local function CheckIsPriorityAura(spellId)
		if cachedPriorityChecks[spellId] == nil then
			cachedPriorityChecks[spellId] = SpellIsPriorityAura(spellId);
		end

		return cachedPriorityChecks[spellId];
	end

	local _, classFilename = UnitClass("player");
	if ( classFilename == "PALADIN" ) then
		AuraUtil.IsPriorityDebuff = function(spellId)
			local isForbearance = (spellId == 25771);
			return isForbearance or securecallfunction(CheckIsPriorityAura, spellId);
		end
	else
		AuraUtil.IsPriorityDebuff = function(spellId)
			return securecallfunction(CheckIsPriorityAura, spellId);
		end
	end

	local function DumpCaches()
		cachedVisualizationInfo = {};
		cachedSelfBuffChecks = {};
		cachedPriorityChecks = {};
	end
	EventRegistry:RegisterFrameEvent("PLAYER_REGEN_ENABLED");
	EventRegistry:RegisterFrameEvent("PLAYER_REGEN_DISABLED");
	EventRegistry:RegisterCallback("PLAYER_REGEN_ENABLED", DumpCaches, {});
	EventRegistry:RegisterCallback("PLAYER_REGEN_DISABLED", DumpCaches, {});
end