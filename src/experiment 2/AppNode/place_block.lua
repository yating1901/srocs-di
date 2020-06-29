if api == nil then api = require('BuilderBotAPI') end

local create_reach_block_node = require("reach_block")
local create_timer_node = require("timer")

local create_place_block_node = function(target, _forward_distance)
   -- assume I am _forward_distance away from the block
   -- shameful move blindly for that far (use reach_block node)
   -- anti release the electomagnet to drop the block

return -- return the following table
{
   type = "sequence*",
   children = {
      -- recharge
      function()
         robot.electromagnet_system.set_discharge_mode("disable")
      end,
      -- reach the block
      create_reach_block_node(target, _forward_distance),
      -- change color
      function()
         if target.type ~= nil then
            api.set_type(target.type)
         end
      end,
      -- drop electromagnet
      function()
         robot.electromagnet_system.set_discharge_mode("destructive")
         return false, true
      end,
      -- wait for 2 sec
      create_timer_node({time = 2,}),
      -- recharge magnet
      function()
         robot.electromagnet_system.set_discharge_mode("disable")
      end,
   },
}
end

return create_place_block_node
