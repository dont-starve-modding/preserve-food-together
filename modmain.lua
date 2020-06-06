-- debug

function DumpComponent( comp )
	for name,value in pairs(comp) do
		if type(value) == "function" then
			-- local info = debug.getinfo(value,"LnS")
			-- print(string.format("      %s = function - %s", name, info.source..":"..tostring(info.linedefined)))
		else
			if value and type(value) == "table" and value.IsValid and type(value.IsValid) == "function" then
			   print(string.format("      %s = %s (valid:%s)", name, tostring(value),tostring(value:IsValid())))
			else
		   		print(string.format("      %s = %s", name, tostring(value)))
			end
		end
	end
end

function DumpEntity(ent)
	print("============================================ Dumping entity ",ent,"============================================")
	print(ent.entity:GetDebugString())
	print("--------------------------------------------------------------------------------------------------------------------")
	for name,value in pairs(ent) do
		if type(value) == "function" then
			-- local info = debug.getinfo(value,"LnS")
			-- print(string.format("   %s = function - %s", name, info.source..":"..tostring(info.linedefined)))
		else
			if value and type(value) == "table" and value.IsValid and type(value.IsValid) == "function" then
			   print(string.format("   %s = %s (valid:%s)", name, tostring(value),tostring(value:IsValid())))
			else
			   print(string.format("   %s = %s", name, tostring(value)))
			end
		end
	end
	print("--------------------------------------------------------------------------------------------------------------------")
	for i,v in pairs(ent.components) do
		print("   Dumping component",i)
		DumpComponent(v)
	end
	print("====================================================================================================================================")
end

-- debug end

PrefabFiles = {
}

Assets = {
    Asset("SOUND", "sound/rabbit.fsb"),
    Asset("SOUND", "sound/mole.fsb")
}

STRINGS = GLOBAL.STRINGS

function TableMerge(t1, t2)
    for k,v in pairs(t2) do
        if type(v) == "table" then
            if type(t1[k] or false) == "table" then
                TableMerge(t1[k] or {}, t2[k] or {})
            else
                t1[k] = v
            end
        else
            t1[k] = v
        end
    end
    return t1
end

NEWSTRINGS = GLOBAL.require("preservefoodstrings")
GLOBAL.STRINGS = TableMerge(GLOBAL.STRINGS, NEWSTRINGS)

-- constants

TUNING.CHILL_DURATION = TUNING.TOTAL_DAY_TIME / 8
TUNING.STALE_MULT = 0.75
TUNING.SPOILED_MULT = 0.5
TUNING.WETNESS = 50

-- configuration

if (GetModConfigData("chill_duration") == "low") then
    TUNING.CHILL_DURATION = TUNING.TOTAL_DAY_TIME / 16
end
if (GetModConfigData("chill_duration") == "high") then
    TUNING.CHILL_DURATION = TUNING.TOTAL_DAY_TIME / 4
end

if (GetModConfigData("chill_wetness") == "low") then
    TUNING.CHILL_DURATION = 40
end
if (GetModConfigData("chill_wetness") == "high") then
    TUNING.CHILL_DURATION = 80
end

-- all ice prefabs have the chiller component
AddPrefabPostInit("ice", function(inst)
    inst:AddComponent("chiller")
end)

-- what to do, when chill duration is over
function startperishing(target)
    print("starting to perish again...")
    if target.components.perishable ~= nil then
        target.components.perishable:StartPerishing()

        if target.components.inventoryitem ~= nil then
            target.components.inventoryitem:AddMoisture(50)
        else
            print("target does not have inventoryitem component")
        end
    else
        print("target does not have perishable component")
    end
end

-- what to do when chilling starts
function chill(act)
    print("chilling...")

    if act.target.prefab == "rabbit" then
        act.target.SoundEmitter:PlaySound("dontstarve/rabbit/scream_short")

        return false
    end

    
    if act.target.prefab == "mole" then
        act.target.SoundEmitter:PlaySound("dontstarve/mole/emerge_voice")

        return false
    end

    if (not act.target:HasTag("fresh") 
        and not act.target:HasTag("stale") 
        and not act.target:HasTag("spoiled"))
        or act.target.components.chiller ~= nil
        or act.target.components.edible == nil 
            then
        return false
    end

    print("stopping to perish...")

    local stop_perish_duration = TUNING.CHILL_DURATION

    if act.target.components.perishable ~= nil then
        act.target.components.perishable:StopPerishing()

        if act.target.components.perishable:IsStale() then
            stop_perish_duration = stop_perish_duration * TUNING.STALE_MULT
        elseif act.target.components.perishable:IsSpoiled() then
            stop_perish_duration = stop_perish_duration * TUNING.SPOILED_MULT
        end

        act.target:DoTaskInTime(stop_perish_duration, startperishing, act.target)
    end

    act.invobject.components.stackable:Get(1):Remove()

    return true
end

-- new GLOBAL Action "CHILL"
AddAction('CHILL', 'Chill', chill)

-- Chilling takes some time
AddStategraphActionHandler('wilson_client', GLOBAL.ActionHandler(GLOBAL.ACTIONS.CHILL, "dolongaction"))
AddStategraphActionHandler('wilson', GLOBAL.ActionHandler(GLOBAL.ACTIONS.CHILL, "dolongaction"))

-- what to do when player is trying to use an item with chiller component
-- mostly a check whether to provide the CHILL action or not based hovered item
function chiller(inst, doer, target, actions, right)
    -- print("using item with component chiller on something " .. tostring(right))
    if right 
        and (target:HasTag("fresh") or target:HasTag("stale") or target:HasTag("spoiled")) then
        -- print("match!")
        table.insert(actions, GLOBAL.ACTIONS.CHILL)
    end
end

-- every prefab with the chiller component can be used in inventory
AddComponentAction("USEITEM", "chiller", chiller)


-- AddComponentPostInit("perishable", function(inst)
--     inst.

--     local fn = inst.StartPerishing
--     inst.StartPerishing = function()
        
--         fn()
--     end
-- end)

-- local function PerishablePostInit(self, inst)
--     self.interrupted_until = nil
--     self.interrupted_task = nil

--     print("postinit loaded")
--     local start_perishing = self.StartPerishing
--     self.StartPerishing = function ()
--         start_perishing()
--     end

--     local long_update = self.LongUpdate
--     self.LongUpdate = function (dt)

--         if self.interrupted_task ~= nil then
-- 			self.interrupted_task:Cancel()
-- 		end
-- 		if self.targettime - dt > GetTime() then
-- 			self.targettime = self.targettime - dt
-- 			self.interrupted_task = self.inst:DoTaskInTime(self.interrupted_until - GetTime(), startperishing, self)
-- 			dt = 0            
-- 		else
-- 			dt = dt - self.targettime + GetTime()
-- 			docompost(self.inst, self)
-- 		end

--         long_update(dt)
--     end

-- 	function self:SomeCoolFn()
-- 		print("SomeCoolFn fired")
--     end
    
-- 	inst:AddTag("chillable")
-- end
 
-- AddComponentPostInit("perishable", PerishablePostInit)