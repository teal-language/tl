local util = require("spec.util")
local teal = require("teal")
local lfs = require("lfs")

describe("Compiler.loaded_files", function()
   it("iterates reporting which files were loaded", function()

      local current_dir = lfs.currentdir()
      local dir_name = util.write_tmp_dir(finally, {
         ["foo.tl"] = [[ require("bar") ]],
         ["bar.tl"] = [[ global x = 10 ]],
      })

      assert(lfs.chdir(dir_name))

      local compiler = teal.compiler()

      local foo_input = compiler:open("foo.tl")
      assert(foo_input:check())

      assert(lfs.chdir(current_dir))

      local res = {}
      for f in compiler:loaded_files() do
         table.insert(res, f)
      end

      assert.same({
         "./bar.tl",
         "foo.tl"
      }, res)
   end)
end)
