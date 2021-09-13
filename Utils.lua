local _, Abstract = ...
local F = Abstract.funcs

local IsInRaid = IsInRaid
local GetNumGroupMembers = GetNumGroupMembers

-- https://wowpedia.fandom.com/wiki/UnitFlag
local OBJECT_AFFILIATION_MINE = 0x00000001
local OBJECT_AFFILIATION_PARTY = 0x00000002
local OBJECT_AFFILIATION_RAID = 0x00000004
local OBJECT_REACTION_HOSTILE = 0x00000040
local OBJECT_REACTION_NEUTRAL = 0x00000020

function F:IsFriend(unitFlags)
    if not unitFlags then return false end
    return (bit.band(unitFlags, OBJECT_AFFILIATION_MINE) ~= 0) or (bit.band(unitFlags, OBJECT_AFFILIATION_RAID) ~= 0) or (bit.band(unitFlags, OBJECT_AFFILIATION_PARTY) ~= 0)
end

function F:IsEnemy(unitFlags)
    if not unitFlags then return false end
    return (bit.band(unitFlags, OBJECT_REACTION_HOSTILE) ~= 0) or (bit.band(unitFlags, OBJECT_REACTION_NEUTRAL) ~= 0)
end

function F:IsSelf(unitFlags)
    if not unitFlags then return false end
    return bit.band(unitFlags, OBJECT_AFFILIATION_MINE) ~= 0
end

function F:IsGroupUnit(unit)
    return unit == "player" or string.match(unit, "party") or string.match(unit, "raid")
end

function F:IterateGroupMembers()
    local groupType = IsInRaid() and "raid" or "party"
    local numGroupMembers = GetNumGroupMembers()
    local i = groupType == "party" and 0 or 1

    return function()
        local ret
        if i == 0 and groupType == "party" then
            ret = "player"
        elseif i <= numGroupMembers and i > 0 then
            ret = groupType .. i
        end
        i = i + 1
        return ret
    end
end

function F:Sort(t, k1, order1, k2, order2, k3, order3)
    table.sort(t, function(a, b)
        if a[k1] ~= b[k1] then
            if order1 == "ascending" then
                return a[k1] < b[k1]
            else -- "descending"
                return a[k1] > b[k1]
            end
        elseif k2 and order2 and a[k2] ~= b[k2] then
            if order2 == "ascending" then
                return a[k2] < b[k2]
            else -- "descending"
                return a[k2] > b[k2]
            end
        elseif k3 and order3 and a[k3] ~= b[k3] then
            if order3 == "ascending" then
                return a[k3] < b[k3]
            else -- "descending"
                return a[k3] > b[k3]
            end
        end
    end)
end

-------------------------------------------------
-- number
-------------------------------------------------
local symbol_1K, symbol_10K, symbol_1B
if LOCALE_zhCN then
    symbol_1K, symbol_10K, symbol_1B = "千", "万", "亿"
elseif LOCALE_zhTW then
    symbol_1K, symbol_10K, symbol_1B = "千", "萬", "億"
elseif LOCALE_koKR then
    symbol_1K, symbol_10K, symbol_1B = "천", "만", "억"
end

if LOCALE_zhCN or LOCALE_zhTW or LOCALE_koKR then
    function F:FormatNumber(n)
        if abs(n) >= 100000000 then
            return string.format("%.3f"..symbol_1B, n/100000000)
        elseif abs(n) >= 10000 then
            return string.format("%.2f"..symbol_10K, n/10000)
        elseif abs(n) >= 1000 then
            return string.format("%.1f"..symbol_1K, n/1000)
        else
            return n
        end
    end
else
    function F:FormatNumber(n)
        if abs(n) >= 1000000000 then
            return string.format("%.3fB", n/1000000000)
        elseif abs(n) >= 1000000 then
            return string.format("%.2fM", n/1000000)
        elseif abs(n) >= 1000 then
            return string.format("%.1fK", n/1000)
        else
            return n
        end
    end
end