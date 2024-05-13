local big_brute_id = "com.keristero.char.BigBrute"

function package_requires_scripts()
    Engine.requires_character(big_brute_id)
end

function package_init(package)
    package:declare_package_id("com.discord.Konstinople#7692.encounter.big_brute.liberation")
end

function package_build(mob, data)
    mob:enable_freedom_mission(3, false)

    mob:create_spawner(big_brute_id, Rank.V1)
       :spawn_at(5, 2)
       :mutate(function(character)
            if data.health then
                character:set_health(data.health)
            end
        end)
end
