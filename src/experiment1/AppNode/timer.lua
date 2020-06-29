local create_timer_node = function(para)
   -- para = {time, func}
   -- count from 0, to para.time, with increment of api.time_period
   -- each step do para.func()
   -- need to do api.process_time everytime
   local current, time, func
   return {
      type = "sequence*",
      children = {
         function()
            current = 0
            time = para.time
            func = para.func
            return false, true
         end,
         function()
            current = current + api.time_period
            if current > time then
               return false, true
            else
               if type(func) == "function" then func() end
               return true
            end
         end,
      },
   }
end

return create_timer_node
