local assert = require("luassert")
local util = require("spec.util")

describe("--no-std argument", function()
    it("prevent the Lua stdlib to be used", function()
        util.do_in(util.write_tmp_dir(finally, {
            ["test.tl"] = [[
                print("hello world")
            ]],
        }), function()
            local pd = io.popen(util.tl_cmd("check", "--no-std", "test.tl") .. " 2>&1 1>" .. util.os_null, "r")
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
                    no_std = true,
                }
            ]],
        }), function()
            local pd = io.popen(util.tl_cmd("check", "test.tl") .. " 2>&1 1>" .. util.os_null, "r")
            local output = pd:read("*a")
            util.assert_popen_close(1, pd:close())
            assert.match("1 error:", output, 1, true)
        end)
    end)
end)