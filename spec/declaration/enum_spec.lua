local util = require("spec.util")

describe("enum declaration", function()
   it("declares a enum with local type", util.check([[
      local type t = enum
         "left"
         "right"
      end

      local func = function(b: boolean): t
         if b then
            return "left"
         else
            return "right"
         end
      end
   ]]))

   it("declares a enum with local enum", util.check([[
      local enum t
         "left"
         "right"
      end

      local func = function(b: boolean): t
         if b then
            return "left"
         else
            return "right"
         end
      end
   ]]))

   it("declares a enum with global type", util.check([[
      global type t = enum
         "left"
         "right"
      end

      global func = function(b: boolean): t
         if b then
            return "left"
         else
            return "right"
         end
      end
   ]]))

   it("declares a enum with global enum", util.check([[
      global enum t
         "left"
         "right"
      end

      global func = function(b: boolean): t
         if b then
            return "left"
         else
            return "right"
         end
      end
   ]]))

   it("produces a nice error when local declared with the old syntax", util.check_syntax_error([[
      local t = enum
         "left"
         "right"
      end

      local func = function(b: boolean): t
         if b then
            return "left"
         else
            return "right"
         end
      end
   ]], {
      { y = 1, msg = "syntax error: this syntax is no longer valid; use 'local enum t'" },
   }))

   it("produces a nice error when global declared with the old syntax", util.check_syntax_error([[
      global t = enum
         "left"
         "right"
      end

      local func = function(b: boolean): t
         if b then
            return "left"
         else
            return "right"
         end
      end
   ]], {
      { y = 1, msg = "syntax error: this syntax is no longer valid; use 'global enum t'" },
   }))

   it("produces a nice error when attempting to nest in a table", util.check_syntax_error([[
      local t = {
         Point = enum
            "hi"
         end
      }
   ]], {
      { y = 2, msg = "syntax error: this syntax is no longer valid; declare nested enum inside a record" },
   }))
end)
