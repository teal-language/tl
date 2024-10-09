local util = require("spec.util")

describe("goto", function()

   it("parses", util.check([[
      local b = true
      if b then
         print(b)
         goto my_label
      end
      ::my_label::
      print(b)
   ]]))

   it("rejects an invalid label", util.check_syntax_error([[
      goto 123
      ::123:: print("no line numbers :(")
   ]], {
      { y = 1 },
      { y = 2 },
   }))

   it("rejects a repeated label", util.check_type_error([[
      ::my_label::
      do
         ::my_label::
      end
      ::my_label::
   ]], {
      { y = 5, msg = "label 'my_label' already defined" }
   }))

   it("accepts a label in a different scope", util.check([[
      ::my_label::
      do
         ::my_label::
         do
            ::my_label::
         end
      end
   ]]))

   it("accepts a label in a different scope", util.check([[
      do
         ::my_label::
      end
      ::my_label::
   ]]))

   it("accepts a label outside above", util.check([[
      ::my_label::
      do
         goto my_label
      end
   ]]))

   it("accepts a label outside below", util.check([[
      do
         goto my_label
      end
      ::my_label::
   ]]))

   it("accepts a label in the same scope above", util.check([[
      ::my_label::
      goto my_label
   ]]))

   it("accepts a label in the same scope below", util.check([[
      goto my_label
      ::my_label::
   ]]))

   it("rejects a label inside above", util.check_type_error([[
      do
         ::my_label::
      end
      goto my_label
   ]], {
      { y = 4, msg = "no visible label 'my_label'" }
   }))

   it("rejects a label inside below", util.check_type_error([[
      goto my_label
      do
         ::my_label::
      end
   ]], {
      { y = 1, msg = "no visible label 'my_label'" }
   }))

   it("accepts multiple labels", util.check([[
      for i=1, 3 do
         if i <= 2 then
            goto continue
         end
         print(i)
         ::continue::
      end

      for i=1, 3 do
         if i <= 2 then
            goto continue1
         end
         print(i)
         ::continue1::
      end
   ]]))

end)
