local function create_smoke(self, anim_state)
    local smoke = Battle.Spell.new(self:get_team())
    smoke:set_texture(Engine.load_texture(_folderpath .. "teleport.png"), true)
    smoke:sprite():set_layer(-2)
    local animation = smoke:get_animation()
    animation:load(_folderpath .. "teleport.animation")
    animation:set_state(anim_state)
    animation:refresh(smoke:sprite())
    animation:on_complete(function()
        smoke:erase()
    end)
    return smoke
end

local function spawn_attack_visual(team, tile, field)
    local visual = Battle.Spell.new(team)
    visual:set_texture(Engine.load_texture(_folderpath .. "hit_effect.png"))
    local anim = visual:get_animation()
    anim:load(_folderpath .. "hit_effect.animation")
    anim:refresh(visual:sprite())
    anim:set_state("DEFAULT")
    visual:sprite():set_layer(-3)
    anim:on_complete(function()
        visual:erase()
    end)
    field:spawn(visual, tile)
end

local function increment_pattern(self)
    self.guard_index = 1
    self.can_block = true
    self.should_block = false
    self.pattern_index = self.pattern_index + 1
    if self.pattern_index > #self.pattern then self.pattern_index = 1 end
    self.pattern_cooldown_index = self.pattern_cooldown_index + 1
    if self.pattern_cooldown_index > #self.pattern_cooldown_list then self.pattern_cooldown_index = 1 end
    self.anim_once = true
    if self.is_guarding or self.defense ~= nil then
        self.is_guarding = false
        self:remove_defense_rule(self.defense)
    end
    self.pattern_cooldown = self.pattern_cooldown_list[self.pattern_cooldown_index]
end

local function warp(self, anim_state)
    local smoke = create_smoke(self, anim_state)
    local field = self:get_field()
    local facing = self:get_facing()
    local i = 1
    local goal = 6
    local increment = 1
    if facing == Direction.Right then
        i = 6
        goal = 1
        increment = -1
    end
    for x = i, goal, increment do
        for y = 1, 3, 1 do
            local prospective_tile = field:tile_at(x, y)
            if self.can_move_to_func(prospective_tile) then self.warp_tile = prospective_tile break end
        end
    end
    field:spawn(smoke, self:get_tile())
    local c = Battle.Component.new(self, Lifetimes.Battlestep)
    c.duration = 60
    c.start_tile = self:get_current_tile()
    c.target_tile = self.warp_tile
    c.owner = self
    c.smoke = create_smoke(self, "BIG_TELEPORT_TO")
    c.update_func = function(self, dt)
        if self.owner:get_health() == 0 then self:eject() return end
        self.duration = self.duration - 1
        if self.duration == 10 then
            local owner_anim = self.owner:get_animation()
            owner_anim:set_state("IDLE")
            owner_anim:refresh(self.owner:sprite())
            owner_anim:set_playback(Playback.Loop)
        end
        if self.duration <= 0 then
            increment_pattern(self.owner)
            self.target_tile:add_entity(self.owner)
            field:spawn(self.smoke, self.target_tile)
            self.owner.can_block = true --Enable blocking.
            self:eject()
        end
    end
    c.scene_inject_func = function(self)
        local id = self:get_owner():get_id()
        self.owner:get_tile():remove_entity_by_id(id)
        self.target_tile:reserve_entity_by_id(id)
    end
    self:register_component(c)
end

local function spawn_attack(self)
    if self.tile ~= nil and self.panels ~= nil then
        local spell = Battle.Spell.new(self:get_team())
        spell:set_hit_props(
            HitProps.new(
                self.attack,
                Hit.Impact | Hit.Flinch | Hit.Flash,
                Element.None,
                self:get_context(),
                Drag.None
            )
        )
        spell.duration = 4
        for i = 1, #self.panels, 1 do
            self.panels[i]:set_state(TileState.Cracked)
        end
        spell.update_func = function()
            spell.duration = spell.duration - 1
            if spell.duration == 0 then spell:delete() return end
            for i = 1, #self.panels, 1 do
                self.panels[i]:highlight(Highlight.Flash)
                self.panels[i]:attack_entities(spell)
            end
        end
        spell.collision_func = function(self)
            self:delete()
        end
        spell.delete_func = function()
            for i = 1, #self.panels, 1 do
                self.panels[i]:highlight(Highlight.None)
            end
            spell:erase()
            self.tile = nil
            self.panels = nil
        end
        local field = self:get_field()
        field:spawn(spell, self.tile)
        Engine.play_audio(Engine.load_audio(_folderpath .. "sounds/attack.ogg", true), AudioPriority.High)
        spawn_attack_visual(self:get_team(), self.tile, field)
    end
end

local function spawn_attack_highlight(self)
    --Don't do anything if the target is dead.
    if not self.target or self.target and self.target:is_deleted() then return end
    --Get the tile to highlight.
    local tile = self.target:get_tile()
    --Adjust if it's not the middle tile.
    if tile:y() > 2 then
        tile = tile:get_tile(Direction.Up, 1)
    elseif tile:y() < 2 then
        tile = tile:get_tile(Direction.Down, 1)
    end
    --Now grab all three once we guarantee we're in the middle.
    local panels = { tile, tile:get_tile(Direction.Up, 1), tile:get_tile(Direction.Down, 1) }
    local spell = Battle.Spell.new(self:get_team())
    spell.timer = 48
    spell.update_func = function(self, dt)
        self.timer = self.timer - 1
        if self.timer == 0 then self:erase() return end
        for i = 1, #panels, 1 do
            panels[i]:highlight(Highlight.Flash)
        end
    end
    self.target:get_field():spawn(spell, tile)
    self.tile = tile
    self.panels = panels
end

local function find_best_target(self)
    local target = self:get_target()
    local field = self:get_field()
    local query = function(c)
        return c:get_team() ~= self:get_team()
    end
    local potential_threats = field:find_characters(query)
    local goal_hp = 99999
    if #potential_threats > 0 then
        for i = 1, #potential_threats, 1 do
            local possible_target = potential_threats[i]
            if possible_target:get_health() <= goal_hp and possible_target:get_health() > 0 then
                target = possible_target
            end
        end
    end
    return target
end

function package_init(self, character_info)
    self:set_texture(Engine.load_texture(_folderpath .. "bladia.greyscaled.png"))
    self:set_palette(Engine.load_texture(character_info.palette))
    local anim = self:get_animation()
    anim:load(_folderpath .. "bladia.animation")
    anim:set_state("SPAWN")
    anim:refresh(self:sprite())
    self:set_health(tonumber(character_info.hp))
    self.attack = character_info.attack
    self:set_name(character_info.name)
    local field = nil
    self.battle_start_func = function(self)
        field = self:get_field()
        anim:set_state("IDLE")
        anim:refresh(self:sprite())
        anim:set_playback(Playback.Loop)
    end
    self.tile = nil
    self.target = nil
    self.panels = nil
    self.pattern = { "IDLE", "ATTACK", "WARP" }
    self.pattern_index = 1
    self.pattern_cooldown_list = { 180, 168, 60 } --How long each state lasts. Idle for 180 frames. Attack for 168 frames. Vanish for 60 before reappearing. Reset.
    self.pattern_cooldown_index = 1
    self.anim_once = true
    self.guard_chances = { 33, 67, 100 } --Chance to guard. Every time we detect an attack and fail to guard, increment the chance for next time.
    self.guard_index = 1
    self.attack_find_query = function(s)
        if s then
            if Battle.Character.from(s) ~= nil or Battle.Obstacle.from(s) ~= nil or Battle.Player.from(s) ~= nil then return false end
            return s:get_tile():y() == self:get_tile():y() and s:get_team() ~= self:get_team()
        end
        return false
    end
    self.virus_body = Battle.DefenseVirusBody.new()
    self:add_defense_rule(self.virus_body)
    local tink = Engine.load_audio(_folderpath .. "sounds/tink.ogg")
    local guard_texture = Engine.load_texture(_folderpath .. "guard_hit.png")
    self.pattern_cooldown = self.pattern_cooldown_list[self.pattern_cooldown_index]
    self.is_guarding = false
    self.defense = nil
    self.warp_tile = nil
    local occupied_query = function(ent)
        return Battle.Obstacle.from(ent) ~= nil or Battle.Character.from(ent) ~= nil
    end
    self.can_move_to_func = function(tile)
        if not tile then return false end
        if tile:is_edge() then return false end
        if #tile:find_entities(occupied_query) > 0 then return false end
        return true
    end
    self.can_block = true --Bool used to determine if we can block right now. Turns off when blocking & when in certain animations.
    self.should_block = false --Bool used to determine if an attack worth blocking is found.
    self.update_func = function(self, dt)
        if not self.is_guarding and self.can_block then
            local attacks = field:find_entities(self.attack_find_query)
            if #attacks > 0 then
                --Collapsed for loop. Goes over the attack list and checks if any have a damage value over 0.
                --If so, tells Bladia he should try to block.
                for i = 1, #attacks, 1 do if attacks[i]:copy_hit_props().damage > 0 then self.should_block = true break end end
                if math.random(1, 100) <= self.guard_chances[self.guard_index] and self.should_block then
                    self.is_guarding = true
                    self.should_block = false
                    self.can_block = false --Disable blocking while already blocking.
                    anim:set_state("BLOCK")
                    anim:on_frame(2, function()
                        self.defense = Battle.DefenseRule.new(1, DefenseOrder.CollisionOnly)
                        self.defense.owner = self
                        self.defense.can_block_func = function(judge, attacker, defender)
                            --Don't block if has the breaking flag
                            if attacker:copy_hit_props().flags & Hit.Breaking == Hit.Breaking then return end
                            --If no breaking flag then block, play the sound and animation
                            judge:block_damage()
                            judge:block_impact()
                            Engine.play_audio(tink, AudioPriority.Highest)
                            local xset = math.random(10, 50)
                            local yset = math.random(35, 50)
                            xset = xset * -1
                            yset = yset * -1
                            if defender:get_facing() == Direction.Right then xset = xset * -1 end
                            local shine = Battle.Spell.new(defender:get_team())
                            shine:set_offset(xset, yset)
                            shine:set_texture(guard_texture)
                            local shine_anim = shine:get_animation()
                            shine_anim:load(_modpath .. "guard_hit.animation")
                            shine_anim:set_state("DEFAULT")
                            shine_anim:refresh(shine:sprite())
                            shine:sprite():set_layer(-2)
                            shine_anim:on_complete(function()
                                shine:delete()
                            end)
                            defender:get_field():spawn(shine, defender:get_tile())
                        end
                        self:add_defense_rule(self.defense)
                    end)
                    anim:on_complete(function()
                        self:remove_defense_rule(self.defense)
                        self.is_guarding = false
                        self.can_block = true
                    end)
                else
                    self.can_block = true
                    self.is_guarding = false
                    self.guard_index = self.guard_index + 1
                    if self.guard_index > #self.guard_chances then self.guard_index = #self.guard_chances end
                end
            end
        end
        if self.pattern_cooldown > 0 then self.pattern_cooldown = self.pattern_cooldown - 1 return end
        if self.pattern[self.pattern_index] == "IDLE" and self.anim_once then
            self.anim_once = false
            anim:set_state("IDLE")
            anim:refresh(self:sprite())
            anim:set_playback(Playback.Loop)
            increment_pattern(self)
        elseif self.pattern[self.pattern_index] == "ATTACK" and self.anim_once then
            self.anim_once = false
            self.target = find_best_target(self)
            anim:set_state("ATTACK")
            anim:refresh(self:sprite())
            anim:on_frame(1, function()
                if self.defense ~= nil then self:remove_defense_rule(self.defense) end
                self.can_block = false --Disable blocking.
            end)
            anim:on_frame(3, function()
                spawn_attack_highlight(self)
            end)
            anim:on_frame(4, function()
                self:toggle_counter(true)
            end)
            anim:on_frame(6, function()
                self:toggle_counter(false)
                self:shake_camera(8.0, 0.6)
                spawn_attack(self)
            end)
            anim:on_complete(function()
                increment_pattern(self)
                self.can_block = false
            end)
        elseif self.pattern[self.pattern_index] == "WARP" and self.anim_once then
            self.anim_once = false
            self.can_block = false
            warp(self, "BIG_TELEPORT_FROM")
        end
    end
end

return package_init
