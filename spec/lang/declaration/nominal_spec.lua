local util = require("spec.util")

describe("nominals", function()
   it("references get resolved in the same scope", util.check([[
      -- unresolved nominal reference
      local has_unr: function(where: Node)

      -- circular type definitions
      local type MyFn = function(MyMap)
      local type MyMap = {string:MyFn}

      -- above nominal reference gets resolved
      local record Node
      end

      has_unr = function(where: Node)
         print(where)
      end
   ]]))

   it("references get resolved across scopes", util.check([[
      -- unresolved nominal reference
      local has_unr: function(where: Node)

      do
         -- circular type definitions
         local type MyFn = function(MyMap)
         local type MyMap = {string:MyFn}
      end

      -- above nominal reference gets resolved
      local record Node
      end

      has_unr = function(where: Node)
         print(where)
      end
   ]]))
end)
