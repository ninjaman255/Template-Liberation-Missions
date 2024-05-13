--Functions for easy reuse in scripts
--Version 1.0

battle_helpers = {}

function battle_helpers.spawn_visual_artifact(field,tile,texture,animation_path,animation_state,position_x,position_y)
    local visual_artifact = Battle.Artifact.new()
    visual_artifact:set_texture(texture,true)
    local anim = visual_artifact:get_animation()
    anim:load(animation_path)
    anim:set_state(animation_state)
    anim:on_complete(function()
        visual_artifact:delete()
    end)
    visual_artifact:sprite():set_offset(position_x,position_y)
    anim:refresh(visual_artifact:sprite())
    field:spawn(visual_artifact, tile:x(), tile:y())
end

battle_helpers.can_move_to_func = function(tile, entity)
    if not tile:is_walkable() or tile:get_team() ~= entity:get_team() or tile:is_reserved({ entity:get_id(), entity._reserver }) then
      return false
    end

    local has_character = false

    tile:find_characters(function(c)
      if c:get_id() ~= entity:get_id() then
        has_character = true
      end
      return false
    end)

    tile:find_obstacles(function(c)
        if c:get_id() ~= entity:get_id() then
          has_character = true
        end
        return false
      end)

    return not has_character
end


battle_helpers.can_move_to_func_front_row = function(tile)
    if not tile:is_walkable() or tile:get_team() ~= self:get_team() or tile:is_reserved({ self:get_id(), self._reserver }) then
      return false
    end

    local has_character = false

    tile:find_characters(function(c)
        if c:get_id() ~= self:get_id() then
            has_character = true
        end
        return false
    end)

    if tile:get_tile(Direction.Left,1):get_team() == self:get_team() then
        has_character = true
    end

    return not has_character
end


battle_helpers.can_move_to_func_target_enemy = function(tile)
    
    if not tile:is_walkable() or tile:get_team() ~= self:get_team() or tile:is_reserved({ self:get_id(), self._reserver }) then
      return false
    end

    local has_enemy = false
    local x = 0
    while x < 6 do 
        if tile:get_tile(Direction.Left, x):is_edge() then
            return has_enemy
        end
        tile:get_tile(Direction.Left, x):find_characters(function(c)
            if c:get_id() ~= self:get_id() then
                has_enemy = true
            end
            return false
        end)
        x = x + 1
    end
    return has_enemy


    
end

function battle_helpers.move_at_random(character)
    
	local field = character:get_field()
	local my_tile = character:get_tile()
	local tile_array = {}
    for x = 1, 6, 1 do
        for y = 1, 3, 1 do
            local prospective_tile = field:tile_at(x, y)
            if battle_helpers.can_move_to_func(prospective_tile, character) and
            my_tile ~= prospective_tile then
                table.insert(tile_array, prospective_tile)
            end
        end
    end
    
	if #tile_array == 0 then return false end
	target_tile = tile_array[math.random(1, #tile_array)]
	if target_tile then
		moved = character:teleport(target_tile, ActionOrder.Immediate)
	end
	return moved
end

return battle_helpers