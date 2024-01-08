local assert = require("luassert")
local util = require("spec.util")

local test_cases = {
   ["feat-arity"] = {
      {
         code = [[
            -- without '?' annotation
            local function add(a: number, b: number): number
               return a + (b or 0)
            end

            print(add())
            print(add(10))
            print(add(10, 20))
            print(add(10, 20, 30))

            -- with '?' annotation
            local function sub(a: number, b?: number): number
               return a - (b or 0)
            end

            print(sub())
            print(sub(10))
            print(sub(10, 20))
            print(sub(10, 20, 30))
         ]],
         values = {
            on = {
               describe = "allows defining minimum arities for functions based on optional argument annotations",
               status = 1,
               match = {
                  "5 errors:",
                  ":6:22: wrong number of arguments (given 0, expects 2)",
                  ":7:22: wrong number of arguments (given 1, expects 2)",
                  ":9:22: wrong number of arguments (given 3, expects 2)",
                  ":16:22: wrong number of arguments (given 0, expects at least 1 and at most 2)",
                  ":19:22: wrong number of arguments (given 3, expects at least 1 and at most 2)",
               },
            },
            off = {
               describe = "ignores missing arguments",
               status = 1,
               match = {
                  "2 errors:",
                  ":9:22: wrong number of arguments (given 3, expects 2)",
                  ":19:22: wrong number of arguments (given 3, expects at least 1 and at most 2)",
               }
            }
         }
      }
   }
}

describe("feat flags", function()
   for flag, tests in pairs(test_cases) do
      describe(flag, function()
         for _, case in ipairs(tests) do
            for value, data in pairs(case.values) do
               it("--" .. flag .. "=" .. value .. " " .. data.describe, function()
                  local name = util.write_tmp_file(finally, case.code)
                  local pd = io.popen(util.tl_cmd("check --" .. flag .. "=" .. value, name) .. "2>&1 1>" .. util.os_null, "r")
                  local output = pd:read("*a")
                  util.assert_popen_close(data.status, pd:close())
                  for _, s in ipairs(data.match) do
                     assert.match(s, output, 1, true)
                  end
               end)
            end
         end
      end)
   end
end)
