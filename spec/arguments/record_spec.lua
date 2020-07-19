local util = require("spec.util")

describe("record argument", function()
   it("catches error passing map when record is expected", util.check_type_error([[
      local type node_t = record
         node: {string: node_t}
      end

      local root: node_t = nil

      local function visit(n: node_t)
      end
      visit(root.node)
   ]], {
      { y = 9, msg = 'argument 1: got {string : node_t}, expected node_t' },
   }))
end)
