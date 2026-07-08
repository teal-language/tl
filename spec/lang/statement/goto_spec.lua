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

   it("rejects a goto into the scope of local in same block (regression test for #1121)", util.check_type_error([[
      goto finish
      local _foo  =  0
      :: finish ::
      local _bar  =  0
   ]], {
      { y = 1, msg = "goto jumps into scope of a local variable" }
   }))

   it("can jump upwards (regression test for #1121)", util.check([[
      local _foo = 0
      :: finish ::
      goto finish
   ]]))

   it("can jump over out-of-scope locals (regression test for #1121)", util.check([[
      do
         goto finish
         local _foo  =  0
      end
      :: finish ::
      local _bar  =  0
   ]]))

   it("rejects a goto into the scope of local in outer block (regression test for #1121)", util.check_type_error([[
      do
         goto finish
      end
      local _foo  =  0
      :: finish ::
      local _bar  =  0
   ]], {
      { y = 2, msg = "goto jumps into scope of a local variable" }
   }))

   it("accepts a goto over a local to a label at the end of a block", util.check([[
      for i = 1, 5 do
         goto next
         local _this = i
         ::next::
      end
   ]]))

   it("accepts the continue idiom with locals in the loop body", util.check([[
      for i = 1, 3 do
         if i == 2 then
            goto continue
         end
         local doubled = i * 2
         print(doubled)
         ::continue::
      end
   ]]))

   it("accepts a goto over a local to stacked labels at the end of a block", util.check([[
      do
         goto first
         local _foo = 0
         ::first::
         ::second::
      end
      local _bar = 0
   ]]))

   it("rejects a goto over a local to a label followed by return", util.check_type_error([[
      local function f(): integer
         goto finish
         local _foo = 0
         ::finish::
         return 1
      end
      f()
   ]], {
      { y = 2, msg = "goto jumps into scope of a local variable" }
   }))

   it("rejects a goto over a local to a label at the end of a repeat body", util.check_type_error([[
      repeat
         goto continue
         local _foo = 0
         ::continue::
      until true
   ]], {
      { y = 2, msg = "goto jumps into scope of a local variable" }
   }))
end)
