DebugMSG.register('process_rules')

if api == nil then
   api = require('BuilderBotAPI')
end
pprint = require('pprint')

function deepcopy(orig)
   local orig_type = type(orig)
   local copy
   if orig_type == 'table' then
      copy = {}
      for orig_key, orig_value in next, orig, nil do
         copy[deepcopy(orig_key)] = deepcopy(orig_value)
      end
      setmetatable(copy, deepcopy(getmetatable(orig)))
   else -- number, string, boolean, etc
      copy = orig
   end
   return copy
end
function draw_block_axes(block_position, block_orientation, color)
   local z = vector3(0, 0, 1)
   api.debug_arrow(color, block_position, block_position + 0.1 * vector3(z):rotate(block_orientation))
end

function draw_line(color, from, to)
   function range(from, to, step)
      step = step or 1
      return function(_, lastvalue)
         local nextvalue = lastvalue + step
         if step > 0 and nextvalue <= to or step < 0 and nextvalue >= to or step == 0 then
            return nextvalue
         end
      end, nil, from - step
   end

   p0 = from
   p1 = to
   vdr = p1 - p0
   last_subpoint = p0
   for lambda in range(0, 1, 0.1) do
      x_ = p0.x + lambda * vdr.x
      y_ = p0.y + lambda * vdr.y
      z_ = p0.z + lambda * vdr.z
      current_subpoint = vector3(x_, y_, z_)
      builderbot_api.debug_arrow(color, last_subpoint, current_subpoint)
      last_subpoint = current_subpoint
   end
end

function check_block_in_safe_zone(block)
   -- we use block in camera eye provided by blocktrackig (Probably would have to do the conversion here in the future)
   x = block.position.x
   y = block.position.y
   z = block.position.z
   -- Define camera parameters (probably this is already provided by michael or maybe ask for it)
   horizontal_fov = 0.60 -- 60 degrees
   vertical_fov = 0.55 -- 60 degrees
   maimum_visible_distance = 1
   c = 0.05
   y_limit = math.tan(vertical_fov / 2) * z - c
   x_limit = math.tan(horizontal_fov / 2) * z - c
   z_limit = maimum_visible_distance - c

   camera_position_in_end_effector = robot.camera_system.transform.position
   camera_position_in_robot =
      camera_position_in_end_effector + vector3(0.0980875, 0, robot.lift_system.position + 0.055)
   camera_orientation_in_robot = robot.camera_system.transform.orientation
   -- Visualize safe zone
   y_limit_for_max_z = math.tan(vertical_fov / 2) * z_limit - c
   x_limit_for_max_z = math.tan(horizontal_fov / 2) * z_limit - c

   staring_point =
      vector3(0, 0, c / math.tan(vertical_fov / 2)):rotate(camera_orientation_in_robot) +
      vector3(camera_position_in_robot)
   api.debug_arrow(
      'green',
      vector3(staring_point),
      vector3(x_limit_for_max_z, y_limit_for_max_z, z_limit):rotate(camera_orientation_in_robot) +
         vector3(camera_position_in_robot)
   )
   api.debug_arrow(
      'green',
      vector3(staring_point),
      vector3(-1 * x_limit_for_max_z, y_limit_for_max_z, z_limit):rotate(camera_orientation_in_robot) +
         vector3(camera_position_in_robot)
   )

   api.debug_arrow(
      'green',
      vector3(staring_point),
      vector3(x_limit_for_max_z, -1 * y_limit_for_max_z, z_limit):rotate(camera_orientation_in_robot) +
         vector3(camera_position_in_robot)
   )

   api.debug_arrow(
      'green',
      vector3(staring_point),
      vector3(-1 * x_limit_for_max_z, -1 * y_limit_for_max_z, z_limit):rotate(camera_orientation_in_robot) +
         vector3(camera_position_in_robot)
   )

   if block.position_robot.z > 0.12 then -- the block could not be higher
      if z < z_limit and y < y_limit and x < x_limit and x > -1 * x_limit then
         -- print('block:', block.id, 'is safe')
         return true
      else
         -- print('block:', block.id, 'is not safe')
         return false
      end
   else
      if z < z_limit and y < y_limit and y > -1 * y_limit and x < x_limit and x > -1 * x_limit then
         -- print('block:', block.id, 'is safe')
         return true
      else
         -- print('block:', block.id, 'is not safe')
         return false
      end
   end
end
function group_blocks()
   local_list_of_structures = {}
   groups_of_connected_blocks = {}
   function check_connected(block_1, block_2)
      -- for now we use distances to tell if blocks are connected or not,
      -- this is not acurate, it could be done by figuring out if two blocks
      -- share at least one edge, but it would require transforming one block position to the other block

      result = false
      orientation_tolerance = 0.0174533 -- one degree
      distance_tolerance = 0.08
      orientation_diff =
         math.sqrt(
         (block_1.orientation_robot.x - block_2.orientation_robot.x) ^ 2 +
            (block_1.orientation_robot.y - block_2.orientation_robot.y) ^ 2
      )

      position_diff =
         math.sqrt(
         (block_1.position_robot.x - block_2.position_robot.x) ^ 2 +
            (block_1.position_robot.y - block_2.position_robot.y) ^ 2 +
            (block_1.position_robot.z - block_2.position_robot.z) ^ 2
      )

      if orientation_diff > orientation_tolerance then
         result = false
      else
         if position_diff < distance_tolerance then
            result = true
         else
            result = false
         end
      end
      return result
   end
   function add_connection_to_list(block_1, block_2)
      for i, group in pairs(groups_of_connected_blocks) do
         for j, block in pairs(group) do
            if block_1.id == block.id and block_1.id ~= block_2.id then
               table.insert(group, block_2)
               return
            elseif block_2.id == block.id and block_1.id ~= block_2.id then
               table.insert(group, block_1)
               return
            end
         end
      end
      -- if the group is new, insert it to the list
      if block_1.id ~= block_2.id then
         group = {
            block_1,
            block_2
         }
      else
         group = {block_1}
      end
      table.insert(groups_of_connected_blocks, group)
   end

   function check_connection_exist(block_1, block_2)
      function has_value(group, block)
         for index, value in pairs(group) do
            if value.id == block.id then
               return true
            end
         end

         return false
      end

      result = false
      for i, group in pairs(groups_of_connected_blocks) do
         if has_value(group, block_1) and has_value(group, block_2) then
            result = true
         end
      end
      return result
   end

   for i, block_1 in pairs(api.blocks) do
      for j, block_2 in pairs(api.blocks) do
         if block_1.id ~= block_2.id then
            if check_connection_exist(block_1, block_2) == false then
               connected = check_connected(block_1, block_2)
               if connected == true then
                  add_connection_to_list(block_1, block_2)
               end
            end
         end
      end
   end
   for i, block_1 in pairs(api.blocks) do
      for j, block_2 in pairs(api.blocks) do
         if block_1.id == block_2.id then
            if check_connection_exist(block_1, block_2) == false then
               add_connection_to_list(block_1, block_2)
            end
         end
      end
   end

   -- Filtering uncertain groups
   -- pprint.pprint(groups_of_connected_blocks)

   -- filtered_groups_list = {}
   -- for i, group in pairs(groups_of_connected_blocks) do
   --    group_clear = true
   --    for j, block in pairs(group) do
   --       print('processing block', tostring(block.id), 'in group:', tostring(i))
   --       if check_block_in_safe_zone(block) == false then
   --          group_clear = false
   --          break
   --       end
   --    end
   --    if group_clear == true then
   --       table.insert(filtered_groups_list, group)
   --    end
   -- end
   filtered_groups_list = groups_of_connected_blocks
   -- builderbot_api.structure_list = groups_of_connected_blocks
   return filtered_groups_list
end

local create_process_rules_node = function(rules, rule_type, final_target)
   final_target.reference_id = nil
   final_target.offset = vector3(0, 0, 0)

   return function()
      grouped_blocks = group_blocks()
      if #grouped_blocks == 0 then
         return false, false
      end

      ------------------------ rotating and indexing the structure ---------------------
      -- Align structure with virtual robot
      for i, group in pairs(grouped_blocks) do
         -- statements
         -- Get the position and orientation of one of the block in the group
         b1_in_r1_ori = group[1].orientation_robot
         b1_in_r1_pos = group[1].position_robot
         -- we assume having the robot in a different position where
         -- the position and orientation of the previous block are as follows:
         b1_in_r2_ori = quaternion(0, 0, 0, 1)
         b1_in_r2_pos = vector3(0.2, 0, b1_in_r1_pos.z - 0.05)
         -- we calculate the inverse relation between the imaginary robot r2 and the block
         r2_in_b1_ori = b1_in_r2_ori:inverse()
         r2_in_b1_pos = -1 * vector3(b1_in_r2_pos):rotate(r2_in_b1_ori)
         -- we calculate the relation between the real robot and the imaginary robot
         r2_in_r1_pos = vector3(r2_in_b1_pos):rotate(b1_in_r1_ori) + b1_in_r1_pos
         r2_in_r1_ori = b1_in_r1_ori * r2_in_b1_ori
         -- we calculate the inverse relation between the real robot r1 and the imaginary r2
         r1_in_r2_ori = r2_in_r1_ori:inverse()
         r1_in_r2_pos = -1 * vector3(r2_in_r1_pos):rotate(r1_in_r2_ori)
         bj_in_r2_pos = {}

         for j, block in pairs(group) do
            -- for each block, we know its relation with r1, and we know the relation r1->r2 so we calculate blocks in r2
            b_in_r1_pos = block.position_robot
            b_in_r2_pos = vector3(b_in_r1_pos):rotate(r2_in_r1_ori:inverse()) + r1_in_r2_pos
            bj_in_r2_pos[tostring(block.id)] = {}
            bj_in_r2_pos[tostring(block.id)].index = (b_in_r2_pos - b1_in_r2_pos)
            bj_in_r2_pos[tostring(block.id)].index.z = b_in_r2_pos.z
            bj_in_r2_pos[tostring(block.id)].type = block.type

            function round(num, numDecimalPlaces)
               local mult = 10 ^ (numDecimalPlaces or 0)
               return math.floor(num * mult + 0.5) / mult
            end
            -- pprint.pprint(bj_in_r2_pos[tostring(block.id)])

            -- transforming the coordinations to indexes
            bj_in_r2_pos[tostring(block.id)].index.x = round(bj_in_r2_pos[tostring(block.id)].index.x / 0.05, 0)
            bj_in_r2_pos[tostring(block.id)].index.y = round(bj_in_r2_pos[tostring(block.id)].index.y / 0.05, 0)
            bj_in_r2_pos[tostring(block.id)].index.z = round(bj_in_r2_pos[tostring(block.id)].index.z / 0.05, 0)
         end
         function get_lowest_indeces(blocks_in_r2)
            lowest_x = 100
            lowest_y = 100
            lowest_z = 100
            for k, indexed_block in pairs(blocks_in_r2) do
               -- Getting lowest x,y,z (should be seperated along with transform indexed blocks to unified origin)
               if indexed_block.index.x < lowest_x then
                  lowest_x = indexed_block.index.x
               end
               if indexed_block.index.y < lowest_y then
                  lowest_y = indexed_block.index.x
               end
               if indexed_block.index.z < lowest_z then
                  lowest_z = indexed_block.index.x
               end
            end
            return lowest_x, lowest_y, lowest_z
         end
         lowest_x, lowest_y, lowest_z = get_lowest_indeces(bj_in_r2_pos)

         -- tranform indexed blocks to unified origin
         for j, block in pairs(bj_in_r2_pos) do
            block.index.x = block.index.x - lowest_x
            block.index.y = block.index.y - lowest_y
            block.index.z = block.index.z - lowest_z
         end
         table.insert(local_list_of_structures, bj_in_r2_pos)
      end
      structure_list = local_list_of_structures
      -- pprint.pprint(structure_list)
      ---------------------------------------------------------------------------------------
      --Match current structures against rules
      final_target.reference_id = nil
      final_target.offset = nil
      targets_list = {}

      function match_structures(visible_structure, rule_structure)
         function tablelength(T)
            local count = 0
            for _ in pairs(T) do
               count = count + 1
            end
            return count
         end
         structure_matching_result = true
         if tablelength(visible_structure) ~= #rule_structure then
            structure_matching_result = false
         else
            for j, rule_block in pairs(rule_structure) do
               block_matched = false
               for k, visible_block in pairs(visible_structure) do
                  if visible_block.index == rule_block.index then --found required index
                     if (visible_block.type == rule_block.type) or (rule_block.type == 'X') then -- found the same required type
                        block_matched = true
                        break
                     end
                  end
               end
               if block_matched == false then
                  structure_matching_result = false
                  break
               end
            end
         end
         return structure_matching_result
      end
      function get_reference_id_from_index(reference_index, visible_structure)
         for j, block in pairs(visible_structure) do
            if block.index == reference_index then
               return j
            end
         end
      end

      ------- generate rotated rules ---------------------

      rotated_rules_list = {}
      for i, rule in pairs(rules.list) do
         if rule.generate_orientations ~= nil and rule.generate_orientations == true then
            rotated_rule = deepcopy(rule)
            rotated_rule.generate_orientations = false
            for i = 1, 3 do
               -- statements
               for j, rule_block in pairs(rotated_rule.structure) do
                  -- rotate and insert
                  index = rule_block.index
                  rule_block.index = vector3(index):rotate(quaternion(0.7071068, 0, 0, 0.7071068))
               end
               -- rotate and insert target as well
               target_index = rotated_rule.target.reference_index
               rotated_rule.target.reference_index =
                  vector3(target_index):rotate(quaternion(0.7071068, 0, 0, 0.7071068))
               table.insert(rotated_rules_list, deepcopy(rotated_rule))
            end
         end
      end
      ------------- insert generated rules into the main list ----------
      for i, generated_rule in pairs(rotated_rules_list) do
         table.insert(rules.list, generated_rule)
      end

      ------ transform rules to unified origin -----------
      for i, rule in pairs(rules.list) do
         lowest_x = 100
         lowest_y = 100
         lowest_z = 100
         for j, rule_block in pairs(rule.structure) do
            if rule_block.index.x < lowest_x then
               lowest_x = rule_block.index.x
            end
            if rule_block.index.y < lowest_y then
               lowest_y = rule_block.index.y
            end
            if rule_block.index.z < lowest_z then
               lowest_z = rule_block.index.z
            end
         end
         for j, rule_block in pairs(rule.structure) do
            rule_block.index.x = round(rule_block.index.x - lowest_x, 0)
            rule_block.index.y = round(rule_block.index.y - lowest_y, 0)
            rule_block.index.z = round(rule_block.index.z - lowest_z, 0)
         end
         rule.target.reference_index.x = round(rule.target.reference_index.x - lowest_x, 0)
         rule.target.reference_index.y = round(rule.target.reference_index.y - lowest_y, 0)
         rule.target.reference_index.z = round(rule.target.reference_index.z - lowest_z, 0)
      end

      function one_block_safe(indexed_structure)
         result = false
         structure = {}
         for bi, indexed_block in pairs(indexed_structure) do
            for b, block in pairs(api.blocks) do
               if tonumber(get_reference_id_from_index(indexed_block.index, indexed_structure)) == tonumber(block.id) then
                  table.insert(structure, block)
               end
            end
         end
         for bi, block in pairs(structure) do
            if check_block_in_safe_zone(block) == true then
               result = true
               break
            end
         end
         return result
      end
      function target_block_safe(indexed_structure, rule_reference_index)
         result = false
         target_block = nil
         target_block_reference_id = get_reference_id_from_index(rule_reference_index, indexed_structure)
         for b, block in pairs(api.blocks) do
            if tonumber(target_block_reference_id) == tonumber(block.id) then
               target_block = block
            end
         end
         if target_block == nil then
            result = false -- target block is not in the structure
            return result
         end
         if check_block_in_safe_zone(target_block) == true then
            result = true
         end

         return result
      end
      -----------------------------------------------------------------------------
      ------------------ matching light source with rule --------------------------
      function match_light_source(actual_lights, rule_light)
         result = false
         for i, actual_light in pairs(actual_lights) do
            if actual_light == rule_light then 
               result = true
            end
         end
         
         return result
      end
      ----------------------------------------------------------------------------
      ------------------ matching rules and getting safe targets ------------------
      -- pprint.pprint(structure_list)
      for i, rule in pairs(rules.list) do
         if rule.rule_type == rule_type then
            match_result = false
            for j, visible_structure in pairs(structure_list) do
               if target_block_safe(visible_structure, rule.target.reference_index) == true then
                  res1 = match_structures(visible_structure, rule.structure)
                  res2 = match_light_source(api.light_source, rule.light)
                  if res1 == true and res2 == true then
                     match_result = true
                     possible_target = {}
                     possible_target.reference_id =
                        get_reference_id_from_index(rule.target.reference_index, visible_structure)
                     possible_target.offset = rule.target.offset_from_reference
                     possible_target.type = rule.target.type
                     possible_target.safe = true
                     table.insert(targets_list, possible_target)
                  end
               end
            end
         end
      end

      -----------------------------------------------------------------------------
      ------------------- match rules and getting unsafe targets ------------------
      -- we get unsafe targets only if we could not find safe targets
      -- if #targets_list == 0 then
      --    for i, rule in pairs(rules.list) do
      --       if rule.rule_type == rule_type then
      --          match_result = false
      --          for j, visible_structure in pairs(structure_list) do
      --             if one_block_safe(visible_structure) == false then
      --                res = match_structures(visible_structure, rule.structure)
      --                if res == true then
      --                   match_result = true
      --                   possible_target = {}
      --                   possible_target.reference_id =
      --                      get_reference_id_from_index(rule.target.reference_index, visible_structure)
      --                   possible_target.offset = rule.target.offset_from_reference
      --                   possible_target.type = rule.target.type
      --                   possible_target.safe = false
      --                   table.insert(targets_list, possible_target)
      --                end
      --             end
      --          end
      --       end
      --    end
      -- end
      --------------------------------------------------------------
      --------------------- Target selection methods ---------------
      if rules.selection_method == 'nearest_win' then
         -----choose the nearest target from the list -------
         minimum_distance = 9999999
         for i, possible_target in pairs(targets_list) do
            for j, block in pairs(api.blocks) do
               if tostring(block.id) == possible_target.reference_id then
                  distance_from_target = math.sqrt((block.position_robot.x) ^ 2 + (block.position_robot.y) ^ 2)
                  if distance_from_target < minimum_distance then
                     minimum_distance = distance_from_target
                     final_target.reference_id = tonumber(possible_target.reference_id)
                     final_target.offset = possible_target.offset
                     final_target.type = possible_target.type
                     final_target.safe = possible_target.safe
                  end
               end
            end
         end
      elseif rules.selection_method == 'furthest_win' then
         -----choose the furthest target from the list -------
         maximum_distance = 0
         for i, possible_target in pairs(targets_list) do
            for j, block in pairs(api.blocks) do
               if tostring(block.id) == possible_target.reference_id then
                  distance_from_target = math.sqrt((block.position_robot.x) ^ 2 + (block.position_robot.y) ^ 2)
                  if distance_from_target > maximum_distance then
                     maximum_distance = distance_from_target
                     final_target.reference_id = tonumber(possible_target.reference_id)
                     final_target.offset = possible_target.offset
                     final_target.type = possible_target.type
                     final_target.safe = possible_target.safe
                  end
               end
            end
         end
      else
         print('no selection method')
      end
      ------- Visualizing the results ----------
      target_block = nil
      for i, block in pairs(api.blocks) do
         if block.id == final_target.reference_id then
            target_block = block
            offsetted_block_in_reference_block_pos = 0.05 * final_target.offset
            offsetted_block_in_robot_pos =
               offsetted_block_in_reference_block_pos:rotate(target_block.orientation_robot) +
               target_block.position_robot
            offsetted_block_in_robot_ori = target_block.orientation_robot
            draw_block_axes(offsetted_block_in_robot_pos, offsetted_block_in_robot_ori, 'blue')
            draw_block_axes(target_block.position_robot, target_block.orientation_robot, 'red')
            break
         end
      end
      -- pprint.pprint(final_target)
      DebugMSG('final target:', final_target)
      if #targets_list > 0 then
         return false, true
      else
         return false, false
      end
   end
end
return create_process_rules_node
