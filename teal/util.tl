--------------------------------------------------------------------------------
-- General algorithm utilities module, with no other dependencies
--------------------------------------------------------------------------------
local record util
end

function util.normalize_path(filename: string): string, string
   local function split_drive(filename: string): string, string
      local drive, rest = filename:match("^([A-Za-z]:)(.*)$")
      if drive then
         return drive, rest
      end
      return "", filename
   end

   local function cd(): string
      local ok, popen = pcall(io.popen, "cd")
      if not ok then
         return "."
      end
      local current = popen:read("*l")
      popen:close()
      return current or "."
   end

   local drive = ""
   local sep = package.config:sub(1, 1)

   if sep == "\\" then
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

   if sep == "\\" then
      filename = filename:gsub("/", "\\")
   end

   return filename, drive .. sep
end

function util.binary_search<T, U>(list: {T}, item: U, cmp: function(T, U): boolean): integer, T
   local len <const> = #list
   local mid: integer
   local s, e = 1, len
   while s <= e do
      mid = math.floor((s + e) / 2)
      local val <const> = list[mid]
      local res <const> = cmp(val, item)
      if res then
         if mid == len then
            return mid, val
         else
            if not cmp(list[mid + 1], item) then
               return mid, val
            end
         end
         s = mid + 1
      else
         e = mid - 1
      end
   end
end

function util.shallow_copy_table<T>(t: T): T
   local copy: {any:any} = {}
   for k, v in pairs(t as {any:any}) do
      copy[k] = v
   end
   return copy as T
end

function util.sorted_keys<A,B>(m: {A:B}):{A}
   local keys = {}
   for k, _ in pairs(m) do
      table.insert(keys, k)
   end
   table.sort(keys)
   return keys
end

return util
