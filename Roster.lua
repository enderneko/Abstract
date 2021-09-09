local _, Abstract = ...
local L = Abstract.L
local F = Abstract.funcs

local roster = CreateFrame("Frame")
local LGIST = LibStub:GetLibrary("LibGroupInSpecT-1.1")

function roster:UnitUpdate(event, guid, unit, info)
    -- print(event, guid, unit, info.global_spec_id)
    -- texplore(info)
    
end
LGIST.RegisterCallback(roster, "GroupInSpecT_Update", "UnitUpdate") 

function F:GetUnitInfoByName(name)
    
end