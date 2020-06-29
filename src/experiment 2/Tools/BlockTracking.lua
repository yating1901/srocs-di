----------------------------------------------------
-- Block tracking of BuilderBot
--
-- Author
--    Weixu Zhu,  Tutti mi chiamano Harry
--       zhuweixu_harry@126.com
-- 
----------------------------------------------------

local BLOCKLENGTH = 0.055
local Hungarian = require("Hungarian")

local function FindBlockXYZ(position, orientation) -- for camera
   --    this function finds axis of a block :    
   --         |Z           Z| /Y       the one pointing up is z
   --         |__ Y         |/         the nearest one pointing towards the camera is x
   --        /               \         and then y follows right hand coordinate system
   --      X/                 \X

   -- All vector in the system of the camera
   --             /z
   --            /
   --            ------- x
   --            |
   --            |y     in the camera's eye

   local X, Y, Z -- vectors of XYZ axis of a block (in camera's coor system) 

   -- all the 6 dirs of a block
   local dirs = {}
   dirs[1] = vector3(1,0,0)
   dirs[2] = vector3(0,1,0)
   dirs[3] = vector3(0,0,1)
   dirs[1]:rotate(orientation)
   dirs[2]:rotate(orientation)
   dirs[3]:rotate(orientation)
   dirs[4] = -dirs[1]
   dirs[5] = -dirs[2]
   dirs[6] = -dirs[3]

   -- clear out 3 pointing far away
   for i, v in pairs(dirs) do
      if v.z > 0 then dirs[i] = nil end
   end

   -- choose the one pointing highest(min y) as Z 
   local highestI 
   local highestY = 0
   for i, v in pairs(dirs) do
      if v.y < highestY then highestY = v.y highestI = i end
   end
   Z = dirs[highestI]
   dirs[highestI] = nil

   -- choose the one pointing nearest(min z) as X
   local nearestI 
   local nearestZ = 99999999999
   for i, v in pairs(dirs) do
      if (position + v):length() < nearestZ then nearestZ = (position + v):length(); nearestI = i end
   end
   X = dirs[nearestI]
   dirs[nearestI] = nil

   Y = vector3(Z):cross(X) -- stupid argos way of saying Y = Z * X

   return X, Y, Z  -- unit vectors
end

local function XYtoQuaternion(_orientation, _X, _Y)
   -- assume Z match
   -- from the XY to calculate the right quaternion
   local orientation = _orientation
   local x = vector3(1,0,0)
   x:rotate(orientation)
   if (x - _X):length() < 0.2 then     
      -- x match 
      return orientation
   elseif (x - _Y):length() < 0.2 then 
      -- x matches Y, rotate 90 clockwise
      return orientation * quaternion(-math.pi/2, vector3(0,0,1))
   elseif (x + _X):length() < 0.2 then 
      -- x matches -X, rotate 180 clockwise
      return orientation * quaternion(math.pi, vector3(0,0,1))
   elseif (x + _Y):length() < 0.2 then 
      -- x matches -Y, rotate 90 anti-clockwise
      return orientation * quaternion(math.pi/2, vector3(0,0,1))
   end
end

local function XYZtoQuaternion(_orientation, _X, _Y, _Z)
   -- from the XYZ to calculate the right quaternion
   local orientation = _orientation
   local x = vector3(1,0,0)
   local y = vector3(0,1,0)
   local z = vector3(0,0,1)
   x:rotate(orientation)
   y:rotate(orientation)
   z:rotate(orientation)
   if (z - _Z):length() < 0.2 then     
      -- z is up
      return XYtoQuaternion(orientation, _X, _Y)
   elseif (-z - _Z):length() < 0.2 then     
      -- -z is up, rotate 180 along x
      orientation = orientation * quaternion(math.pi, vector3(1,0,0))
      return XYtoQuaternion(orientation, _X, _Y)
   elseif (x - _Z):length() < 0.2 then     
      -- x is up, rotate a-clock 90 along y
      orientation = orientation * quaternion(math.pi/2, vector3(0,1,0))
      return XYtoQuaternion(orientation, _X, _Y)
   elseif (-x - _Z):length() < 0.2 then     
      -- -x is up, rotate clock 90 along y
      orientation = orientation * quaternion(-math.pi/2, vector3(0,1,0))
      return XYtoQuaternion(orientation, _X, _Y)
   elseif (y - _Z):length() < 0.2 then     
      -- y is up, rotate clock 90 along x
      orientation = orientation * quaternion(-math.pi/2, vector3(1,0,0))
      return XYtoQuaternion(orientation, _X, _Y)
   elseif (-y - _Z):length() < 0.2 then     
      -- y is up, rotate a-clock 90 along x
      orientation = orientation * quaternion(math.pi/2, vector3(1,0,0))
      return XYtoQuaternion(orientation, _X, _Y)
   end
end

local function UpdateBlock(oldBlock, newBlock)
   oldBlock.position = newBlock.position
   oldBlock.orientation = newBlock.orientation
   oldBlock.X = newBlock.X
   oldBlock.Y = newBlock.Y
   oldBlock.Z = newBlock.Z
   oldBlock.tags = newBlock.tags
end

local function HungarianMatch(_oldBlocks, _newBlocks)
   -- the index of _oldBlocks maybe not consistent, like 1, 2, 4, 6
   -- put it into oldBlockArray with 1,2,3,4
   local oldBlocksArray = {}
   local count = 0
   for i, block in pairs(_oldBlocks) do
      count = count + 1
      oldBlocksArray[count] = block
      oldBlocksArray[count].index = i
   end

   -- max size
   local n = #oldBlocksArray
   if #_newBlocks > n then n = #_newBlocks end

   -- set penalty matrix
      -- fill n * n with 0
   local penaltyMatrix = {}
   for i = 1, n do 
      penaltyMatrix[i] = {}
      for j = 1,n do 
         penaltyMatrix[i][j] = 0
      end
   end

   --                new blocks
   --             * * * * * * * *
   -- old blocks  *             *
   --             * * * * * * * *

   for i, oldB in ipairs(oldBlocksArray) do
      for j, newB in ipairs(_newBlocks) do
         local dis = (oldB.position - newB.position):length()
         penaltyMatrix[i][j] = dis + 0.1   -- 0.1 to make it not 0
      end
   end

   local hun = Hungarian:create{costMat = penaltyMatrix, MAXorMIN = "MIN"}
   hun:aug()
   -- hun.match_of_X[i] is the index of match for oldBlocksArray[i]

   for i, oldB in ipairs(oldBlocksArray) do
      if penaltyMatrix[i][hun.match_of_X[i]] == 0 then
         -- lost
         local index = oldB.index
         _oldBlocks[index] = nil
      else
         -- tracking
         local index = oldB.index
         --_oldBlocks[index] = _newBlocks[hun.match_of_X[i]]
         UpdateBlock(_oldBlocks[index], _newBlocks[hun.match_of_X[i]])
      end
   end

   local index = 1
   for j, newB in ipairs(_newBlocks) do
      if penaltyMatrix[hun.match_of_Y[j]][j] == 0 then
         -- new blocks
         while _oldBlocks[index] ~= nil do index = index + 1 end
         _oldBlocks[index] = newB
         _oldBlocks[index].id = index
      end
   end
end

function CheckTagDirection(block)
   for i, tag in ipairs(block.tags) do
      local dif = (tag.position - block.position) * (1/BLOCKLENGTH) * 2
      if (block.X - dif):length() < 0.5 then
         block.tags.front = tag
      elseif (block.Z - dif):length() < 0.5 then
         block.tags.up = tag
      elseif (block.Y - dif):length() < 0.5 then
         block.tags.right = tag
      elseif (-block.Y - dif):length() < 0.5 then
         block.tags.left = tag
      end
   end
   for i, tag in ipairs(block.tags) do
      block.tags[i] = nil
   end
end

function BlockTracking(_blocks, _tags)
   local blocks = {}

   -- cluster tags into blocks
   local p = vector3(0, 0, -BLOCKLENGTH/2)
   for i, tag in ipairs(_tags) do
      local middlePointV3 = vector3(p):rotate(tag.orientation) + tag.position

      -- find which block it belongs
      local flag = 0
      for j, block in ipairs(blocks) do
         if (middlePointV3 - block.position):length() < BLOCKLENGTH/3 then
            flag = 1
            block.tags[#block.tags + 1] = tag
            block.positionSum = block.positionSum + middlePointV3
            break
         end
      end
      if flag == 0 then
         blocks[#blocks + 1] = {position = middlePointV3, 
                                positionSum = middlePointV3,
                                orientation = tag.orientation,
                                tags = {tag},
                               }
      end
   end
   -- average block position
   for i, block in ipairs(blocks) do
      block.position = block.positionSum * (1/#block.tags)
      block.positionSum = nil
   end
   -- adjust block orientation
   for i, block in ipairs(blocks) do
      block.X, block.Y, block.Z = FindBlockXYZ(block.position, block.orientation)
         -- X,Y,Z are unit vectors
      block.orientation = XYZtoQuaternion(block.orientation, block.X, block.Y, block.Z)
         -- to make orientation matches X,Y,Z
      CheckTagDirection(block)
   end

   HungarianMatch(_blocks, blocks)
end

