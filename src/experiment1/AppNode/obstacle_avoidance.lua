if DebugMSG == nil then
   DebugMSG = require('DebugMessage')
end
DebugMSG.register('obstacle_avoidance')

if api == nil then
   api = require('BuilderBotAPI')
end
local create_timer_node = require('timer')

-- if there are obstacles avoid it and return running
-- if there no obstacles, return true
local create_obstacle_avoidance_node = function()
   return {
      type = 'selector*',
      children = {
         -- no obstacle?
         function()
            local flag = false
            -- DebugMSG('obstacles')
            -- DebugMSG(api.possible_obstacles)
            
            for i, v in ipairs(api.possible_obstacles) do
               -- pprint.pprint(v)
               if v.position.x < 0.19 and v.position.x > 0.06 then
                  if v.source == 'camera' then
                     -- print("camera")
                     flag = true
                     break
                  elseif v.source == 'left' or v.source == 'right' then
                     if robot.rangefinders['underneath'].proximity > api.parameters.proximity_touch_tolerance then
                        if robot.lift_system.position < api.parameters.lift_system_rf_cover_threshold then
                           -- print('left right maip down normal')

                           flag = true
                           break
                        end
                     end
                  elseif v.source == '1' or v.source == '12' then
                     if robot.lift_system.position >= api.parameters.lift_system_rf_cover_threshold then
                        -- print('1 12 manip up')
                        -- pprint.pprint(v)
                        flag = true
                        break
                     end
                  elseif v.source == '2' or v.source == '11' then
                     -- print('2 11 normal')

                     flag = true
                     break
    
                  end
               end
            end
            if flag == true then
               return false, false
            else
               return false, true
            end
         end,
         -- avoid
         {
            type = 'sequence*',
            children = {
               -- backup 8 cm
               app.create_timer_node(
                  {
                     time = 0.08 / 0.005,
                     func = function()
                        api.move(-0.005, -0.005)
                     end
                  }
               ),
               -- turn 180
               create_timer_node(
                  {
                     time = 90 / 5,
                     func = function()
                        api.move_with_bearing(0, 5)
                     end
                  }
               )
            }
         }
      }
   }
end

return create_obstacle_avoidance_node
