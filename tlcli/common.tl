local record common
   sep: string
end

common.sep = package.config:sub(1, 1)

function common.keys<A, B>(m: {A:B}):{A}
   local keys = {}
   for k, _ in pairs(m) do
      table.insert(keys, k)
   end
   table.sort(keys)
   return keys
end

function common.get_output_filename(file_name: string): string
   if file_name == "-" then return "-" end
   local tail = file_name:match("[^%" .. common.sep .. "]+$")
   if not tail then
      return
   end
   local name, ext = tail:match("(.+)%.([a-zA-Z]+)$")
   if not name then name = tail end
   if ext ~= "lua" then
      return name .. ".lua"
   else
      return name .. ".out.lua"
   end
end

function common.printerr(s: string)
   io.stderr:write(s .. "\n")
end

function common.die(msg: string)
   common.printerr(msg)
   os.exit(1)
end

return common
