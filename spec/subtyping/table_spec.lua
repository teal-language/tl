local util = require("spec.util")

describe("'table' alias to {any:any}", function()
   it("is bivariant as a special-case", util.check([[
      local record R
         tbl_contains: function(table, any): boolean
      end

      local record opt
         record Opt<T>
            get: function<T>(Opt<T>): T
         end

         foldopen: Opt<{string}>
      end

      print(R.tbl_contains(opt.foldopen:get(), 'search'))
   ]]))
end)
