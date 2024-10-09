local tl = require("tl")
local util = require("spec.util")

local function trim_code(c)
   return c:gsub("^%s*", ""):gsub("\n%s*", "\n"):gsub("%s*$", "")
end

describe("not", function()
   it("ok with any type", util.check([[
      local x = 1
      local y = 2
      local z = true
      if not x then
         z = false
      end
   ]]))

   it("ok with not not", util.check([[
      local x = true
      local z: boolean = not not x
   ]]))

   it("not not casts to boolean", util.check([[
      local i = 12
      local z: boolean = not not 12
   ]]))

   it("handles precedence of sequential unaries correctly", function()
      local code = [[
         local y = not -a == not -b
         local x = not not a == not not b
      ]]

      local result = tl.process_string(code)
      local output = tl.pretty_print_ast(result.ast, true)

      assert.same(trim_code(code), trim_code(output))
   end)

   it("handles complex expression with not", function()
      local code = [[
         if t1.typevar == t2.typevar and
            (not not typevars or
            not not typevars[t1.typevar] == not typevars[t2.typevar]) then
            return true
         end
         if t1.typevar == t2.typevar and
            (not typevars or
            not not typevars[t1.typevar] == not not typevars[t2.typevar]) then
            return true
         end
      ]]

      local result = tl.process_string(code)
      local output = tl.pretty_print_ast(result.ast, true)

      assert.same(trim_code(code), trim_code(output))
   end)

end)
