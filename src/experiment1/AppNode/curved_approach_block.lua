DebugMSG.register("curved_approach_block")
if api == nil then api = require('BuilderBotAPI') end

local create_aim_block_node = require("aim_block")
local create_obstacle_avoidance_node = require("obstacle_avoidance")

local create_curved_approach_block_node = function(target, target_distance)
   local case = {left_right_case = 0, forward_backup_case = 1,}
   local aim = {}
   return 
-- return the following table
{
   type = "sequence",
   children = {
      -- obstacle_avoidance
      create_obstacle_avoidance_node(),
      -- check the target block is still there 
      function()
         if target == nil or 
            target.reference_id == nil or 
            api.blocks[target.reference_id] == nil then
            DebugMSG("curved_approach: block is nil")
            api.move(0,0)
            return false, false
         else
            DebugMSG("curved_approach: block is not nil")
            return false, true
         end
      end,
      -- analyze block angle
      function()
         local target_block = api.blocks[target.reference_id]
         local robot_to_block = vector3(-target_block.position_robot):rotate(target_block.orientation_robot:inverse())
         local angle = math.atan(robot_to_block.y / robot_to_block.x) * 180 / math.pi
         DebugMSG("curved_approach: angle is ", angle)
         local tolerance = api.parameters.aim_block_angle_tolerance * 3

         if angle > 40 or angle < -40 then return false, false end

         if target_block.position_robot.x > target_distance + 0.05 then
            if case.left_right_case == 0 and angle > tolerance/2 then case.left_right_case = -1 -- right
            elseif case.left_right_case == 0 and angle < -tolerance/2 then case.left_right_case = 1 -- left
            elseif case.left_right_case == 1 and angle > -tolerance/4 then case.left_right_case = 0
            elseif case.left_right_case == -1 and angle < tolerance/4 then case.left_right_case = 0
            end
            case.done = false
         else
            if case.done == false and angle > tolerance/2 then case.left_right_case = -1 -- right
            elseif case.done == false and angle < -tolerance/2 then case.left_right_case = 1 -- left
            elseif case.left_right_case == 1 and angle > tolerance/6 and angle < tolerance/2 then case.left_right_case = 0 case.done = true
            elseif case.left_right_case == -1 and angle < -tolerance/6 and angle > -tolerance/2 then case.left_right_case = 0 case.done = true
            end
         end
         return false, true
      end,
      -- prepare aim
      function()
         if case.forward_backup_case == 1 and case.left_right_case == 1 or
            case.forward_backup_case == -1 and case.left_right_case == -1 then
            aim.case = "left"
         elseif case.forward_backup_case == 1 and case.left_right_case == -1 or
            case.forward_backup_case == -1 and case.left_right_case == 1 then
            aim.case = "right"
         elseif case.left_right_case == 0 then
            aim.case = nil
         end
         return false, true
      end,
      -- aim
      create_aim_block_node(target, aim),
      -- forward or backup
      function()
         local target_block = api.blocks[target.reference_id]
         local tolerence = api.parameters.block_position_tolerance
         local default_speed = api.parameters.default_speed

         DebugMSG(case)

         if case.forward_backup_case == 1 then
            -- forward case
            --if target_block.position_robot.x > target_distance - tolerence then
            if target_block.position_robot.x > target_distance then
               -- still too far away, move forward
               api.move(default_speed, default_speed)
               return true
            else
               -- close enough, check angle
               if case.left_right_case == 0 then
                  -- success
                  return false, true
               else
                  -- close enough, but wrong angle, switch to backup
                  case.forward_backup_case = -1
                  return true
               end
            end
         elseif case.forward_backup_case == -1 then
            -- backup case
            --if target_block.position_robot.x < target_distance + 0.03 + tolerence then
            if target_block.position_robot.x < target_distance + 0.04 then
               -- too close, keep move backward
               api.move(-default_speed, -default_speed)
               return true
            else
               -- far enough, forward again
               case.forward_backup_case = 1
               return true
            end
         end
      end,
   },
}
end
return create_curved_approach_block_node
