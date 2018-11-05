local extract = "D:/Extract/" --Change to your path
local done = {}
function ParseXml(file, scriptdata, trykey)
    if trykey then
        local file = ParseXml(trykey, scriptdata)
        if file then
            return file
        end
    end
    return SystemFS:exists(file) and (scriptdata and FileIO:ReadScriptData(file, "binary") or SystemFS:parse_xml(file)) or nil
end
 
function LogFound(path, check_db_ext)
    if not path then return end
    if done[path] then
        return
    else
        done[path] = true
    end
    if check_db_ext then 
        if not DB:has(check_db_ext, path) then
            return
        end
    end
    local file_write = "Paths.txt"
    local opened_file = io.open( file_write , "a+")
    if opened_file then
        opened_file:write(path .. "\n")
        opened_file:close()
    end
end
 
function SearchInUnit(file)
    local node = ParseXml(file)
    if node then
        for child in node:children() do
            local name = child:name()
            if name == "object" then
                local unit = tostring(child:parameter("file"))
                LogFound(unit)
                if unit:find("wpn_fps") then
                    LogFound(unit.."_npc", "unit")
                end
            elseif name == "dependencies" then
                for dep in child:children() do
                    for ext, path in pairs(dep:parameters()) do
                        LogFound(path)
                    end
                end
            elseif name == "anim_state_machine" then
                LogFound(child:parameter("name"))
            elseif name == "remote_unit" then
                local remote_unit = child:parameter("remote_unit")
                if remote_unit ~= "" then
                    LogFound(remote_unit, "unit")
                    LogFound(remote_unit:gsub("_husk", ""), "unit")                    
                end
            end
        end    
    end
end
 
function SearchInObject(file)
    local node = ParseXml(file)
    if node then
        for child in node:children() do
            local name = child:name()
            if name == "diesel" and child:has_parameter("materials") then
                local material = child:parameter("materials")
                LogFound(material)
            elseif name == "sequence_manager" then
                LogFound(child:parameter("file"))
            elseif name == "effects" then
                for efct in child:children() do
                    LogFound(efct:parameter("effect"))
                end
            elseif name == "animation_def" then
                LogFound(child:parameter("name"))
            end
        end
    end
end
 
 
function SearchInMaterial(file)
    local node = ParseXml(file)
    if node then
        for child in node:children() do
            if child:name() == "material" then
                for v in child:children() do
                    if v:has_parameter("file") then
                        LogFound(v:parameter("file"))
                    end
                end
            end
        end
    end
end
 
function SearchInAnimDef(file)
    local node = ParseXml(file)
    if node then
        for child in node:children() do    
            if child:name() == "animation_set" then
                for anim_set in child:children() do
                    local anim_subset = anim_set:parameter("file")
                    LogFound(anim_subset)
                end  
            end
        end
    end
end
 
function SearchInAnimSubset(file)
    local node = ParseXml(file)
    if node then
        for child in node:children() do
            LogFound(child:parameter("file"))
        end
    end
end

function SearchInAnimStateMachine(file)
    local node = ParseXml(file)
    if node then
        for child in node:children() do    
            if child:name() == "states" then
                LogFound(child:parameter("file"))
            end
        end
    end
end

function SearchInContinent(file)
    local node = ParseXml(file, true)
    if node.statics then
        for _, static in ipairs(node.statics) do
            LogFound(static.unit_data.name)
        end
    else
        log(file, "has no statics..?")
    end
    if node.instances then
        for _, instance in ipairs(node.instances) do
            local path = instance.folder
            LogFound(path.."/world")
            path = Path:GetDirectory(path).."/"
            LogFound(path.."continents")
            LogFound(path.."cover_data")
            LogFound(path.."massunit")
            LogFound(path.."mission")
            LogFound(path.."nav_manager_data")
            LogFound(path.."world")
            LogFound(path.."world_cameras")
            LogFound(path.."world_sounds")
            LogFound(path.."cube_lights/dome_occlusion")
            local possible_blacklist = path.."blacklist"
            if DB:has("blacklist", possible_blacklist) then
                LogFound(possible_blacklist)
            end
        end
    end
end

function SearchInMission(file)
    local node = ParseXml(file, true)
    for _, script in pairs(node) do
        if type(script) == "table" and script.elements then
            for _, element in ipairs(script.elements) do
                local vals = element.values
                if vals.enemy then
                    LogFound(vals.enemy)
                end
                if vals.effect then
                    LogFound(vals.effect)
                end
                if vals.unit then
                    LogFound(vals.unit)
                end
            end
        end
    end
end

function SearchInWorld(file)
    local node = ParseXml(file, true)
    local env = node.environment
    if env then
        local env_vals = env.environment_values
        LogFound(env_vals.environment)
        for _, area in ipairs(env.environment_areas) do
            LogFound(area.environment)
        end
        for _, effect in ipairs(env.effects) do
            LogFound(effect.name)
        end
    end
end

function SearchInSequence(file)
    local node = ParseXml(file, true)
    if node.unit then
        for _, sequence in ipairs(node.unit) do
            for _, shit in ipairs(sequence) do
                if shit.name and shit.name:find("/%w+/") then
                    local name = shit.name:gsub("'", "")
                    LogFound(name)
                elseif not tonumber(shit.param3) and shit.param3 and shit.param3:find("/%w+/") then
                    local name = shit.param3:gsub("'", "")
                    LogFound(name)
                end
            end
        end
    end
end

function SearchInBank(path)
    local file = io.open(path, "rb")
    local read = file:read("*all"):reverse()
    local match = read:match("%w+_*%w*_*%w*")
    if match:len() > 2 then
        LogFound("soundbanks/"..match) --Some don't have a name at the end so they will fail.
    end
    file:close()
end

local funcs = {
    unit = SearchInUnit,
    object = SearchInObject,
    material_config = SearchInMaterial,
    animation_def = SearchInAnimDef,
    animation_subset = SearchInAnimSubset,
    animation_state_machine = SearchInAnimSubset,
    bnk = SearchInBank,
    sequence_manager = SearchInSequence,
    mission = SearchInMission,
    continent = SearchInContinent,
    world = SearchInWorld
}

local logged = {}
function find_all(path)
    for _, file in pairs(SystemFS:list(path)) do
        local splt = string.split(file, "%.")
        local ext = splt[#splt]
        local file_path = path.."/"..file
        if funcs[ext] then
            funcs[ext](file_path)
        elseif not logged[ext] then
            log("no function for", file_path)
            logged[ext] = true
        end
    end

    --Comment to only search root directory
    for _, folder in pairs(SystemFS:list(path, true)) do
        find_all(path.."/"..folder)
    end
end

log("Beginning in 5 seconds..")
DelayedCalls:Add("アルミル・ハシュリスト", 5, function()
    os.execute('"'..Application:base_path()..'mods\\extract_paths\\HashlistHelper.exe" banksinfo '..extract:gsub("/", "\\")..'existing_banks.banksinfo Paths.txt')

    for id, level in pairs(tweak_data.levels) do
        if not level.custom then
            local name = level.world_name
            if level.load_screen then
                LogFound(level.load_screen)
            end
            if name then
                name = "levels/"..name
                LogFound(name.."/world")
                LogFound(name.."/nav_manager_data")
                LogFound(name.."/massunit")
                LogFound(name.."/cover_data")
                LogFound(name.."/continents")
                LogFound(name.."/mission")
                LogFound(name.."/world_cameras")
                LogFound(name.."/world_sounds")

                local possible_blacklist = name.."/blacklist"
                if DB:has("blacklist", possible_blacklist) then
                    LogFound(possible_blacklist)
                end
    

                local node = ParseXml(extract..name.."/mission.mission", true, extract..BLEP.swap_endianness(string.key(name.."/mission"))..".mission")
                if node then
                    for _, mission in pairs(node) do
                        local continent_path = name.."/"..mission.file
                        LogFound(continent_path)
                        local node = ParseXml(extract..continent_path..".continent", true, extract..BLEP.swap_endianness(string.key(continent_path))..".continent", true)
                
                        if node.statics then
                            for _, static in ipairs(node.statics) do
                                local ud = static.unit_data
                                if ud.projection_textures then
                                    for _, texture in pairs(ud.projection_textures) do
                                        LogFound(texture)
                                    end
                                end
                                if ud.lights or ud.projection_lights then
                                    LogFound(name.."/cube_lights/"..ud.unit_id, "texture")
                                end
                            end
                        end

                    end
                else
                    log("Mission doesn't exist", extract..name.."/mission.mission")
                end
            elseif level.name_id then
                log("Has no world name", tostring(id))
            end
        end
    end
    for id, narr in pairs(tweak_data.narrative.jobs) do
        if not narr.custom then
            if narr.load_screen then
                LogFound(narr.load_screen)
            end
            local vis = narr.contract_visuals
            if vis and vis.preview_image then
                local data = vis.preview_image
                if data.id then
                    LogFound("guis/dlcs/" .. (data.folder or "bro") .. "/textures/pd2/crimenet/" .. data.id)
                end
            end
        end
    end

    for _, tip in ipairs(tweak_data.tips.tips) do
        LogFound("guis/textures/loading/hints/" .. tip.image)
    end

    for _, ad in ipairs(tweak_data.gui.new_heists) do
        LogFound(ad.texture_path)
    end

    for _, ad in ipairs(tweak_data.gui.content_updates.item_list) do
        LogFound(ad.image)
    end

    local function TryTexture(path, path2)
        if DB:has("texture", path) then
            LogFound(path)
        elseif path2 and DB:has("texture", path2) then
            LogFound(path2)
        end
    end
    for id, tbl in pairs(tweak_data.blackmarket.projectiles) do
        if tbl.icon then
            LogFound(tbl.icon)
            LogFound(tbl.unit)
            LogFound(tbl.sprint_unit)
            TryTexture("guis/textures/pd2/blackmarket/icons/grenades/"..id, tbl.texture_bundle_folder and "guis/dlcs/"..tbl.texture_bundle_folder.."/textures/pd2/blackmarket/icons/grenades/"..id)
            TryTexture("guis/textures/pd2/blackmarket/icons/grenades/outline/"..id, tbl.texture_bundle_folder and "guis/dlcs/"..tbl.texture_bundle_folder.."/textures/pd2/blackmarket/icons/grenades/outline/"..id)
        end
    end
    for id, tbl in pairs(tweak_data.weapon) do
        TryTexture("guis/textures/pd2/blackmarket/icons/weapons/"..id, tbl.texture_bundle_folder and "guis/dlcs/"..tbl.texture_bundle_folder.."/textures/pd2/blackmarket/icons/weapons/"..id)
        TryTexture("guis/textures/pd2/blackmarket/icons/weapons/outline/"..id, tbl.texture_bundle_folder and "guis/dlcs/"..tbl.texture_bundle_folder.."/textures/pd2/blackmarket/icons/weapons/outline/"..id)
    end

    for id, tbl in pairs(tweak_data.blackmarket.melee_weapons) do
        TryTexture("guis/textures/pd2/blackmarket/icons/melee_weapons/"..id, tbl.texture_bundle_folder and "guis/dlcs/"..tbl.texture_bundle_folder.."/textures/pd2/blackmarket/icons/melee_weapons/"..id)
        TryTexture("guis/textures/pd2/blackmarket/icons/melee_weapons/outline/"..id, tbl.texture_bundle_folder and "guis/dlcs/"..tbl.texture_bundle_folder.."/textures/pd2/blackmarket/icons/melee_weapons/outline/"..id)
    end
    
    for id, tbl in pairs(tweak_data.equipments) do
        TryTexture("guis/textures/pd2/blackmarket/icons/deployables/outline/"..id)
    end
    
    for id, tbl in pairs(tweak_data.hud_icons) do
        LogFound(tbl.texture)
    end

    for id, tbl in pairs(tweak_data.blackmarket.textures) do
        LogFound(tbl.texture)
    end

    local function GetIcon(bundle_folder, cat, id)
        local guis_catalog = "guis/"
            
        if bundle_folder then
            guis_catalog = guis_catalog .. "dlcs/" .. tostring(bundle_folder) .. "/"
        end
        
        LogFound(guis_catalog .. "textures/pd2/blackmarket/icons/"..cat.."/" .. id)
    end

    for id, tbl in pairs(tweak_data.blackmarket.materials) do
        LogFound(tbl.texture)
        GetIcon(tbl.texture_bundle_folder, "materials", id)
    end

    for id, tbl in pairs(tweak_data.blackmarket.weapon_skins) do
        LogFound("guis/dlcs/"..tbl.texture_bundle_folder.."/weapon_skins/"..id)
    end

    for id, tbl in pairs(tweak_data.blackmarket.masks) do
        GetIcon(tbl.texture_bundle_folder, "masks", id)
    end

    for id, tbl in pairs(tweak_data.weapon.factory.parts) do
        GetIcon(tbl.texture_bundle_folder, "mods", id)
	end
    
    for cat, tbl in pairs(tweak_data.economy) do
        if cat == "safes" or cat == "drills" or cat == "armor_skins" then
            for id, td in pairs(tbl) do
                local guis_catalog = "guis/"
                local bundle_folder = td.texture_bundle_folder
        
                if bundle_folder then
                    guis_catalog = guis_catalog .. "dlcs/" .. tostring(bundle_folder) .. "/"
                end
                LogFound(guis_catalog .. cat .. "/" .. id)
            end
        end
    end

    --Comment to search only lua.
    --find_all(extract)
end)
