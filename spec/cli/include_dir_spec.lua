local assert = require("luassert")
local util = require("spec.util")

describe("-I --include-dir argument", function()
   it("adds a directory to package.path", function()
      util.do_in(util.write_tmp_dir(finally, {
         mod = {
            ["add.tl"] = [[
               local function add(n: number, m: number): number
                   return n + m
               end

               return add
            ]],
            ["subtract.tl"] = [[
               global function subtract(n: number, m: number): number
                   return n - m
               end
            ]],
         },
         ["test.tl"] = [[
            local add = require("add")
            local x: number = add(1, 2)

            assert(x == 3)

            require("subtract")
            local y: number = subtract(100, 90)

            assert(y == 10)
         ]],
      }), function()
         local pd = io.popen(util.tl_cmd("check", "-I", "mod", "test.tl"), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         assert.match("0 errors detected", output, 1, true)
      end)
   end)
   it("adds a directory to package.cpath", function()
      local name = util.write_tmp_file(finally, [[
         print(package.cpath:match("spec/cli/") ~= nil)
      ]])
      local pd = io.popen(util.tl_cmd("run", "-I", "spec/cli/", name), "r")
      local output = pd:read("*a")
      util.assert_popen_close(0, pd:close())
      util.assert_line_by_line([[
         true
      ]], output)
   end)
end)
