local EnemySelection = require("scripts/ezlibs-custom/nebulous-liberations/liberations/enemy_selection")
local EnemyHelpers = require("scripts/ezlibs-custom/nebulous-liberations/liberations/enemy_helpers")
local Preloader = require("scripts/ezlibs-custom/nebulous-liberations/liberations/preloader")

Preloader.add_asset("/server/assets/NebuLibsAssets/bots/snowball.png")
Preloader.add_asset("/server/assets/NebuLibsAssets/bots/snowball.animation")

local BlizzardMan = {}

function BlizzardMan:new(instance, position, direction)
  local blizzardman = {
    instance = instance,
    id = nil,
    health = 1000,
    max_health = 1000,
    x = math.floor(position.x),
    y = math.floor(position.y),
    z = math.floor(position.z),
    mug = {
      texture_path = "/server/assets/NebuLibsAssets/mugs/blizzardman.png",
      animation_path = "/server/assets/NebuLibsAssets/mugs/blizzardman.animation",
    },
    encounter = "/server/assets/encounters/dependencies/com_OFC_mob_EXEPoN_023_IceManV1.zip",
    selection = EnemySelection:new(instance),
    is_engaged = false
  }

  setmetatable(blizzardman, self)
  self.__index = self

  local shape = {
    {1, 1, 1},
    {1, 0, 1},
    {1, 1, 1},
    {1, 1, 1}
  }

  blizzardman.selection:set_shape(shape, 0, -2)
  blizzardman:spawn(direction)

  return blizzardman
end

function BlizzardMan:do_first_encounter_banter(player_id)
  local co = coroutine.create(function()
    Async.await(Async.message_player(player_id, "I didn't think you would make it this far! *Whoosh*", self.mug.texture_path, self.mug.animation_path))
    Async.await(Async.message_player(player_id, "I'll freeze you to the bone!", self.mug.texture_path, self.mug.animation_path))
    self.is_engaged = true
  end)
  return Async.promisify(co)
end

function BlizzardMan:spawn(direction)
  self.id = Net.create_bot({
    texture_path = "/server/assets/NebuLibsAssets/bots/blizzardman.png",
    animation_path = "/server/assets/NebuLibsAssets/bots/blizzardman.animation",
    area_id = self.instance.area_id,
    direction = direction,
    warp_in = false,
    x = self.x + .5,
    y = self.y + .5,
    z = self.z
  })
  Net.set_bot_minimap_color(self.id, EnemyHelpers.boss_minimap_color)
end

function BlizzardMan:get_death_message()
  return "Woosh!\nI can't believe\nit. I can't lose.\nNOOOO!"
end

function BlizzardMan:take_turn()
  local co = coroutine.create(function()
    if not debug and self.instance.phase == 1 then
      for _, player in ipairs(self.instance.players) do
        player:message(
          "I'll turn this area into a Nebula ski resort! Got it?",
          self.mug.texture_path,
          self.mug.animation_path
        )
      end

      -- Allow time for the players to read this message
      Async.await(Async.sleep(3))
    end

    self.selection:move(self, Net.get_bot_direction(self.id))

    local caught_sessions = self.selection:detect_player_sessions()
    
    if #caught_sessions == 0 then
      return
    end

    self.selection:indicate()

    Async.await(Async.sleep(1))

    for _, player in ipairs(self.instance.players) do
      player:message(
        "Shiver in my\ndeep winter!\nSnowball!",
        self.mug.texture_path,
        self.mug.animation_path
      )
    end

    Async.await(Async.sleep(1))

    EnemyHelpers.play_attack_animation(self)

    local spawned_bots = {}

    for _, player_session in ipairs(caught_sessions) do
      local player = player_session.player

      local snowball_bot_id = Net.create_bot({
        texture_path = "/server/assets/NebuLibsAssets/bots/snowball.png",
        animation_path = "/server/assets/NebuLibsAssets/bots/snowball.animation",
        area_id = self.instance.area_id,
        warp_in = false,
        x = player.x - .5,
        y = player.y - .5,
        z = player.z + 8
      })

      Net.animate_bot_properties(snowball_bot_id, {
        {
          properties = {
            { property = "Animation", value = "FALL" },
          }
        },
        {
          properties = {
            { property = "Z", ease = "Linear", value = player.z + 1 },
          },
          duration = .5
        }
      })

      spawned_bots[#spawned_bots+1] = snowball_bot_id
    end

    Async.await(Async.sleep(.5))

    for _, player in ipairs(self.instance.players) do
      Net.shake_player_camera(player.id, 2, .5)
    end

    for _, player_session in ipairs(caught_sessions) do
      player_session:hurt(40)
    end

    Async.await(Async.sleep(.5))

    for _, bot_id in ipairs(spawned_bots) do
      Net.remove_bot(bot_id, false)
    end

    Async.await(Async.sleep(1))

    self.selection:remove_indicators()
  end)

  return Async.promisify(co)
end

return BlizzardMan
