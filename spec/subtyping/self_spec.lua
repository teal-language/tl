local util = require("spec.util")

describe("subtyping of self", function()
   it("self type resolves from abstract interface to concrete records (#756)", util.check([[
      local interface SoundMaker
         make_sound: function(self)
      end

      local record Animal is SoundMaker
         species: string
      end

      function Animal:create(species: string): Animal
         return setmetatable({ species = species }, { __index = Animal })
      end

      function Animal:make_sound()
         print("Animal sound")
      end

      local record Person is SoundMaker
         name: string
      end

      function Person:create(name: string): Person
         return setmetatable({ name = name }, { __index = Person })
      end

      function Person:make_sound()
         print("Person sound")
      end

      local things: {SoundMaker} = {
         Animal:create("Dog"),
         Person:create("John")
      }

      for _, thing in ipairs(things) do
         thing:make_sound()
      end
   ]]))
end)

