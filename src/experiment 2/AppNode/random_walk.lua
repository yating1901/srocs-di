if DebugMSG == nil then
   DebugMSG = require('DebugMessage')
end
DebugMSG.register('random_walk')

if api == nil then
   api = require('BuilderBotAPI')
end

-- if there are obstacles avoid it and return running
-- if there no obstacles, return true
local create_random_walk_node = function()
   return {
      type = 'sequence',
      children = {
         function()
            local random_angle = math.random(-api.parameters.search_random_range, api.parameters.search_random_range)
            --api.move(-api.parameters.default_speed, api.parameters.default_speed)
            api.move_with_bearing(api.parameters.default_speed, random_angle)
            return true
         end
      }
   }
end

return create_random_walk_node
