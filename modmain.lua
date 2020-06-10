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
    Asset("SOUND", "sound/mole.fsb"),
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
    TUNING.WETNESS = 40
end
if (GetModConfigData("chill_wetness") == "high") then
    TUNING.WETNESS = 80
end

-- what to do when chilling starts
function chill(act)
    -- print("chilling...")
    -- DumpEntity(act.target)

    if act.target.prefab == "rabbit" then
        act.target.SoundEmitter:PlaySound("dontstarve/rabbit/scream_short")

        return false
    end

    if act.target.prefab == "mole" then
        act.target.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/mole/pickup")

        -- moles eat ice
        act.invobject.components.stackable:Get(1):Remove()

        return true
    end

    if act.target.components.perishable == nil
        or act.target.components.chiller ~= nil
        or (act.target.components.edible == nil 
            and act.target.prefab ~= "hambat")
        or act.target.components.chillable == nil
            then
        return false
    end

    print("starting to chill on chillable component...")

    local chill_duration = TUNING.CHILL_DURATION

    if act.invobject.components.perishable ~= nil then
        if act.invobject.components.perishable:IsStale() then
            chill_duration = chill_duration * TUNING.STALE_MULT
        elseif act.invobject.components.perishable:IsSpoiled() then
            chill_duration = chill_duration * TUNING.SPOILED_MULT
        end
    end

    if act.target.components.stackable ~= nil then
        print("is stackable: " .. act.target.components.stackable.stacksize)
        chill_duration = chill_duration / act.target.components.stackable.stacksize
    end

    act.target.components.chillable:Chill(chill_duration)

    act.invobject.components.stackable:Get(1):Remove()

    return true
end

-- new GLOBAL Action "CHILL"
AddAction('CHILL', 'Chill', chill)

-- Chilling Action takes some time
AddStategraphActionHandler('wilson_client', GLOBAL.ActionHandler(GLOBAL.ACTIONS.CHILL, "dolongaction"))
AddStategraphActionHandler('wilson', GLOBAL.ActionHandler(GLOBAL.ACTIONS.CHILL, "dolongaction"))

-- what to do when player is trying to use an item with chiller component
-- mostly a check whether to provide the CHILL action or not based hovered item
function chiller(inst, doer, target, actions, right)
    -- print("using item with component chiller on something " .. tostring(right))
    -- DumpEntity(target)
    if right 
        and (target:HasTag("fresh") or target:HasTag("stale") or target:HasTag("spoiled")) then
        -- print("match!")
        table.insert(actions, GLOBAL.ACTIONS.CHILL)
    end
end

-- every prefab with the chiller component can be used in inventory
AddComponentAction("USEITEM", "chiller", chiller)

-- code below this statement is only executed on servers and not on clients
if not GLOBAL.TheNet:GetIsServer() then
    return
end

-- ice adjustments: ----------------

-- all ice prefabs have the chiller component
function tuwas(inst)
    inst:AddComponent("chiller")
end

AddPrefabPostInit("ice", tu_was)

-- stackable adjustments: ----------

local function stackable_stuff(self, inst)
    -- overwrite Get and Put

    local old_get = self.Get
    self.Get = function(self, num)
        -- print("stackable: Get " .. tostring(self) .. " " ..tostring(num))

        local return_instance = old_get(self, num)

        -- basically copy the current chillable effect from one stack to the new one

        local num_to_get = num or 1
        -- partly taken from stackable.lua:59
        if self.stacksize > num_to_get then
            if self.inst.components.chillable ~= nil then
                if self.inst.components.chillable.chilled_until ~= nil then
                    print("stackable: ChillUntil " .. self.inst.components.chillable.chilled_until)
                    return_instance.components.chillable:ChillUntil(self.inst.components.chillable.chilled_until)
                end
            end
        end

        return return_instance
    end

    local old_put = self.Put
    self.Put = function(self, item, source_pos)
        -- partly taken from stackable.lua:90

        -- print("stackable: Put " .. tostring(self) .. " " ..tostring(item) .. " " .. tostring(source_pos))

        -- the following condition expects that 
        --- both inst have chillable
        --- or both inst don't have chillable
        if item.prefab == self.inst.prefab and item.skinname == self.inst.skinname then

            -- dilute the chillable effect in the new stack
            if self.inst.components.chillable ~= nil and item.components.chillable ~= nil then
                local newtotal = self.stacksize + item.components.stackable.stacksize

                local newsize = math.min(self.maxsize, self.stacksize + item.components.stackable.stacksize)        
                local number_added = newsize - self.stacksize
                
                print("stackable: Put " .. tostring(self) .. " " ..tostring(item) .. " " .. tostring(source_pos))
                self.inst.components.chillable:Dilute(item.components.chillable:GetChilledUntil(), number_added)
            end
        end

        return old_put(self, item, source_pos)
    end
end

AddComponentPostInit("stackable", stackable_stuff)


-- other miscellaneous adjustments for specific items:  ------

local function add_chillable_to_perishable(component, inst)
    inst:AddComponent("chillable")
end

local function overwrite_hambat_damage(inst)
    -- chillable component is added via perishable

    -- overwrite damage
    -- chilled hambats are harder!
    if inst.components.weapon ~= nil then
        local old_setdamage = inst.components.weapon.SetDamage
        inst.components.weapon.SetDamage = function(self, dmg)
            local new_dmg = dmg

            if inst.components.chillable ~= nil then
                if inst.components.chillable:GetChilledUntil() ~= nil then
                    new_dmg = new_dmg * 1.1
                end
            end

            old_setdamage(self, new_dmg)
        end
    end
end

local function overwrite_edible_oneaten_temperature(self, inst)
    inst:AddComponent("chillable")
    
    local old_oneaten = self.OnEaten
    self.OnEaten = function(oneaten_self, eater)

        -- local old_edible_component_temperaturedelta = self.temperaturedelta 
        -- local old_edible_component_temperatureduration = self.temperatureduration

        -- KÜHLENDE TEMPERATUR SETZEN
        if inst.components.chillable ~= nil then
            if inst.components.chillable:GetChilledUntil() ~= nil then
                self.temperaturedelta = TUNING.COLD_FOOD_BONUS_TEMP
                self.temperatureduration = TUNING.FOOD_TEMP_BRIEF
            end
        end

        -- STANDARD DS ZEUG
        old_oneaten(oneaten_self, eater)

        -- KÜHLENDE TEMPERATUR ZURÜCKSETZEN
        -- if inst.components.chillable ~= nil then
        --     if inst.components.chillable:GetChilledUntil() ~= nil then
        --         self.temperaturedelta = old_edible_component_temperaturedelta
        --         self.temperatureduration = old_edible_component_temperatureduration
        --     end
        -- end
    end
end

AddComponentPostInit("perishable", add_chillable_to_perishable)
AddPrefabPostInit("hambat", overwrite_hambat_damage)
AddComponentPostInit("edible", overwrite_edible_oneaten_temperature)