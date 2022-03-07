local tl = require("tl")
local util = require("spec.util")

describe("tl.init_env", function()
   describe("preload_modules", function()
      it("should preload the modules given in the last argument", function()
         util.mock_io(finally, {
            ["foo.tl"] = [[ return 10 ]],
         })
         local env = tl.init_env(false, nil, nil, {"foo"})
         assert(env.modules["foo"], "foo wasn't loaded")
      end)
      it("should fail when it can't preload every module", function()
         util.mock_io(finally, {
            ["foo.tl"] = [[ return 10 ]],
         })
         local env, err = tl.init_env(false, nil, nil, {"bar"})
         assert(not env, "env loading succeeded when it shouldn't have")
         assert.match("not predefine.*bar", err)
      end)
   end)

   it("should return an error if gen_target=='5.4' and gen_compat~='off'", function()
      local env, err = tl.init_env(false, true, "5.4")
      assert.is_nil(env)
      assert.is_not_nil(err)
      assert.match("5%.4", err)
   end)
end)
