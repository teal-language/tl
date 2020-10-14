local util = require("spec.util")

describe("empty table without type annotation", function()
   it("an empty return produces no type information (regression test for #234)", util.check_type_error([[
      local function heyyyy()
      end

      local ret_value = {heyyyy()}
      table.unpack(ret_value)
   ]], {
      { msg = "cannot determine type of array elements" },
   }))

   it("has its type determined by its first use", util.check_type_error([[
      local t = {}
      for i = 1, 10 do
         t[i] = i * 10
      end

      t.foo = "bar"
   ]], {
      { msg = "cannot index something that is not a record: {number}" },
   }))

   it("first use can be a function call", util.check [[
      local files = {}
      local pd = io.popen("git diff-tree -r HEAD", "r")
      for line in pd:lines() do
         local mode, file = line:match("^[^%s]+ [^%s]+ [^%s]+ [^%s]+ (.)\t(.-)$")
         if mode and file then
            table.insert(files, { mode = mode, file = file })
         end
      end

      for i, f in ipairs(files) do
         print(f.mode, f.file)
      end
   ]])

   it("has its type determined by its first reassignment", util.check [[
      local function return_arr(): {number}
         local t = {}
         local arr = {1,2,3}
         if 2 < 3 then
            t = arr
         end
         return t
      end
   ]])

   it("cannot be reassigned to a non-table", util.check_type_error([[
      local function return_arr(): {number}
         local t = {}
         local arr = {1,2,3}
         if 2 < 3 then
            t = 12
         end
         return t
      end
   ]], {
      { msg = "assigning number to a variable declared with {}" },
   }))

   it("preserves provenance information", util.check_type_error([[
      local function return_arr(): {number}
         local t = {}
         local arr = {1,2,3}
         if 2 < 3 then
            t = arr
         end
         t.foo = "bar"
         return t
      end
   ]], {
      { msg = "cannot index something that is not a record: {number} (inferred at foo.tl:5:" },
   }))
end)
