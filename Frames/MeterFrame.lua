local _, Abstract = ...
local L = Abstract.L
local F = Abstract.funcs
local P = Abstract.pixelPerfectFuncs

local mainFrame = CreateFrame("Frame", "AbstractMainFrame", UIParent)
Abstract.frames.mainFrame = mainFrame
mainFrame:SetIgnoreParentScale(true)
mainFrame:SetFrameStrata("LOW")
-- mainFrame:SetSize(100, 100)
-- mainFrame:SetPoint("CENTER")

-- local text = mainFrame:CreateFontString(nil, "OVERLAY", "ABSTRACT_FONT_WIDGET")
-- text:SetPoint("CENTER", UIParent)

local function CombatStart(data)
    F:Debug("|cff22ff22CombatStart|r", data["segment"], data["preciseDuration"])
    Abstract.frames.meterFrames[1]:CombatStart()
end
Abstract:RegisterCallback("CombatStart", "MeterFrame_CombatStart", CombatStart)

local function CombatEnd()
    F:Debug("|cffff2222CombatEnd|r")
    Abstract.frames.meterFrames[1]:CombatEnd()
end
Abstract:RegisterCallback("CombatEnd", "MeterFrame_CombatEnd", CombatEnd)

-------------------------------------------------
-- meter frames
-------------------------------------------------
local function SetDraggerForFrame(dragger, frame)
    dragger:RegisterForDrag("LeftButton")
    dragger:SetScript("OnDragStart", function()
        frame:StartMoving()
        frame:SetUserPlaced(false)
    end)
    dragger:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        P:SavePosition(frame, frame.position)
    end)
end

local indices = {
    ["damage-done"] = {"friend-done", "damage"},
}

Abstract.frames.meterFrames = {}
function F:CreateMeterFrame(i, t)
    local m = CreateFrame("Frame", "AbstractMeterFrame"..i, mainFrame, "BackdropTemplate")
    Abstract.frames.meterFrames[i] = m
    Abstract:StylizeFrame(m, {0.1, 0.1, 0.1, 0.5})

    -- size & position
    m:SetClampedToScreen(true)
    P:Size(m, t["width"], t["height"])
    m:SetPoint("BOTTOM", UIParent, 0, 300)
    P:LoadPosition(m, t["position"])
    m.position = t["position"]

    -- mover
    m:EnableMouse(true)
    m:SetMovable(true)
    SetDraggerForFrame(m, m)

    -- title
    local title = m:CreateFontString(nil, "OVERLAY", "ABSTRACT_FONT_WIDGET")
    title:SetPoint("TOPLEFT")
    m.default = t.default
    m.current = t.default
    title:SetText(L[m.default])

    -- scroll
    local dataArea = CreateFrame("Frame", "AbstractMeterFrame"..i.."DataArea", m, "BackdropTemplate")
    dataArea:SetPoint("TOPLEFT", 1, -16)
    dataArea:SetPoint("BOTTOMRIGHT", -1, 1)
    Abstract:StylizeFrame(dataArea, {0,1,0,0.1}, {0,0,0,0})
    local chart = Abstract:CreateScrollChart(dataArea)

    function m:ShowData(data, which)
        which = which or m.default
        m.current = which
        title:SetText(L[which])
        
        local i1, i2, func = indices[which][1], indices[which][2]

        if string.find(which, "done") or string.find(which, "taken") then
            func = chart.ShowData_DH
        end
        
        if not data["end"] then
            local timeElapsed = 0
            chart:SetScript("OnUpdate", function(self, elapsed)
                timeElapsed = timeElapsed + elapsed
                if timeElapsed >= 0.2 then
                    timeElapsed = 0
                    func(chart, data[i1][i2], GetTime() - data["preciseDuration"])
                end
            end)
        else
            chart:SetScript("OnUpdate", nil)
            func(chart, data[i1][i2], data["preciseDuration"])
        end
    end

    function m:CombatStart()
        m:ShowData(Abstract.current, m.default)
    end

    function m:CombatEnd()
        C_Timer.After(.2, function()
            m:ShowData(Abstract.current, m.current)
        end)
    end
end