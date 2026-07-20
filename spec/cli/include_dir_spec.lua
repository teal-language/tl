local assert = require("luassert")
local util = require("spec.util")

describe("-I --include-dir argument", function()
   it("adds source_dir from tlconfig.lua without replacing include_dir", function()
      util.do_in(util.write_tmp_dir(finally, {
         include = {
            ["external.d.tl"] = [[
               local record External
                  name: string
               end

               return External
            ]],
         },
         src = {
            ["main.tl"] = [[
               local vec = require("vec")
               local type External = require("external")

               local value = vec(1, 2)
               local external: External = { name = "dependency" }
               print(value.x, value.y, external.name)
            ]],
            ["vec.tl"] = [[
               local record Vec
                  x: number
                  y: number
               end

               return function(x: number, y: number): Vec
                  return { x = x, y = y }
               end
            ]],
         },
         ["tlconfig.lua"] = [[
            return {
               include_dir = { "include" },
               source_dir = "src",
            }
         ]],
      }), function()
         local pd = io.popen(util.tl_cmd("check", "src/main.tl"), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         assert.match("0 errors detected", output, 1, true)
      end)
   end)

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
