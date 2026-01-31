local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local table = _tl_compat and _tl_compat.table or table


local util = {}

function util.normalize_path(filename)
   local function split_drive(filename)
      local drive, rest = filename:match("^([A-Za-z]:)(.*)$")
      if drive then
         return drive, rest
      end
      return "", filename
   end

   local function cd()
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

function util.binary_search(list, item, cmp)
   local len = #list
   local mid
   local s, e = 1, len
   while s <= e do
      mid = math.floor((s + e) / 2)
      local val = list[mid]
      local res = cmp(val, item)
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

function util.shallow_copy_table(t)
   local copy = {}
   for k, v in pairs(t) do
      copy[k] = v
   end
   return copy
end

function util.sorted_keys(m)
   local keys = {}
   for k, _ in pairs(m) do
      table.insert(keys, k)
   end
   table.sort(keys)
   return keys
end

return util