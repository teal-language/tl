
local util = require("spec.util")
describe("tl ast", function()
   setup(util.chdir_setup)
   teardown(util.chdir_teardown)
   describe("on .tl files", function()
      it("Test tl ast, reports nothing if no errors, runs and returns code 0 on success", function()
         local name = util.write_tmp_file(finally, "add.tl", [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add(10, 20))
         ]])
         local pd = io.popen("./tl ast " .. name, "r")
         assert(pd ~= nil, 'not nil')
         util.assert_popen_close(true, "exit", 0, pd:close())
      end)
   end)
end)

