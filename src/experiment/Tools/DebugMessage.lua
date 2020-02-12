local DebugMessage = {}
DebugMessage.mt = {}
setmetatable(DebugMessage, DebugMessage.mt)

-- call DebugMessage(...)
function DebugMessage.mt:__call(a, ...)
	local info = debug.getinfo(2)
   local src = info.short_src
   local moduleName = DebugMessage.modules[src]
   if moduleName == nil then moduleName = "nil" end
   if DebugMessage.switches[moduleName] == true then
      --print("DebugMSG:\t" .. moduleName .. ":" .. info.currentline .. "\t", ...)
      if type(a) == "table" then
         DebugMessage.ShowTable(a, ...)
      else
         print("DebugMSG:\t", a, ...)
      end
   end
end

DebugMessage.modules = {}
DebugMessage.switches = {}
DebugMessage.switches["nil"] = false

function DebugMessage.register(moduleName)
	local info = debug.getinfo(2)
   local src = info.short_src
   DebugMessage.modules[src] = moduleName
   DebugMessage.switches[moduleName] = false
end

function DebugMessage.disable(moduleName)
   if moduleName == nil then
      for i, v in pairs(DebugMessage.switches) do
         DebugMessage.switches[i] = false
         DebugMessage.switches["nil"] = false
      end
   else
      DebugMessage.switches[moduleName] = false
   end
end

function DebugMessage.enable(moduleName)
   if moduleName == nil then
      for i, v in pairs(DebugMessage.switches) do
         DebugMessage.switches[i] = true
         DebugMessage.switches["nil"] = true
      end
   else
      DebugMessage.switches[moduleName] = true
   end
end

function DebugMessage.ShowTable(table, number, skipindex)
   -- number means how many indents when printing
   if number == nil then number = 0 end
   if type(table) ~= "table" then return nil end

   for i, v in pairs(table) do
      local str = "DebugMSG:\t\t"
      for j = 1, number do
         str = str .. "\t"
      end

      str = str .. tostring(i) .. "\t"

      if i == skipindex then
         print(str .. "SKIPPED")
      else
         if type(v) == "table" then
            print(str)
            DebugMessage.ShowTable(v, number + 1, skipindex)
         else
            str = str .. tostring(v)
            print(str)
         end
      end
   end
end

return DebugMessage
