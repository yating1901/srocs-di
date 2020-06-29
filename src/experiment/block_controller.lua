-- load the interface
user_code = require('block_usercode')

clock = 0

function init()
   -- init the clock
   clock = 0
   -- init the simulated nfc controllers
   for id, radio in pairs(robot.radios) do
      radio.initiator_policy = "disable"
      radio.role = "target"
   end
   -- init user code
   user_code.init()
end

function step()
   -- step the clock
   clock = clock + 1
   -- step the simulated nfc controllers
   for identifier, radio in pairs(robot.radios) do
      if #radio.rx_data > 0 then
         if radio.role == "target" then
            if radio.rx_as_target then
               radio.rx_as_target(identifier, radio.rx_data)
            end
            if radio.tx_as_target then
               radio.tx_data(radio.tx_as_target(identifier))
            else
               radio.tx_data({})
            end
         elseif radio.role == "initiator" then
            if radio.rx_as_initiator then
               radio.rx_as_initiator(identifier, radio.rx_data)
            end
         end
      elseif radio.initiator_policy ~= "disable" then
         radio.role = "initiator"
         if radio.initiator_policy == "once" then
            radio.initiator_policy = "disable"
         end
         if radio.tx_as_initiator then
            radio.tx_data(radio.tx_as_initiator(identifier))
         else
            radio.tx_data({})
         end
      end
   end
   -- step user code
   user_code.step(clock)
end

function reset()
   -- recall init()
   init()
end

function destroy()
end
