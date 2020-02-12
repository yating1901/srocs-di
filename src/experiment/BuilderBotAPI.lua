----------------------------------------------------
-- Intermediate Level of BuilderBot
--
-- Author
--    Weixu Zhu,  Tutti mi chiamano Harry
--       zhuweixu_harry@126.com
--
----------------------------------------------------
require('BlockTracking')
pprint = require('pprint')
local builderbot_api = {}

-- consts --------------------------------------------
------------------------------------------------------
builderbot_api.consts = {}
builderbot_api.consts.end_effector_position_offset = vector3(0.09800875, 0, 0.055)

-- parameters ----------------------------------------
------------------------------------------------------
builderbot_api.parameters = {}

builderbot_api.parameters.lift_system_upper_limit = 0.135
builderbot_api.parameters.lift_system_lower_limit = 0
builderbot_api.parameters.lift_system_rf_cover_threshold = 0.06
builderbot_api.parameters.lift_system_position_tolerance = tonumber(robot.params.lift_system_tolerance or 0.001)

builderbot_api.parameters.default_speed = tonumber(robot.params.default_speed or 0.005)

builderbot_api.parameters.search_random_range = tonumber(robot.params.search_random_range or 25)

builderbot_api.parameters.aim_block_angle_tolerance = tonumber(robot.params.aim_block_angle_tolerance or 0.5)

builderbot_api.parameters.block_position_tolerance = tonumber(robot.params.block_position_tolerance or 0.001)

builderbot_api.parameters.proximity_touch_tolerance = tonumber(robot.params.proximity_touch_tolerance or 0.003)

builderbot_api.parameters.proximity_detect_tolerance = tonumber(robot.params.proximity_detect_tolerance or 0.03)

builderbot_api.parameters.proximity_maximum_distace = tonumber(robot.params.proximity_maximum_distace or 0.05)



-- system --------------------------------------------
------------------------------------------------------
builderbot_api.lastTime = 0
builderbot_api.time_period = 0
builderbot_api.process_time = function()
   builderbot_api.time_period = robot.system.time - builderbot_api.lastTime
   builderbot_api.lastTime = robot.system.time
end

-- move --------------------------------------------
------------------------------------------------------
builderbot_api.move = function(x, y)
   -- TODO
   -- x, y for left and right, in m/s
   robot.differential_drive.set_target_velocity(x, -y)
end

builderbot_api.move_with_bearing = function(v, th)
   -- move v m/s forward, with th degree/s to the left
   -- this is the distance of two wheelsA
   -- TODO: needs to be tested on real robots
   local d = 0.1225
   local diff = math.pi * d * (th / 360)
   local x = v - diff
   local y = v + diff
   robot.differential_drive.set_target_velocity(x, -y)
end

builderbot_api.move_with_vector3 = function(v3) -- x front, y left
   local v = v3:length()
   if v3.x < 0 then
      v = -v
   end
   local diff = math.atan(v3.y / v3.x) * 180 / math.pi
   builderbot_api.move_with_bearing(v, diff)
end

-- nfc  ----------------------------------------------
------------------------------------------------------
builderbot_api.set_type = function(type)
   if type == 0 or type == 1 or type == 2 or type == 3 or type == 4 then
      robot.nfc.write(tostring(type))
   else
      -- robot.nfc.write(tostring(builderbot_api.consts.color_to_index_table['black']))
      DebugMSG('type is invalid')
   end
end

-- lift ----------------------------------------------
------------------------------------------------------
-- this number is updated by process_positions
builderbot_api.end_effector_position =
   builderbot_api.consts.end_effector_position_offset + vector3(0, 0, robot.lift_system.position)

-- camera --------------------------------------------
------------------------------------------------------

-- camera's frame reference
--
--             /z
--            /
--            ------- x
--            |
--            |y     in the camera's eye
--
-- robot's frame reference
--
--            z up of the robot
--       |     |
--       |---  |  / y left of the robot
--     __|_    | /
--    |____|   |/
--     +  +    ------- x  in front of the robot

--robot.camera_system.tags
-- tags = an array of tags
-- a tag has
--    position    = a vector3     -- in camera's frame reference
--    orientation = a quternion   -- in camera's frame reference
--    center and corners
--       2D information, not important for now

--builderbot_api.blocks
-- blocks = an array of blocks
-- a block has
--    position    = a vector3
--    orientation = a quternion   -- in camera's frame reference
--    X, Y, Z:  three vector3 (in camera's eye)
--       showing the axis of a block :
--
--           |Z           Z| /Y       the one pointing up is Z
--           |__ Y         |/         the nearest one pointing towards the camera is X
--           /              \         and then Y follows right hand coordinate system
--         X/                \X
--
--    position_robot    = a vector3
--    orientation_robot = a quternion  in robot's frame reference
--    tags = an array of tags pointers, each pointing to the tags array

builderbot_api.camera_orientation = robot.camera_system.transform.orientation
-- this number is updated by process_positions
builderbot_api.camera_position = robot.camera_system.transform.position + builderbot_api.end_effector_position

builderbot_api.subprocess_leds = function()
   -- takes tags in camera_frame_reference
   local led_dis = 0.02 -- distance between leds to the center
   local led_loc_for_tag = {
      vector3(led_dis, 0, 0),
      vector3(0, led_dis, 0),
      vector3(-led_dis, 0, 0),
      vector3(0, -led_dis, 0)
   } -- from x+, counter-closewise

   for i, block in ipairs(builderbot_api.blocks) do
      for j, tag in pairs(block.tags) do
         tag.type = 0
         block.type = 0
         for j, led_loc in ipairs(led_loc_for_tag) do
            local led_loc_for_camera = vector3(led_loc):rotate(tag.orientation) + tag.position
            local color_number = robot.camera_system.detect_led(led_loc_for_camera)
            if color_number ~= tag.type and color_number ~= 0 then
               tag.type = color_number
               block.type = tag.type
            end
         end
      end
   end
end

builderbot_api.process_blocks = function()
   -- track block
   if builderbot_api.blocks == nil then
      builderbot_api.blocks = {}
   end
   BlockTracking(builderbot_api.blocks, robot.camera_system.tags)
   -- figure out led color for tags
   builderbot_api.subprocess_leds()
   -- transfer block to robot frame
   for i, block in pairs(builderbot_api.blocks) do
      block.position_robot =
         vector3(block.position):rotate(builderbot_api.camera_orientation) + builderbot_api.camera_position
      block.orientation_robot = builderbot_api.camera_orientation * block.orientation
   end
end

-- process positions ---------------------------------
------------------------------------------------------
builderbot_api.process_positions = function()
   builderbot_api.end_effector_position =
      builderbot_api.consts.end_effector_position_offset + vector3(0, 0, robot.lift_system.position)
   builderbot_api.camera_position = builderbot_api.end_effector_position + robot.camera_system.transform.position
end

-- process obstacles ---------------------------------
------------------------------------------------------
-- builderbot_api.obstacles = array of obstacles
--    an obstacle has
--       position = vector3
--       distance = how far away from the rangefinder
--       TODO: the rangefinder that discovers it
builderbot_api.process_obstacles = function()
   builderbot_api.possible_obstacles = {}
   for i, rf in pairs(robot.rangefinders) do
      if rf.proximity >= builderbot_api.parameters.proximity_maximum_distace then
         rf.proximity = 9999
      end
      local obstacle_position_robot =
         vector3(0, 0, rf.proximity):rotate(rf.transform.orientation) + rf.transform.position
      if rf.transform.anchor == 'end_effector' then
         obstacle_position_robot = obstacle_position_robot + builderbot_api.end_effector_position
      end
      builderbot_api.possible_obstacles[#builderbot_api.possible_obstacles + 1] = {
         position = obstacle_position_robot,
         source = tostring(i)
      }
   end
   for i, block in ipairs(api.blocks) do
      builderbot_api.possible_obstacles[#builderbot_api.possible_obstacles + 1] = {
         position = block.position_robot,
         source = 'camera'
      }
   end
end


builderbot_api.process_lights = function()
   function exists(items, studied_item)
      for index, value in pairs(items) do
         if value == studied_item then
            return true
         end
      end

      return false
   end
   builderbot_api.light_source = {}
   light_threshold = 0.35
   -- range_finders_illuminance = {}
   for i, rf in pairs(robot.rangefinders) do
      -- print(tostring(robot.id),tostring(i), tostring(rf.illuminance))
      if i == "1" and rf.illuminance > light_threshold and exists(builderbot_api.light_source,"front") ~= true then 
         builderbot_api.light_source[#builderbot_api.light_source+1] = "front"
      elseif i == "3" and rf.illuminance > light_threshold and exists(builderbot_api.light_source,"right") ~= true then 
         builderbot_api.light_source[#builderbot_api.light_source+1] = "right"
      elseif i == "4" and rf.illuminance > light_threshold and exists(builderbot_api.light_source,"right") ~= true then 
         builderbot_api.light_source[#builderbot_api.light_source+1] = "right"
      elseif i == "6" and rf.illuminance > light_threshold and exists(builderbot_api.light_source,"back") ~= true then 
         builderbot_api.light_source[#builderbot_api.light_source+1] = "back"
      elseif i == "7" and rf.illuminance > light_threshold and exists(builderbot_api.light_source,"back") ~= true then 
         builderbot_api.light_source[#builderbot_api.light_source+1] = "back"
      elseif i == "9" and rf.illuminance > light_threshold and exists(builderbot_api.light_source,"left") ~= true then 
         builderbot_api.light_source[#builderbot_api.light_source+1] = "left"
      elseif i == "10" and rf.illuminance > light_threshold and exists(builderbot_api.light_source,"left") ~= true then 
         builderbot_api.light_source[#builderbot_api.light_source+1] = "left"
      elseif i == "12" and rf.illuminance > light_threshold and exists(builderbot_api.light_source,"front") ~= true then 
         builderbot_api.light_source[#builderbot_api.light_source+1] = "front"
      end
   end
   
end

-- process for each step -----------------------------
------------------------------------------------------

builderbot_api.process = function()
   builderbot_api.process_time()
   builderbot_api.process_positions()
   -- process blocks and obstacle should happen after process positions
   builderbot_api.process_blocks()
   builderbot_api.process_obstacles()
   builderbot_api.process_lights()
end

-- debug arrow ---------------------------------------
------------------------------------------------------
builderbot_api.debug_arrow = function(color, from, to)
   if robot.debug == nil then
      return
   end

   robot.debug.draw('arrow(' .. color .. ')(' .. from:__tostring() .. ')(' .. to:__tostring() .. ')')
end

return builderbot_api
