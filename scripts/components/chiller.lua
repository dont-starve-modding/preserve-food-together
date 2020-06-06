-- a component to mark items that can be used to chill stuff

local Chiller = Class(function(self, inst)
    self.inst = inst
end)

function Chiller:LongUpdate(dt)
    -- print("Chiller LongUpdate" .. dt)
end

return Chiller