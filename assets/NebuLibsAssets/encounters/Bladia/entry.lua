local package_id = "com.EXE5.Bladia"
local character_id = "com.EXE5.Bladia.Enemy"

function package_requires_scripts()
    Engine.define_character(character_id, _modpath .. "shared")
    Engine.define_character(character_id .. "1", _modpath .. "1")
    Engine.define_character(character_id .. "2", _modpath .. "2")
    Engine.define_character(character_id .. "3", _modpath .. "3")
    Engine.define_character(character_id .. "4", _modpath .. "4")
    Engine.define_character(character_id .. "5", _modpath .. "5")
    Engine.define_character(character_id .. "6", _modpath .. "6")
end

function package_init(package)
    package:declare_package_id(package_id)
    package:set_name("Bladia")
    package:set_description("And steadily it would decline, in to its solitary shell.")
    package:set_speed(1)
    package:set_attack(50)
    package:set_health(200)
    package:set_preview_texture_path(_modpath .. "preview.png")
end

function package_build(mob, data)
    --Make it a liberation fight.
    mob:enable_freedom_mission(3, false)
    --You may change this 1 to any number up to 6, and fight a higher rank Bladia.
    local rank = "1"
    print(data)
    --Liberation missions sometimes call up a higher rank from server side.
    if data and data.rank then rank = data.rank end
    --In case the server has converted it to an integer, we use tostring()
    mob:create_spawner(character_id..tostring(rank), Rank.V1):spawn_at(5, 2):mutate(function(character)
        if data and data.health then
            print("mutating")
            character:set_health(data.health)
        end
    end)
end
