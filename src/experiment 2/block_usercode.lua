local user_code = {}
require "bit32"
-- Set Face Color --
user_code.set_face_color = function(face, color)
   if face == "north" then
      robot.directional_leds.set_single_color(1, color)
      robot.directional_leds.set_single_color(2, color)
      robot.directional_leds.set_single_color(3, color)
      robot.directional_leds.set_single_color(4, color)
   elseif face == "east" then
      robot.directional_leds.set_single_color(5, color)
      robot.directional_leds.set_single_color(6, color)
      robot.directional_leds.set_single_color(7, color)
      robot.directional_leds.set_single_color(8, color)
   elseif face == "south" then
      robot.directional_leds.set_single_color(9, color)
      robot.directional_leds.set_single_color(10, color)
      robot.directional_leds.set_single_color(11, color)
      robot.directional_leds.set_single_color(12, color)
   elseif face == "west" then
      robot.directional_leds.set_single_color(13, color)
      robot.directional_leds.set_single_color(14, color)
      robot.directional_leds.set_single_color(15, color)
      robot.directional_leds.set_single_color(16, color)
   elseif face == "top" then
      robot.directional_leds.set_single_color(17, color)
      robot.directional_leds.set_single_color(18, color)
      robot.directional_leds.set_single_color(19, color)
      robot.directional_leds.set_single_color(20, color)
   elseif face == "bottom" then
      robot.directional_leds.set_single_color(21, color)
      robot.directional_leds.set_single_color(22, color)
      robot.directional_leds.set_single_color(23, color)
      robot.directional_leds.set_single_color(24, color)
   end
end
--extend tree--
function user_code.extend_tree()
   --robot.directional_leds.set_all_colors("blue")
   robot.branch_data = {15,2,0,2,0,2,0,2,0}
   --print("#robot.branch_data", length)
   --print("#user_code.tx_as_target", #user_code.tx_as_target)
end
--define tree structure--
user_code.tree={15,0,0,0,0}
--assign number to faces--
user_code.face_to_number = {
   north  = 1,
   east   = 2,
   south  = 3,
   west   = 4,
   top    = 5,
   bottom = 6,
}

user_code.num_to_face = {
   "north", "east", "south", "west", "top", "bottom"
}

user_code.face_to_order={}
--store directed faces--
user_code.order_to_face = {}
function user_code.set_directed_faces(identifier)
   -- assume the Top face is forever "top" --
   map={1, 2, 3, 4, 1, 2}  --surrounded face would be north,east,south,west
   face_number = user_code.face_to_number[identifier]
   
   user_code.order_to_face[4]   = identifier                                   --parent
   user_code.order_to_face[3]   = user_code.num_to_face[map[face_number + 1]]  --left
   user_code.order_to_face[2]   = user_code.num_to_face[map[face_number + 2]]  --front
   if face_number == 1 then
      user_code.order_to_face[1] = "west"   --parent face is north face, then right face is west face
   else
      user_code.order_to_face[1] = user_code.num_to_face[map[face_number - 1]]
   end
   user_code.order_to_face[5] = "top"
   user_code.order_to_face[6] = "bottom"

   for index = 1, 6 do 
      user_code.face_to_order[user_code.order_to_face[index]] = index
   end
end

--count the number of directly connected blocks
function user_code.count_children(internal_configuration)
   local num = 0
   for index = 1, 6 do
      if bit32.band(internal_configuration, bit32.lshift(1, index-1)) ~= 0 then
         num = num +1
      end
   end 
   --print("num", num)
   return num
end

-- Get one branch--
function user_code.get_one_branch(root_index)
   local start_index 
   start_index = root_index    
   local final_index
   final_index = start_index + user_code.count_children(robot.branch_data[start_index])

   while final_index ~= start_index do
      start_index = start_index + 1
      final_index = final_index + user_code.count_children(robot.branch_data[start_index])
   end
   --print("final_index", final_index)
   return final_index
end
-- allocate branch data for its child faces--
user_code.tx_as_initiator = {}
function user_code.allocate_branch()
   local start_index = 1
   order = {6,5,4,3,2,1}
   if #robot.branch_data > 0 then 
      for key, index in pairs(order) do
         if bit32.band(robot.branch_data[1], bit32.lshift(1, index-1)) ~= 0 then
            face_name = user_code.order_to_face[index]
            user_code.tx_as_initiator[face_name] = {}
            start_index = start_index + 1
            --print("start_index", start_index)
            last_index = user_code.get_one_branch(start_index)
            --print("last_index", last_index)
            if start_index <= #robot.branch_data then
               for branch_index = start_index, last_index do
                  table.insert(user_code.tx_as_initiator[face_name], robot.branch_data[branch_index])
                  --print(face_name, robot.branch_data[branch_index])
               end
            end
            start_index = last_index 
            if index ~= 5 then
               user_code.set_face_color(user_code.order_to_face[index],"magenta")
            else
               user_code.set_face_color(user_code.order_to_face[index],"orange")
            end
         end
      end
   end
end

function user_code.my_tx_as_initiator(identifier)
   sub_branch = {}
   if user_code.tx_as_initiator[identifier] ~= nil then 

      sub_branch = user_code.tx_as_initiator[identifier]
   end
   return sub_branch
end


function user_code.my_rx_as_target(identifier, data)
   -- get branch data for its own --
   robot.branch_data = {}
   for msg_index, message in ipairs(data) do
      for byte_index, byte in ipairs(message) do
         --print(robot.id, msg_index, byte_index, byte)
         table.insert(robot.branch_data, byte)
      end
   end
end

--response messages table--
user_code.initiatoe_rx_table={}
function user_code.my_rx_as_initiator(identifier, data)
   user_code.initiatoe_rx_table[identifier] = {}
   if #data>0 then
      for msg_index, message in ipairs(data) do
         for byte_index, byte in ipairs(message) do 
            table.insert(user_code.initiatoe_rx_table[identifier], byte)
         end
      end
      robot.radios[identifier].haschild= true
   end
end

-- parent face response functor
function user_code.my_tx_as_target(identifier) 
   return user_code.tx_as_target
end

--get the info of which faces has a child
user_code.tx_as_target={}
function user_code.collect_messages()
   robot.childstate = 0
   for identifier, radio in pairs(robot.radios) do
      if radio.haschild == true  then
         robot.childstate = bit32.bor(robot.childstate, bit32.lshift(1, user_code.face_to_order[identifier]-1))
      end
   end
   user_code.tx_as_target={}
   --collect in the order: R,F,L,T,B
   for index=1, 6 do
      --if index ~= 4 then  --exlcude parent face
         face_name = user_code.order_to_face[index]
         if user_code.initiatoe_rx_table[face_name] ~= nil then
            for msg_index, msg in pairs(user_code.initiatoe_rx_table[face_name]) do
               table.insert(user_code.tx_as_target,msg)
            end
         end
      --end
   end
   table.insert(user_code.tx_as_target, robot.childstate)  --internal configuration
end

-- init method --
function user_code.init()
   robot.isroot = false
   robot.blockstate = "Idle"
   robot.directional_leds.set_all_colors("black")
   robot.childstate = 0
   robot.branch_data = {} --should be an array

   -- define the root block
   if robot.id == "block0" then
      robot.isroot = true
      robot.radios["west"].parent = true
      robot.blockstate = "Query"
      user_code.set_directed_faces("west")
      robot.branch_data = user_code.tree
   end

   for id, radio in pairs(robot.radios) do
      radio.initiator_policy = "disable"
      radio.parent = false
      radio.haschild = false
      -- non-zero length payload shown in purple
      radio.tx_as_initiator = user_code.my_tx_as_initiator
      --radio.rx_as_initiator = function() end
      radio.rx_as_initiator = user_code.my_rx_as_initiator
      -- zero length payload shown in cyan
      --radio.tx_as_target = function() return {} end
      radio.tx_as_target = user_code.my_tx_as_target 
      radio.rx_as_target = user_code.my_rx_as_target
   end
end

-- step method --
function user_code.step(time)
  
   for identifier, radio in pairs(robot.radios) do
      if robot.blockstate == "Idle" then
         if radio.role == "target" and #radio.rx_data > 0 then
            if identifier == "bottom" or identifier == "up" then
               robot.blockstate = "Idle"
               radio.parent = false
               robot.directional_leds.set_all_colors("green")
            else
               radio.parent = true
               robot.blockstate = "Query"
               robot.branch_data = radio.rx_data
               user_code.set_directed_faces(identifier)
               break --One block only have one parent face--
            end
         end
      else
         robot.directional_leds.set_all_colors("green")
         user_code.collect_messages()
         user_code.allocate_branch()
         if radio.parent == false and robot.isroot == false then
            radio.initiator_policy = "once"
         end
         if robot.isroot == true then
            radio.initiator_policy = "once"
         end
      end
   end
   if robot.isroot == true then
      --check if the structure is completed--
      length = #robot.branch_data
      if #user_code.tx_as_target == length then 
         iscompleted = true
         for index = 1, length  do
            iscompleted =  iscompleted and (robot.branch_data[index] == user_code.tx_as_target[length + 1 - index])
         end
      end
      if iscompleted == true then
         user_code.extend_tree()
      end
   end
end

-- reset method --
function user_code.reset()
   
end

return user_code


-- if time % 9 == 0 then
--    robot.directional_leds.set_single_color(21,"blue")
-- end
--robot.radios["east"].initiator_policy = "once"