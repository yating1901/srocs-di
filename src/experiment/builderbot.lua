package.path = package.path .. ';Tools/?.lua'
package.path = package.path .. ';AppNode/?.lua'
DebugMSG = require('DebugMessage')
-- require('Debugger')

if api == nil then
   api = require('BuilderBotAPI')
end
if app == nil then
   app = require('ApplicationNode')
end
if rules == nil then
   rules = require(robot.params.rules)
end
local bt = require('luabt')

DebugMSG.enable()

--[[ This function is executed every time you press the 'execute' button ]]
function init()
   reset()
end


--[[ This function is executed every time you press the 'reset'
     button in the GUI. It is supposed to restore the state
     of the controller to whatever it was right after init() was
     called. The state of sensors and actuators is reset
     automatically by ARGoS. ]]
function reset()
   local BTDATA = {target = {}}
   -- bt init ---
   local bt_node = {
      type = 'sequence*',
      children = {
         -- pick up
         {
            type = "selector*",
            children = {
               -- am I holding a block? If yes, go to place
               function()
                  if robot.rangefinders['underneath'].proximity < api.parameters.proximity_touch_tolerance then
                     return false, true
                  else
                     return false, false
                  end
               end,
               -- pickup procedure
               {
                  type = "sequence*",
                  children = {
                     -- search
                     app.create_search_block_node(
                        app.create_process_rules_node(rules, 'pickup', BTDATA.target)
                     ),
                     -- approach
                     app.create_curved_approach_block_node(BTDATA.target, 0.2),
                     -- pickup 
                     app.create_pickup_block_node(BTDATA.target, 0.2),
                  },
               },
            },
         },
         -- place
         {
            type = "selector*",
            children = {
               -- Is my hand empty? If yes, go to pickup
               function()
                  if robot.rangefinders['underneath'].proximity > api.parameters.proximity_touch_tolerance then
                     return false, true
                  else
                     return false, false
                  end
               end,
               -- place procedure
               {
                  type = "sequence*",
                  children = {
                     -- search
                     app.create_search_block_node(
                        app.create_process_rules_node(rules, 'place', BTDATA.target)
                     ),
                     function()
                        DebugMSG("BTDATA.target, before approach")
                        DebugMSG(BTDATA.target)
                     end,
                     -- approach
                     app.create_curved_approach_block_node(BTDATA.target, 0.20),
                     function()
                        DebugMSG("BTDATA.target, after approach")
                        DebugMSG(BTDATA.target)
                     end,
                     -- place
                     app.create_place_block_node(BTDATA.target, 0.20),
                     -- backup
                     app.create_timer_node{
                        time = 0.08 / 0.005,
                        func = function() api.move(-0.005, -0.005) end
                     },
                  },
               },
            },
         },
      },
   }
   behaviour = bt.create(bt_node)
   -- robot init ---
   robot.camera_system.enable()
end
local STATE = 'prepare'



--[[ This function is executed at each time step
     It must contain the logic of your controller ]]
function step()
   DebugMSG('-------- step begins ---------')
   robot.wifi.tx_data({robot.id})
   api.process()
   behaviour()
end


--[[ This function is executed only once, when the robot is removed
     from the simulation ]]
function destroy()
   -- put your code here
end
