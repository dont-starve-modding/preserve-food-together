-- a component to mark items that are chilled right now, which means that perishing is interrupted

local Chillable = Class(function(self, inst)
    self.inst = inst
    self.chilled_until = nil
    self.task = nil
end)

local function finish_chilling(inst)
    print("chillable: finish chilling...")
    if inst.components.perishable ~= nil then
        if inst.components.perishable ~= nil then
            inst.components.perishable:StartPerishing()
    
            if inst.components.inventoryitem ~= nil then
                local wetness = TUNING.WETNESS

                if inst.components.stackable then
                    -- TODO wetness = wetness / inst.components.stackable.stacksize
                end

                inst.components.inventoryitem:AddMoisture(wetness)
            else
                print("self.inst does not have inventoryitem component")
            end
        else
            print("self.inst does not have perishable component")
        end
    end

    inst.components.chillable:ResetChilledUntil()
end

function Chillable:GetChilledUntil()
    return self.chilled_until
end

function Chillable:ResetChilledUntil()
    self.chilled_until = nil
end

function Chillable:ChillUntil(chill_until)
    self.chilled_until = chill_until

    -- item specific modification action

    if self.inst.components.perishable ~= nil then
        print("chillable: :StopPerishing")
        self.inst.components.perishable:StopPerishing()
    end

    -----------------

    self:RestartTask()
end


function Chillable:Chill(duration)
    print("chillable: chill with " .. duration)
    if duration <= 0 then
        return
    end

    self:ChillUntil(GetTime() + duration)
end

function Chillable:Dilute(chill_until, number_added)
    if self.chilled_until == nil and chill_until == nil then
        print("chillable: Dilute nil nil")
        return
    end

    print("chillable: Dilute")

    local self_chilled_until = self.chilled_until or GetTime()
    local added_item_chilled_until = chill_until or GetTime()
    local stacksize = 1
    
    if self.inst.components.stackable ~= nil then
        stacksize = self.inst.components.stackable.stacksize
    end

    print("chillable: Dilute "..tostring(self_chilled_until).." "..tostring(stacksize)..
                " "..tostring(added_item_chilled_until).." "..tostring(number_added))
    self.chilled_until = (stacksize * self_chilled_until  + number_added * added_item_chilled_until) / 
        (stacksize + number_added)

    self:RestartTask()
end

function Chillable:OnSave()
    print("chillable: OnSave")
    return
    {
        chilled_until = self.chilled_until
    }
end

function Chillable:OnLoad(data)
    print("chillable: OnLoad")
    if data ~= nil then
		if data.chilled_until ~= nil then
            self.chilled_until = data.chilled_until
            
            self:RestartTask()
		end
    end
end

-- don't know, why this should happen, but whatever...
function Chillable:OnRemoveEntity()
    -- print("chillable: OnRemoveEntity")
    
    if self.task ~= nil then
        -- print("chillable: cancelling task")
        self.task:Cancel()
    end
end

function Chillable:LongUpdate(dt)
    print("chillable: LongUpdate" .. GetTime() .. dt)

    self:RestartTask(dt)
end


function Chillable:RestartTask(dt)
    print("chillable: RestartTask " .. tostring(dt))
    if dt == nil then
        dt = 0
    end

    if self.task ~= nil then
        print("chillable: cancelling task")
        self.task:Cancel()
    end

    if self.chilled_until ~= nil then
        if self.chilled_until - dt > GetTime() then
            self.chilled_until = self.chilled_until - dt
            print("chillable: starting DoTaskInTime with " .. (self.chilled_until - GetTime()))
            self.task = self.inst:DoTaskInTime(self.chilled_until - GetTime(), finish_chilling, self)
        else
            finish_chilling(self.inst)
        end
    end
end

return Chillable