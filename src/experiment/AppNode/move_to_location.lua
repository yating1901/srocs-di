if DebugMSG == nil then DebugMSG = require('DebugMessage') end
DebugMSG.register("move_to_location")
if api == nil then api = require('BuilderBotAPI') end

local create_timer_node = require("timer")

local create_move_to_location_node = function(location)
   -- move to the location (position and orientation) blindly
   --
   --       \       x
   --     th2\     |
   --    <----P    |         forward
   --          \   |
   --       dis \th|
   --            \ |
   --             \|
   --   y ---------------------
   --              |\
   --              | \       backup
   --              |  \   |
   --              |   \th|
   --              | th2\ |
   --              | <---\

   local th, dis, th2
   local turn_th_timer_parameter = {}
   local move_dis_timer_parameter = {}
   local turn_th2_timer_parameter = {}

   return 
-- return the following table
{
   type = "sequence*",
   children = {
      -- calculate th, dis, th2
      function()
         -- th
         local backup_mode = false
         if location.position.x == 0 then
            if location.position.y < 0 then th = -90
            elseif location.position.y > 0 then th = 90 end
         else
            th = math.atan(location.position.y / location.position.x) * 180 / math.pi
            if location.position.x < 0 then
               backup_mode = true
            end  
         end
         DebugMSG("th = ", th)
         local turnspeed = 3
         if th >= 0 then
            turn_th_timer_parameter.time = th / turnspeed
            turn_th_timer_parameter.func = function() api.move_with_bearing(0, turnspeed) end
         else
            turn_th_timer_parameter.time = -th / turnspeed
            turn_th_timer_parameter.func = function() api.move_with_bearing(0, -turnspeed) end
         end

         -- dis
         dis = math.sqrt(location.position.x ^ 2 + location.position.y ^ 2)
         move_dis_timer_parameter.time = dis / api.parameters.default_speed
         if backup_mode == false then
            move_dis_timer_parameter.func = function() api.move_with_bearing(api.parameters.default_speed, 0) end
         else
            move_dis_timer_parameter.func = function() api.move_with_bearing(-api.parameters.default_speed, 0) end
         end
         --move_dis_timer_parameter.func = function() api.move(api.parameters.default_speed, api.parameters.default_speed) end
         DebugMSG("dis = ", dis)

         -- th2   -- assume orientation is always around z axis
         local angle, axis = location.orientation:toangleaxis()
         -- reverse orientation if axis is pointing down
         if (axis - vector3(0,0,-1)):length() < 0.1 then
            axis = -axis
            angle = 2 * math.pi - angle
         end
         DebugMSG("angle = ", angle)
         angle = angle * 180 / math.pi  -- angle from 0 to 360
         DebugMSG("angle = ", angle)
         th2 = angle - th               -- th2 from -90 to 360 + 90
         if th2 > 180 then th2 = th2 - 360 end
         local turnspeed = 3
         if th2 >= 0 then
            turn_th2_timer_parameter.time = th2 / turnspeed
            turn_th2_timer_parameter.func = function() api.move_with_bearing(0, turnspeed) end
         else
            turn_th2_timer_parameter.time = -th2 / turnspeed
            turn_th2_timer_parameter.func = function() api.move_with_bearing(0, -turnspeed) end
         end
         DebugMSG("th2 = ", th2)

         robot.camera_system.disable()
         return false, true
      end,
      -- turn th
      function() DebugMSG("turn th") return false, true end,
      create_timer_node(turn_th_timer_parameter),
      -- move dis
      function() DebugMSG("move dis") return false, true end,
      create_timer_node(move_dis_timer_parameter),
      -- turn th2
      function() DebugMSG("turn th2") return false, true end,
      create_timer_node(turn_th2_timer_parameter),
      -- stop moving
      function() 
         api.move(0,0) 
         robot.camera_system.enable()
         return false, true 
      end,
   }, -- end of the children of go to pre-position
} -- end of go to pre-position

end
return create_move_to_location_node
