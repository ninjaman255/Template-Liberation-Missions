local shared_package_init = include("../shared/entry.lua")
function package_init(character)
    local character_info = {
        name = "Bladia4",
        hp = 300,
        attack = 160,
        height = 70,
        palette = _folderpath.."bladia.png"
    }
    shared_package_init(character, character_info)
end
