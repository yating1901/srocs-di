if DebugMSG == nil then DebugMSG = require('DebugMessage') end
DebugMSG.register("approach_block")

if api == nil then api = require('BuilderBotAPI') end

local create_Z_shape_approach_block_node = require("Z_shape_approach_block")
local create_curved_approach_block_node = require("curved_approach_block")

local create_approach_block_node = function(search_node, target, distance)
   return -- return the following table
{
   type = "sequence*",
   children = {
      -- search block
      search_node,
      -- check range and blind approach and search again
      {
         type = "selector*",
         children = {
            -- check range
            function()
               local target_block = api.blocks[target.reference_id]
               local robot_to_block = vector3(-target_block.position_robot):rotate(target_block.orientation_robot:inverse())
               local angle = math.atan(robot_to_block.y / robot_to_block.x) * 180 / math.pi
               local blind_tolerance = 20
               if angle < blind_tolerance and angle > -blind_tolerance and robot_to_block:length() < 0.27 then 
                  return false, true
               else
                  return false, false
               end
            end,
            -- not in range, blind approach and search
            {
               type = "sequence*",
               children = {
                  create_Z_shape_approach_block_node(target, distance + 0.05),
                  function() print("in approach_node, before search") return false, true end,
                  search_node,
                  function() print("in approach_node, after search") return false, true end,
               },
            }, 
         }, -- end of chilren
      }, -- end of check range and blind approach and search again
      -- now should be in range, curved approach
      create_curved_approach_block_node(target, distance)
   }, -- end of children of the return table
} -- end of the return table
end

return create_approach_block_node
