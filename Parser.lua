local _, Abstract = ...
local F = Abstract.funcs

local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local UnitAffectingCombat = UnitAffectingCombat
local UnitIsVisible = UnitIsVisible
local GetSpellInfo = GetSpellInfo
local GetUnitName = GetUnitName
local UnitIsUnit = UnitIsUnit
local UnitGUID = UnitGUID
local UnitExists = UnitExists

local SWING_NAME, _, SWING_ICON = GetSpellInfo(260421)

local data = {}
Abstract.data = data

local petToPlayer = {} -- petGUID -> playerName
local unitToPet = {} -- petUnitId -> petGUID

local InitAuraData, UpdateAuraData, UpdateAuraAfterCombat
-------------------------------------------------
-- init segment
-------------------------------------------------
local inCombat -- group in combat
local current, last
local function InitCurrentSegmentData(segmentName, isBossEncounter)
    inCombat = true
    if not current then
        current = {
            ["segment"] = segmentName,
            ["start"] = time(),
            ["type"] = isBossEncounter and "boss" or "trash",
            ["preciseDuration"] = GetTime(),
            ["friend-done"] = {
                ["group-damage"] = 0,
                -- ["group-dps"] = 0,
                ["damage"] = {},
                ["healing"] = {},
                ["debuff"] = {}, -- debuff self->self self->enemy
                ["buff"] = {}, -- buff self->self
            },
            ["friend-taken"] = {
                ["damage"] = {},
                ["healing"] = {},
            },
            ["spell-taken"] = {
                -- ["spell"] = {
                --     ["total"] = n,
                --     ["target"] = {
                --         ["player1"] = n,
                --     },
                -- },
            },
            ["enemy-done"] = {
                ["healing"] = {},
            },
            ["enemy-taken"] = {
                ["damage"] = {},
            },
            ["death"] = {},
            -- ["data-enemy"] = {
            --     ["damage"] = {},
            --     ["healing"] = {},
            -- },
        }

        --! init already applied auras
        for unit in F:IterateGroupMembers() do
            if UnitIsVisible(unit) then
                local player = GetUnitName(unit, true)
                -- init auras
                for index = 1, 40 do
                    local name, _, _, _, _, _, source, _, _, spellId = UnitBuff(unit, index)
                    if not name then break end
                    if source and UnitIsUnit(unit, source) and not AbstractDB["auraBlacklist"][spellId] then
                        InitAuraData("buff", player)
                        UpdateAuraData("buff", player, spellId, name, "SPELL_AURA_APPLIED", time())
                    end
                end
                for index = 1, 40 do
                    local name, _, _, _, _, _, source, _, _, spellId = UnitDebuff(unit, index)
                    if not name then break end
                    if not  not AbstractDB["auraBlacklist"][spellId] then
                        InitAuraData("debuff", player)
                        UpdateAuraData("debuff", player, spellId, name, "SPELL_AURA_APPLIED", time())
                    end
                end
            end
        end
        -- for source, at in pairs(auraTemps) do
        --     InitAuraData("buff", source)
        --     for spellId, spellName in pairs(at["buff"]) do
        --         UpdateAuraData("buff", source, spellId, spellName, "SPELL_AURA_APPLIED", time())
        --     end
        --     InitAuraData("debuff", source)
        --     for spellId, spellName in pairs(at["debuff"]) do
        --         UpdateAuraData("debuff", source, spellId, spellName, "SPELL_AURA_APPLIED", time())
        --     end
        -- end

        tinsert(data, current)
        current.index = #data
        Abstract.current = current
        Abstract:Fire("CombatStart", current)
    end
end

local function CheckCombat(escapeCheck)
    local isInCombat = false
    if not escapeCheck then
        for unit in F:IterateGroupMembers() do
            if UnitIsVisible(unit) and UnitAffectingCombat(unit) then
                isInCombat = true
                break
            end
        end
    end
    -- print("CheckCombat: ", isInCombat)
    
    if not isInCombat then
        inCombat = false
        Abstract:Fire("CombatEnd", current["type"])
        -- update segment data
        current["end"] = time()
        current["preciseDuration"] = tonumber(string.format("%.3f", GetTime() - current["preciseDuration"]))
        -- update aura data
        UpdateAuraAfterCombat("buff")
        UpdateAuraAfterCombat("debuff")
        -- clear "Creature" pets
        for guid, _ in pairs(petToPlayer) do
            if string.find(guid, "^C") then
                petToPlayer[guid] = nil
            end
        end
        -- reset
        last = current
        current = nil
    end
end

local segment = CreateFrame("Frame")
segment:RegisterEvent("ENCOUNTER_START")
segment:RegisterEvent("ENCOUNTER_END")
segment:RegisterEvent("UNIT_FLAGS")
segment:RegisterEvent("PLAYER_REGEN_ENABLED")

local wipeCounter = {}
segment:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4, arg5)
    if event == "UNIT_FLAGS" then
        if F:IsGroupUnit(arg1) and inCombat then
            CheckCombat()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if inCombat then
            CheckCombat()
        end
    elseif event == "ENCOUNTER_START" then
        -- local encounterID, encounterName = arg1, arg2
        -- print("ENCOUNTER_START", arg1, arg2)
        if current then
            current["segment"] = arg2
            current["type"] = "boss"
        else
            InitCurrentSegmentData(arg2, true)
        end
    elseif event == "ENCOUNTER_END" then
        if inCombat then
            -- encounterID, encounterName, difficultyID, groupSize, success
            -- print("ENCOUNTER_END", arg1, arg2, arg3, arg4, arg5)
            inCombat = false
            CheckCombat(true)
            if last and last["segment"] == arg2 then
                last["success"] = arg5 == 1
                if arg5 == 0 then -- wipe
                    wipeCounter[arg1] = (wipeCounter[arg1] or 0) + 1
                    last["segment"] = arg2.." #"..wipeCounter[arg1]
                else
                    wipeCounter[arg1] = nil
                end
            end
        end
    end
end)

-------------------------------------------------
-- merge
-------------------------------------------------
local startIndex, lastIndex = 1
local function Merge(type)
    lastIndex = #data
    if lastIndex-1 <= startIndex then return end

    if data[startIndex]["type"] == "trash" and data[startIndex+1]["type"] == "trash" then
        -- F:Merge(data, startIndex, startIndex+1)
    end
    -- delete & update
    data[startIndex+1] = data[lastIndex]
    data[startIndex+1]["index"] = startIndex+1
    data[lastIndex] = nil
    
    if type == "boss" then
        startIndex = lastIndex + 1
    end
end
-- Abstract:RegisterCallback("CombatEnd", "Merger_CombatEnd", Merge)

-------------------------------------------------
-- pet owner
-------------------------------------------------
local petOwnerFinder = CreateFrame("GameTooltip", "AbstractPetOwnerFinder", nil, "GameTooltipTemplate")
local function FindPetOwner(petGUID)
    petOwnerFinder:SetOwner (WorldFrame, "ANCHOR_NONE")
    petOwnerFinder:SetHyperlink("unit:" .. petGUID)
    local text = _G["AbstractPetOwnerFinderTextLeft2"] and _G["AbstractPetOwnerFinderTextLeft2"]:GetText()
    if text and text ~= "" then
        for unit in F:IterateGroupMembers() do
            local pName = GetUnitName(unit)
            if string.find(_G["AbstractPetOwnerFinderTextLeft2"]:GetText(), pName) then
                return pName
            end
        end
    end
end

-------------------------------------------------
-- init data
-------------------------------------------------
local function InitDamageData(dataType, name)
    if not current[dataType]["damage"][name] then
        if dataType == "friend-done" then
            current[dataType]["damage"][name] = { -- sourceName
                ["total"] = 0,
                ["target"] = {},
                ["spell"] = {},
            }

        elseif dataType == "friend-taken" then
            current[dataType]["damage"][name] = { -- destName
                ["total"] = 0,
                ["source"] = {},
                ["spell"] = {},
            }

        elseif dataType == "enemy-taken" then
            current[dataType]["damage"][name] = { -- destName
                ["total"] = 0,
                ["source"] = {},
            }
        end
    end
end

local function InitHealingData(dataType, name)
    if not current[dataType]["healing"][name] then
        if dataType == "friend-done" then
            current[dataType]["healing"][name] = { -- sourceName
                ["total"] = 0,
                ["overhealing"] = 0,
                ["target"] = {},
                ["spell"] = {},
            }

        elseif dataType == "friend-taken" then
            current[dataType]["healing"][name] = { -- destName
                ["total"] = 0,
                ["source"] = {},
            }

        elseif dataType == "enemy-done" then
            current[dataType]["healing"][name] = { -- destName
                ["total"] = 0,
                ["target"] = {},
                ["spell"] = {},
            }
        end
    end
end

InitAuraData = function(auraType, sourceName)
    if not current["friend-done"][auraType][sourceName] then
        current["friend-done"][auraType][sourceName] = {}
    end
end

-------------------------------------------------
-- update damage data
-------------------------------------------------
local function UpdateDamageDone(dataType, sourceName, destName, spellId, spellName, amount, overkill, absorbed, isCritical, missType)
    -- init
    if not current[dataType]["damage"][sourceName]["spell"][spellId] then
        if tonumber(spellId) and not AbstractDB["iconsCache"][spellId] then AbstractDB["iconsCache"][spellId] = select(3, GetSpellInfo(spellId)) end
        current[dataType]["damage"][sourceName]["spell"][spellId] = {
            ["hit"] = 0,
            ["amount"] = 0,
            ["critical"] = 0,
            ["absorbed"] = 0,
            ["name"] = spellName,
            ["icon"] = string.find(spellId, "swing") and SWING_ICON or AbstractDB["iconsCache"][spellId],
            ["target"] = {},
        }
    end
    
    -- hit
    current[dataType]["damage"][sourceName]["spell"][spellId]["hit"] = current[dataType]["damage"][sourceName]["spell"][spellId]["hit"] + 1
    
    -- min, max
    current[dataType]["damage"][sourceName]["spell"][spellId]["max"] = math.max(current[dataType]["damage"][sourceName]["spell"][spellId]["max"] or amount, amount)
    current[dataType]["damage"][sourceName]["spell"][spellId]["min"] = math.min(current[dataType]["damage"][sourceName]["spell"][spellId]["min"] or amount, amount)

    -- amount
    if overkill and overkill ~= -1 then
       amount = amount - overkill
    end

    -- absorbed
    if absorbed then
        current[dataType]["damage"][sourceName]["spell"][spellId]["absorbed"] = current[dataType]["damage"][sourceName]["spell"][spellId]["absorbed"] + absorbed
        amount = amount + absorbed
    end

    current[dataType]["damage"][sourceName]["total"] = current[dataType]["damage"][sourceName]["total"] + amount
    current[dataType]["damage"][sourceName]["spell"][spellId]["amount"] = current[dataType]["damage"][sourceName]["spell"][spellId]["amount"] + amount
    if destName then
        current[dataType]["damage"][sourceName]["target"][destName] = (current[dataType]["damage"][sourceName]["target"][destName] or 0) + amount
        current[dataType]["damage"][sourceName]["spell"][spellId]["target"][destName] = (current[dataType]["damage"][sourceName]["spell"][spellId]["target"][destName] or 0) + amount
    end
    
    -- critical
    if isCritical then
        current[dataType]["damage"][sourceName]["spell"][spellId]["critical"] = current[dataType]["damage"][sourceName]["spell"][spellId]["critical"] + 1
    end

    -- update group damage
    if dataType == "friend-done" then
        current[dataType]["group-damage"] = current[dataType]["group-damage"] + amount
    end
end

local function UpdateDamageTaken(dataType, sourceName, destName, spellId, spellName, amount, overkill, absorbed)
    -- NOTE: 不记录敌方受到技能伤害
    -- amount
    if overkill and overkill ~= -1 then
        amount = amount - overkill
    end
    if absorbed then amount = amount + absorbed end

    current[dataType]["damage"][destName]["total"] = current[dataType]["damage"][destName]["total"] + amount
    if destName then
        if not sourceName then sourceName = ENVIRONMENTAL_DAMAGE end
        current[dataType]["damage"][destName]["source"][sourceName] = (current[dataType]["damage"][destName]["source"][sourceName] or 0) + amount
    end

    if dataType == "friend-taken" then
        -- init friend-taken-spell
        if not current[dataType]["damage"][destName]["spell"][spellId] then
            if tonumber(spellId) and not AbstractDB["iconsCache"][spellId] then AbstractDB["iconsCache"][spellId] = select(3, GetSpellInfo(spellId)) end
            current[dataType]["damage"][destName]["spell"][spellId] = {
                ["amount"] = 0,
                ["name"] = spellName,
                ["icon"] = string.find(spellId, "swing") and SWING_ICON or AbstractDB["iconsCache"][spellId],
            }
        end
        current[dataType]["damage"][destName]["spell"][spellId]["amount"] = current[dataType]["damage"][destName]["spell"][spellId]["amount"] + amount

        -- init spell-taken
        if not current["spell-taken"][spellId] then
            current["spell-taken"][spellId] = {
                ["name"] = spellName,
                ["icon"] = AbstractDB["iconsCache"][spellId],
                ["total"] = 0,
                ["target"] = {},
            }
        end
        current["spell-taken"][spellId]["total"] = current["spell-taken"][spellId]["total"] + amount
        current["spell-taken"][spellId]["target"][destName] = (current["spell-taken"][spellId]["target"][destName] or 0) + amount
    end
end

local function UpdateDamageData(func, dataType, ...)
    local _, event, _, sourceGUID, sourceName, _, _, _, destName = ...

    if event == "SPELL_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or event == "RANGE_DAMAGE" or event == "DAMAGE_SHIELD" then
        local spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical = select(12, ...)
        if petToPlayer[sourceGUID] then
            spellName = spellName.." ("..sourceName..")"
            sourceName = petToPlayer[sourceGUID]
        end
        func(dataType, sourceName, destName, spellId, spellName, amount, overkill, absorbed, critical)

    elseif event == "SWING_DAMAGE" then
        local amount, overkill, school, resisted, blocked, absorbed, critical = select(12, ...)
        if petToPlayer[sourceGUID] then
            func(dataType, petToPlayer[sourceGUID], destName, "swing-"..sourceName, SWING_NAME.." ("..sourceName..")", amount, overkill, absorbed, critical)
        else
            func(dataType, sourceName, destName, "swing", SWING_NAME, amount, overkill, absorbed, critical)
        end

    elseif event == "SPELL_MISSED" or event == "RANGE_MISSED" or event == "SPELL_PERIODIC_MISSED" then
        local spellId, spellName, spellSchool, missType, isOffHand, amountMissed, critical = select(12, ...)
        if missType == "ABSORB" then
            if petToPlayer[sourceGUID] then
                spellName = spellName.." ("..sourceName..")"
                sourceName = petToPlayer[sourceGUID]
            end
            func(dataType, sourceName, destName, spellId, spellName, 0, nil, amountMissed, critical)
        end

    elseif event == "SWING_MISSED" then
        local missType, isOffHand, amountMissed, critical = select(12, ...)
        if missType == "ABSORB" then
            if petToPlayer[sourceGUID] then
                func(dataType, petToPlayer[sourceGUID], "swing-"..sourceName, SWING_NAME.." ("..sourceName..")", 0, nil, amountMissed, critical)
            else
                func(dataType, sourceName, destName, "swing", SWING_NAME, 0, nil, amountMissed, critical)
            end
        end
    end
end

-------------------------------------------------
-- update healing data
-------------------------------------------------
local function UpdateHealingDone(dataType, sourceName, destName, spellId, spellName, amount, overhealing, absorbed, isCritical)
    -- init
    if not current[dataType]["healing"][sourceName]["spell"][spellId] then
        if not AbstractDB["iconsCache"][spellId] then AbstractDB["iconsCache"][spellId] = select(3, GetSpellInfo(spellId)) end
        current[dataType]["healing"][sourceName]["spell"][spellId] = {
            ["hit"] = 0,
            ["critical"] = 0,
            ["amount"] = 0,
            ["absorbed"] = 0,
            ["overhealing"] = 0,
            ["name"] = spellName,
            ["icon"] = AbstractDB["iconsCache"][spellId],
            ["target"] = {},
        }
    end
    
    -- hit
    current[dataType]["healing"][sourceName]["spell"][spellId]["hit"] = current[dataType]["healing"][sourceName]["spell"][spellId]["hit"] + 1
    
    -- absorbed
    if absorbed then
        current[dataType]["healing"][sourceName]["spell"][spellId]["absorbed"] = current[dataType]["healing"][sourceName]["spell"][spellId]["absorbed"] + absorbed
        amount = amount + absorbed
    end

    -- min, max
    current[dataType]["healing"][sourceName]["spell"][spellId]["max"] = math.max(current[dataType]["healing"][sourceName]["spell"][spellId]["max"] or amount, amount)
    current[dataType]["healing"][sourceName]["spell"][spellId]["min"] = math.min(current[dataType]["healing"][sourceName]["spell"][spellId]["min"] or amount, amount)

    -- amount
    if overhealing then
        amount = amount - overhealing
        current[dataType]["healing"][sourceName]["overhealing"] = current[dataType]["healing"][sourceName]["overhealing"] + overhealing
        current[dataType]["healing"][sourceName]["spell"][spellId]["overhealing"] = current[dataType]["healing"][sourceName]["spell"][spellId]["overhealing"] + overhealing
    end

    current[dataType]["healing"][sourceName]["total"] = current[dataType]["healing"][sourceName]["total"] + amount
    current[dataType]["healing"][sourceName]["spell"][spellId]["amount"] = current[dataType]["healing"][sourceName]["spell"][spellId]["amount"] + amount
    if destName then
        current[dataType]["healing"][sourceName]["target"][destName] = (current[dataType]["healing"][sourceName]["target"][destName] or 0) + amount
        current[dataType]["healing"][sourceName]["spell"][spellId]["target"][destName] = (current[dataType]["healing"][sourceName]["spell"][spellId]["target"][destName] or 0) + amount
    end
    
    -- critical
    if isCritical then
        current[dataType]["healing"][sourceName]["spell"][spellId]["critical"] = current[dataType]["healing"][sourceName]["spell"][spellId]["critical"] + 1
    end
end

local function UpdateHealingTaken(dataType, sourceName, destName, spellId, spellName, amount, overhealing, absorbed)
    -- amount
    if overhealing then amount = amount - overhealing end
    if absorbed then amount = amount + absorbed end

    current[dataType]["healing"][destName]["total"] = current[dataType]["healing"][destName]["total"] + amount
    if destName then
        current[dataType]["healing"][destName]["source"][sourceName] = (current[dataType]["healing"][destName]["source"][sourceName] or 0) + amount
    end
end

local function UpdateHealingData(func, dataType, ...)
    local _, event, _, sourceGUID, sourceName, _, _, _, destName = ...
    if event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then
        local spellId, spellName, spellSchool, amount, overhealing, absorbed, critical = select(12, ...)
        if petToPlayer[sourceGUID] then
            spellName = spellName.." ("..sourceName..")"
            sourceName = petToPlayer[sourceGUID]
        end
        func(dataType, sourceName, destName, spellId, spellName, amount, overhealing, absorbed, critical)
    
    elseif event == "SPELL_HEAL_ABSORBED" or event == "SPELL_PERIODIC_HEAL_ABSORBED" then
        -- TODO:
        print(event, select(12, ...))
        -- extraGUID, extraName, extraFlags, extraRaidFlags, extraSpellID, extraSpellName, extraSchool, amount
        -- local spellId, spellName, spellSchool, amount, overhealing, absorbed, critical = select(12, ...)
    
    elseif event == "SPELL_ABSORBED" then
        -- NOTE: critical 是由吸收此次的伤害技能是否爆击决定的，而不是盾是否爆击
        -- timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, [spellID, spellName, spellSchool], casterGUID, casterName, casterFlags, casterRaidFlags, absorbSpellId, absorbSpellName, absorbSpellSchool, amount, critical
        local arg12 = select(12, ...)
        local casterGUID, casterName, casterFlags, casterRaidFlags, absorbSpellId, absorbSpellName, absorbSpellSchool, amount, critical
        if type(arg12) == "number" then -- SPELL_MISSED
            casterGUID, casterName, casterFlags, casterRaidFlags, absorbSpellId, absorbSpellName, absorbSpellSchool, amount, critical = select(15, ...)
        else -- SWING_MISSED
            casterGUID, casterName, casterFlags, casterRaidFlags, absorbSpellId, absorbSpellName, absorbSpellSchool, amount, critical = select(12, ...)
        end
        if petToPlayer[sourceGUID] then
            absorbSpellName = absorbSpellName.." ("..casterName..")"
            casterName = petToPlayer[sourceGUID]
        end
        func(dataType, casterName, destName, absorbSpellId, absorbSpellName, amount, nil, nil, critical)
    end
end

-------------------------------------------------
-- update aura data
-------------------------------------------------
UpdateAuraData = function(auraType, sourceName, spellId, spellName, event, timestamp)
    -- init
    if not current["friend-done"][auraType][sourceName][spellId] then
        if not AbstractDB["iconsCache"][spellId] then AbstractDB["iconsCache"][spellId] = select(3, GetSpellInfo(spellId)) end
        current["friend-done"][auraType][sourceName][spellId] = {
            ["uptime"] = 0,
            ["applied"] = 0,
            ["refreshed"] = 0,
            ["removed"] = 0,
            -- ["temp-uptime"] = 0,
            -- ["start"] = startTime,
            ["name"] = spellName,
            ["icon"] = AbstractDB["iconsCache"][spellId],
        }
    end


    if event == "SPELL_AURA_APPLIED" then
        current["friend-done"][auraType][sourceName][spellId]["applied"] = current["friend-done"][auraType][sourceName][spellId]["applied"] + 1
        if not current["friend-done"][auraType][sourceName][spellId]["start"] then current["friend-done"][auraType][sourceName][spellId]["start"] = timestamp end
        
    elseif event == "SPELL_AURA_REFRESH" then
        current["friend-done"][auraType][sourceName][spellId]["refreshed"] = current["friend-done"][auraType][sourceName][spellId]["refreshed"] + 1
        
    else -- SPELL_AURA_REMOVED
        current["friend-done"][auraType][sourceName][spellId]["removed"] = current["friend-done"][auraType][sourceName][spellId]["removed"] + 1

        if current["friend-done"][auraType][sourceName][spellId]["start"] then
            current["friend-done"][auraType][sourceName][spellId]["temp-uptime"] = timestamp - current["friend-done"][auraType][sourceName][spellId]["start"]
        else
            -- already applied before combat
            current["friend-done"][auraType][sourceName][spellId]["temp-uptime"] = timestamp - current["start"]
        end

        if current["friend-done"][auraType][sourceName][spellId]["applied"] == current["friend-done"][auraType][sourceName][spellId]["removed"] then -- all removed
            current["friend-done"][auraType][sourceName][spellId]["start"] = nil
            current["friend-done"][auraType][sourceName][spellId]["uptime"] = current["friend-done"][auraType][sourceName][spellId]["uptime"] + current["friend-done"][auraType][sourceName][spellId]["temp-uptime"]
        end
    end
end

UpdateAuraAfterCombat = function(auraType)
    for sourceName, spells in pairs(current["friend-done"][auraType]) do
        for s, st in pairs(spells) do
            if st["applied"] ~= st["removed"] then
                -- NOTE: debuff于战斗结束后仍存在，未记录到消失时间，以战斗结束时间为准。 这种情况存在于木桩。
                -- aura 的开始时间可能记录不到，cleu:AURA可能发生在其他事件之前，而此时还没有被标记为inCombat。
                st["uptime"] = st["uptime"] + (current["end"] - (st["start"] or current["start"]))
            end
            st["removed"] = nil
            st["temp-uptime"] = nil
            st["start"] = nil
        end
    end
end

-------------------------------------------------
-- COMBAT_LOG_EVENT_UNFILTERED
-------------------------------------------------
local cleu = CreateFrame("Frame")
cleu:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
cleu:SetScript("OnEvent", function()
    -- print(CombatLogGetCurrentEventInfo())
    cleu:PET(CombatLogGetCurrentEventInfo())
    cleu:DAMAGE(CombatLogGetCurrentEventInfo())
    cleu:HEALING(CombatLogGetCurrentEventInfo())
    cleu:AURA(CombatLogGetCurrentEventInfo())
end)

function cleu:PET(...)
    local timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = ...
    if event == "SPELL_SUMMON" then
        -- print(event, sourceName, destGUID, destName)
        petToPlayer[destGUID] = sourceName
    -- elseif event == "SPELL_CREATE" then
    --     print(...)
    end
end

function cleu:DAMAGE(...)
    local timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = ...
    -- print(event, sourceName, destName)
    if not (string.match(event, "DAMAGE") or string.match(event, "MISSED")) then return end
    if not inCombat and string.match(event, "SPELL_PERIODIC") then return end

    --! friend-done
    if F:IsFriend(sourceFlags) then
        if string.find(sourceGUID, "^C") and not petToPlayer[sourceGUID] then -- Creature
            local owner = FindPetOwner(sourceGUID)
            if owner then
                petToPlayer[sourceGUID] = owner
                sourceName = owner
            end
        else
            sourceName = petToPlayer[sourceGUID] or sourceName
        end
        InitCurrentSegmentData(destName)
        InitDamageData("friend-done", sourceName)
        UpdateDamageData(UpdateDamageDone, "friend-done", ...)
    end
        
    --! enemy-done
    if F:IsEnemy(sourceFlags) and F:IsFriend(destFlags) then
        InitCurrentSegmentData(sourceName)
    end

    --! friend-taken
    if F:IsFriend(destFlags) and inCombat then
        InitDamageData("friend-taken", destName)
        UpdateDamageData(UpdateDamageTaken, "friend-taken", ...)
    end

    --! enemy-taken
    if F:IsEnemy(destFlags) and inCombat and (F:IsFriend(sourceFlags) or F:IsEnemy(sourceFlags)) then
        InitDamageData("enemy-taken", destName)
        UpdateDamageData(UpdateDamageTaken, "enemy-taken", ...)
    end
end

function cleu:HEALING(...)
    local timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = ...
    -- print(event, sourceName, destName)
    -- if not (string.match(event, "HEAL") or event == "SPELL_ABSORBED") then return end
    if not inCombat then return end

    if string.match(event, "HEAL") then
        --! friend-done
        if F:IsFriend(sourceFlags) then
            if string.find(sourceGUID, "^C") and not petToPlayer[sourceGUID] then -- Creature
                local owner = FindPetOwner(sourceGUID)
                if owner then
                    petToPlayer[sourceGUID] = owner
                    sourceName = owner
                end
            else
                sourceName = petToPlayer[sourceGUID] or sourceName
            end
            InitHealingData("friend-done", sourceName)
            UpdateHealingData(UpdateHealingDone, "friend-done", ...)
        end

        --! friend-taken
        if F:IsFriend(destFlags) then
            InitHealingData("friend-taken", destName)
            UpdateHealingData(UpdateHealingTaken, "friend-taken", ...)
        end

        --! enemy-done
        if F:IsEnemy(sourceFlags) and F:IsEnemy(destFlags) then
            InitHealingData("enemy-done", sourceName)
            UpdateHealingData(UpdateHealingDone, "enemy-done", ...)
        end

    elseif event == "SPELL_ABSORBED" then
        -- timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, [spellID, spellName, spellSchool], casterGUID, casterName, casterFlags, casterRaidFlags, absorbSpellId, absorbSpellName, absorbSpellSchool, amount, critical
        local casterGUID, casterName, casterFlags = select(12, ...)
        if type(casterGUID) == "number" then -- SPELL_MISSED
            casterGUID, casterName, casterFlags = select(15, ...)
        end
        --! friend-done
        if F:IsFriend(casterFlags) then
            if petToPlayer[casterGUID] then
                casterName = petToPlayer[casterGUID]
            end
            InitHealingData("friend-done", casterName)
            UpdateHealingData(UpdateHealingDone, "friend-done", ...)
        end

        --! friend-taken
        if F:IsFriend(destFlags) then
            InitHealingData("friend-taken", destName)
            UpdateHealingData(UpdateHealingTaken, "friend-taken", ...)
        end
        
        --! enemy-done
        if F:IsEnemy(casterFlags) and F:IsEnemy(destFlags) then
            InitHealingData("enemy-done", casterName)
            UpdateHealingData(UpdateHealingDone, "enemy-done", ...)
        end
    end
end

function cleu:AURA(...)
    local timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags  = ...
    if not (event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REMOVED" or event == "SPELL_AURA_REFRESH") then return end
    
    local spellId, spellName, spellSchool, auraType, amount = select(12, ...)
    -- print(event, sourceName, destName, spellId, spellName, spellSchool, auraType)

    if not inCombat then
        --! keep track of auras before combat
        -- if F:IsFriend(sourceFlags) and sourceGUID == destGUID then
        --     if not auraTemps[sourceName] then auraTemps[sourceName] = {["buff"]={}, ["debuff"]={}} end
        --     if event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" then
        --         auraTemps[sourceName][strlower(auraType)][spellId] = spellName
        --     else
        --         auraTemps[sourceName][strlower(auraType)][spellId] = nil
        --     end
        -- end
        return
    end

    if AbstractDB["auraBlacklist"][spellId] then return end

    --! debuff applied to an enemy by self
    if F:IsFriend(sourceFlags) and F:IsEnemy(destFlags) and auraType == "DEBUFF" then
        if petToPlayer[sourceGUID] then
            InitAuraData("debuff", petToPlayer[sourceGUID])
            UpdateAuraData("debuff", petToPlayer[sourceGUID], spellId, spellName.." ("..sourceName..")", event, timestamp)
        else
            InitAuraData("debuff", sourceName)
            UpdateAuraData("debuff", sourceName, spellId, spellName, event, timestamp)
        end
    end
    
    --! buff/debuff self-applied
    if F:IsFriend(sourceFlags) and sourceGUID == destGUID then
        InitAuraData(strlower(auraType), sourceName)
        UpdateAuraData(strlower(auraType), sourceName, spellId, spellName, event, timestamp)
    end
end

-------------------------------------------------
-- other events
-------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_PET")

function f:PLAYER_LOGIN()
    for unit in F:IterateGroupMembers() do
        f:UNIT_PET(unit)
    end
    -- texplore(petToPlayer)
end

function f:PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
    if not (isInitialLogin or isReloadingUi) then
        wipe(petToPlayer)
        wipe(unitToPet)
        for unit in F:IterateGroupMembers() do
            f:UNIT_PET(unit)
        end
    end
end

function f:UNIT_PET(unit)
    -- print("UNIT_PET", unit)
    -- init petToPlayer
    local player = GetUnitName(unit, true)
    
    if unit == "player" then
        unit = "pet"
    else
        unit = string.gsub(unit, "party", "partypet")
        unit = string.gsub(unit, "raid", "raidpet")
    end
    
    local petGUID = UnitGUID(unit)
    if UnitExists(unit) then
        petToPlayer[petGUID] = player
        unitToPet[unit] = petGUID
    elseif unitToPet[unit] then
        petToPlayer[unitToPet[unit]] = nil
    end
end

f:SetScript("OnEvent", function(self, event, ...)
    self[event](self, ...)
end)