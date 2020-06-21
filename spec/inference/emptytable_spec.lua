local tl = require("tl")

describe("empty table without type annotation", function()
   it("has its type determined by its first use", function()
      local tokens = tl.lex([[
         local t = {}
         for i = 1, 10 do
            t[i] = i * 10
         end

         t.foo = "bar"
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast, { filename = "test.lua" })
      assert.match("cannot index something that is not a record: {number}", errors[1].msg, 1, true)
   end)

   it("first use can be a function call", function()
      local tokens = tl.lex([[
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
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast, { filename = "test.lua" })
      assert.same({}, errors)
   end)

   it("has its type determined by its first reassignment", function()
      local tokens = tl.lex([[
         local function return_arr(): {number}
            local t = {}
            local arr = {1,2,3}
            if 2 < 3 then
               t = arr
            end
            return t
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast, { filename = "test.lua" })
      assert.same({}, errors)
   end)

   it("cannot be reassigned to a non-table", function()
      local tokens = tl.lex([[
         local function return_arr(): {number}
            local t = {}
            local arr = {1,2,3}
            if 2 < 3 then
               t = 12
            end
            return t
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast, { lax = false, filename = "test.lua" })
      assert.match("assigning number to a variable declared with {}", errors[1].msg, 1, true)
   end)

   it("preserves provenance information", function()
      local tokens = tl.lex([[
         local function return_arr(): {number}
            local t = {}
            local arr = {1,2,3}
            if 2 < 3 then
               t = arr
            end
            t.foo = "bar"
            return t
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast, { lax = false, filename = "test.lua" })
      assert.match("cannot index something that is not a record: {number} (inferred at test.lua:5:", errors[1].msg, 1, true)
   end)
end)
