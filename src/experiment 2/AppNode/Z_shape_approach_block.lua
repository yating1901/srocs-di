if DebugMSG == nil then DebugMSG = require('DebugMessage') end
DebugMSG.register("blind_approach_block")

if api == nil then api = require('BuilderBotAPI') end

local create_move_to_location_node = require("move_to_location")
local create_obstacle_avoidance_node = require("obstacle_avoidance")

local create_Z_shape_approach_block_node = function(target, _distance)
   -- approach the target reference block until _distance away 
   local location = {}
   return 
-- return the following table
{
   type = "sequence*",
   children = {
      -- calc location
      function()
         local target_block = api.blocks[target.reference_id]
         location.position = target_block.position_robot + vector3(1,0,0):rotate(target_block.orientation_robot) * _distance
         location.orientation = target_block.orientation_robot * quaternion(math.pi, vector3(0,0,1))
         return false, true
      end,
      -- move to the location
      {
         type = "sequence",
         children = {
            create_obstacle_avoidance_node(),
            create_move_to_location_node(location),
         }
      }
   }, -- end of the children of go to pre-position
} -- end of go to pre-position

end
return create_Z_shape_approach_block_node
