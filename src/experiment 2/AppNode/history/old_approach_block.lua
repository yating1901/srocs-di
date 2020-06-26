if api == nil then api = require('BuilderBotAPI') end

local create_aim_block_node = require("aim_block")

local create_approach_block_node = function(target, _distance)
   -- approach the target reference block until _distance away 

   local aim_point = {}
   local aim_case
   local forward_case
   return 
-- return the following table
{
   type = "sequence",
   children = {
      -- check the target block is still there 
      function()
         if target == nil or 
            target.reference_id == nil or 
            api.blocks[target.reference_id] == nil then
            DebugMSG("approach: block is nil")
            api.move(0,0)
            return false, false
         else
            DebugMSG("approach: block is not nil")
            return false, true
         end
      end,
      -- I have the target block, approach it
      {
         type = "sequence",
         children = {
         {
            type = "sequence*",
            children = {
            -- analyze the status of the block
            function()
               local target_block = api.blocks[target.reference_id]
               local robot_to_block = vector3(-target_block.position_robot):rotate(target_block.orientation_robot:inverse())
               local angle = math.atan(robot_to_block.y / robot_to_block.x) * 180 / math.pi
               DebugMSG("angle = ", angle)
               local tolerance = api.parameters.aim_block_angle_tolerance
               if aim_case == nil and angle > tolerance then aim_case = "right"
               elseif aim_case == nil and angle < -tolerance then aim_case = "left"
               elseif aim_case == "left" and angle > -tolerance/2 then aim_case = nil
               elseif aim_case == "right" and angle < tolerance/2 then aim_case = nil
               end

               local target_distance = _distance
               local tolerence = api.parameters.block_position_tolerance
               local default_speed = api.parameters.default_speed
               if target_block.position_robot.x > target_distance - tolerence and 
                  target_block.position_robot.x < target_distance + tolerence then
                  if aim_point.case == nil then
                     move_case = nil
                  else
                     move_case = "backup"
                     if aim_case == "left" then aim_point.case = "right" end
                     if aim_case == "right" then aim_point.case = "left" end
                     return false, false
                  end
               elseif target_block.position_robot.x < target_distance - tolerence then
                  move_case = "backup"
                  if aim_case == "left" then aim_point.case = "right" end
                  if aim_case == "right" then aim_point.case = "left" end
               elseif target_block.position_robot.x > target_distance + tolerence then
                  move_case = "forward"
                  aim_point.case = aim_case
               end
               DebugMSG("aim_case = ", aim_case)
               DebugMSG("aim_point.case = ", aim_point.case)
               DebugMSG("move_case = ", move_case)
               return false, true
            end,
            -- aim block, put the block into the center of the image
            create_aim_block_node(target, aim_point),
            }
         },
            -- go to the pre-position
            function()
               local default_speed = api.parameters.default_speed
               DebugMSG("approach: approaching pre-position")
               if move_case == "forward" then
                  api.move(default_speed, default_speed)
                  return true
               elseif move_case == "backup" then
                  api.move(-default_speed, -default_speed)
                  return true
               elseif move_case == nil then
                  api.move(0, 0)
                  return false, true
               else
                  DebugMSG('wow this case should not exist')
               end
            end,
         },
      },
   }, -- end of the children of approach_block_node
} -- end of approach_block_node

end
return create_approach_block_node
