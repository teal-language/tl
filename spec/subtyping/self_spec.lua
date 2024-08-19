local util = require("spec.util")

describe("subtyping of self", function()
   it("self type resolves from abstract interface to concrete records, implicit self type by name (#756)", util.check([[
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

   it("self type resolves from abstract interface to concrete records, explicit use of self type (#756)", util.check([[
      local interface SoundMaker
         make_sound: function(self: self)
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

   it("self type resolves from abstract interface to concrete records, self type self-reference heuristic (#756)", util.check([[
      local interface SoundMaker
         make_sound: function(self: SoundMaker)
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

   it("a self variable that is not a self-referential type has no special behavior", util.check_type_error([[
      local interface SoundMaker
         make_sound: function(self: integer)
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
   ]], {
      { y = 13, msg = "type signature of 'make_sound' does not match its declaration in Animal: argument 0: got Animal, expected integer" },
      { y = 25, msg = "type signature of 'make_sound' does not match its declaration in Person: argument 0: got Person, expected integer" },
      { y = 35, msg = "self: got SoundMaker, expected integer" },
   }))

end)

