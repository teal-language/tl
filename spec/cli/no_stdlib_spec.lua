local assert = require("luassert")
local util = require("spec.util")

describe("--no-stdlib argument", function()
   it("prevents the Lua stdlib from being used", function()
      util.do_in(util.write_tmp_dir(finally, {
         ["test.tl"] = [[
            print("hello world")
         ]],
      }), function()
         local pd = io.popen(util.tl_cmd("check", "--no-stdlib", "test.tl") .. " 2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match("1 error:", output, 1, true)
      end)
   end)

   it("reads no_std from tlconfig.lua", function()
      util.do_in(util.write_tmp_dir(finally, {
         ["test.tl"] = [[
            print("hello world")
         ]],
         ["tlconfig.lua"] = [[
               return {
                  no_stdlib = true,
               }
            ]],
      }), function()
         local pd = io.popen(util.tl_cmd("check", "test.tl") .. " 2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match("1 error:", output, 1, true)
      end)
   end)

   it("keeps prelude available when --no-stdlib is used", function()
      util.do_in(util.write_tmp_dir(finally, {
         ["test.tl"] = [[
            local function id(x: any): any return x end
            local record Rec end
            local rec_mt: metatable<Rec>
         ]],
      }), function()
         local pd = io.popen(util.tl_cmd("check", "--no-stdlib", "test.tl") .. " 2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         assert.match("2 warnings", output, 1, t1, true)
         -- 2 warnings:
         -- test.tl:1:13: unused function id: function(<any type>): <any type>
         -- test.tl:3:19: unused variable rec_mt: metatable<Rec>
      end)
   end)
end)
