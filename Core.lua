local addonName, Abstract = ...
_G.Abstract = Abstract
Abstract.frames = {}
Abstract.vars = {}
Abstract.funcs = {}

local F = Abstract.funcs
local P = Abstract.pixelPerfectFuncs

--@debug@
local debugMode = true
--@end-debug@
function F:Debug(arg, ...)
    if debugMode then
        if type(arg) == "string" or type(arg) == "number" then
            print(arg, ...)
        elseif type(arg) == "function" then
            arg(...)
        elseif arg == nil then
            return true
        end
    end
end

-------------------------------------------------
-- events
-------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

function eventFrame:ADDON_LOADED(arg1)
    if arg1 == addonName then
        eventFrame:UnregisterEvent("ADDON_LOADED")
        
        if type(AbstractDB) ~= "table" then AbstractDB = {} end
        
        if type(AbstractDB["iconsCache"]) ~= "table" then AbstractDB["iconsCache"] = {} end
        
        if type(AbstractDB["auraBlacklist"]) ~= "table" then
            AbstractDB["auraBlacklist"] = {
                [186406] = true, -- 动物印记
            }
        end
        
        if type(AbstractDB["appearance"]) ~= "table" then
            AbstractDB["appearance"] = {
                ["scale"] = 1,
            }
        end
        P:SetRelativeScale(AbstractDB["appearance"]["scale"])
        P:SetEffectiveScale(Abstract.frames.mainFrame)

        if type(AbstractDB["meters"]) ~= "table" then
            AbstractDB["meters"] = {
                {
                    ["width"] = 300,
                    ["height"] = 200,
                    ["position"] = {},
                    ["default"] = "damage-done",
                },
            }
        end

        for i, t in pairs(AbstractDB["meters"]) do
            F:CreateMeterFrame(i, t)
        end
    end
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    self[event](self, ...)
end)