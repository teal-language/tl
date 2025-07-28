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

do
   local function split_drive(filename: string): string, string
      if common.sep == "\\" then
         local d, r = filename:match("^(.:)(.*)$")
         if d then
            return d, r
         end
      end
      return "", filename
   end

   local cd_cache: string
   local function cd(): string
      if cd_cache then
         return cd_cache
      end
      local wd = os.getenv("PWD")
      if not wd then
         local pd = io.popen("cd", "r")
         wd = pd:read("*l")
         pd:close()
      end
      cd_cache = wd
      return wd
   end

   function common.normalize(filename: string): string, string
      local drive = ""

      if common.sep == "\\" then
         filename = filename:gsub("\\", "/")
         drive, filename = split_drive(filename)
      end

      if filename:sub(1, 1) ~= "/" then
         filename = cd() .. "/" .. filename
         drive, filename = split_drive(filename)
      end

      local root = ""
      if filename:sub(1, 1) == "/" then
         root = "/"
      end

      local pieces = {}
      for piece in filename:gmatch("[^/]+") do
         if piece == ".." then
            local prev = pieces[#pieces]
            if not prev or prev == ".." then
               table.insert(pieces, "..")
            elseif prev ~= "" then
               table.remove(pieces)
            end
         elseif piece ~= "." then
            table.insert(pieces, piece)
         end
      end

      filename = (drive .. root .. table.concat(pieces, "/")):gsub("/*$", "")

      if common.sep == "\\" then
         filename = filename:gsub("/", "\\")
      end

      return filename, drive .. common.sep
   end
end

function common.get_output_filename(file_name: string, root?: string, outdir?: string, custom_ext?: string): string
   if file_name == "-" then return "-" end

   local tail: string
   if root then
      file_name = common.normalize(file_name)
      root = common.normalize(root)
      if file_name:sub(1, #root) == root then
         tail = file_name:sub(#root + 1):gsub("^" .. common.sep .. "+", "")
      end
   end
   if not tail then
      tail = file_name:match("[^%" .. common.sep .. "]+$")
   end
   if not tail then
      return
   end
   if outdir then
      tail = outdir .. common.sep .. tail
   end

   local name, ext = tail:match("(.+)%.([a-zA-Z]+)$")
   if not name then name = tail end

   if custom_ext then
      return name .. custom_ext
   elseif ext ~= "lua" then
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
