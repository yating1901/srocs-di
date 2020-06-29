function ShowTable(table, number, skipindex)
   -- number means how many indents when printing
   if number == nil then number = 0 end
   if type(table) ~= "table" then return nil end

   for i, v in pairs(table) do
      local str = ""
      for j = 1, number do
         str = str .. "\t"
      end

      str = str .. tostring(i) .. "\t"

      if i == skipindex then
         print(str .. "SKIPPED")
      else
         if type(v) == "table" then
            print(str)
            ShowTable(v, number + 1, skipindex)
         else
            str = str .. tostring(v)
            print(str)
         end
      end
   end
end

