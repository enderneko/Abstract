-- self == L
-- rawset(t, key, value)
-- Sets the value associated with a key in a table without invoking any metamethods
-- t - A table (table)
-- key - A key in the table (cannot be nil) (value)
-- value - New value to set for the key (value)
select(2, ...).L = setmetatable({
    ["CHANGE LOGS"] = [[
        <h1>r59-release (Aug 7, 2021, 18:23 GMT+8)</h1>
        <p>* Implemented Copy Indicators.</p>
        <p>* Updated Layout Auto Switch.</p>
        <p>* Updated Raid Debuffs, Targeted Spells, Death Report.</p>
        <br/>
    ]],
}, {
    __index = function(self, Key)
        if (Key ~= nil) then
            rawset(self, Key, Key)
            return Key
        end
    end
})