local util = require("spec.util")
local teal = require("teal")
local lfs = require("lfs")

describe("Compiler.recall", function()
   it("retrieves a previously-processed module", function()
      local current_dir = lfs.currentdir()
      local dir_name = util.write_tmp_dir(finally, {
         ["foo.tl"] = [[ require("bar") ]],
         ["bar.tl"] = [[ global x = 10 ]],
      })

      assert(lfs.chdir(dir_name))

      local compiler = teal.compiler()

      local foo_input = compiler:open("foo.tl")
      local module = foo_input:check()

      assert(lfs.chdir(current_dir))

      local recalled = compiler:recall("foo.tl")
      assert.same(module, recalled)

      -- can also retrieve modules processed via require
      assert(compiler:recall("./bar.tl"))
   end)

   it("returns nil if module wasn't previously loaded", function()
      local compiler = teal.compiler()
      local recalled = compiler:recall("foo.tl")
      assert.same(nil, recalled)
   end)
end)
