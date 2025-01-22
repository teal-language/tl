local util = require("spec.util")

describe("maps", function()
   it("covariant matching on map values (see #914)", util.check_lines([[
      local interface Animal
      end

      local record Bird is Animal
      end

      local record Cat is Animal
      end

      local sa: {string: Animal}
      local sb: {string: Bird}
      local sc: {string: Cat}

      local function add_cat(m: {string: Cat})
         local c: Cat = {}
         m["felix"] = c
      end

      local function add_animal(m: {string: Animal})
         local c: Cat = {}
         m["felix"] = c
      end

      local function get_cat(m: {string: Cat}): Cat
         return m["felix"]
      end

      local function get_animal(m: {string: Animal}): Animal
         return m["felix"]
      end
   ]], {
      { line = "local c: Cat; c = sa['felix']", err = "in assignment: Animal is not a Cat" },
      { line = "local c: Cat; c = sb['felix']", err = "in assignment: Bird is not a Cat" },
      { line = "local c: Cat; c = sc['felix']" },
      { line = "local c: Cat; c = get_cat(sa)", err = "in map value: Animal is not a Cat" },
      { line = "local c: Cat; c = get_cat(sb)", err = "in map value: Bird is not a Cat" },
      { line = "local c: Cat; c = get_cat(sc)" },

      { line = "local a: Animal; a = sa['felix']" },
      { line = "local a: Animal; a = sb['felix']" },
      { line = "local a: Animal; a = sc['felix']" },
      { line = "local a: Animal; a = get_cat(sa)", err = "in map value: Animal is not a Cat"  },
      { line = "local a: Animal; a = get_cat(sb)", err = "in map value: Bird is not a Cat"  },
      { line = "local a: Animal; a = get_cat(sc)" },

      { line = "local c: Cat; sa['felix'] = c" },
      { line = "local c: Cat; sb['felix'] = c", err = "in assignment: Cat is not a Bird" },
      { line = "local c: Cat; sc['felix'] = c" },

      { line = "local a: Animal; sa['felix'] = a" },
      { line = "local a: Animal; sb['felix'] = a", err = "in assignment: Animal is not a Bird" },
      { line = "local a: Animal; sc['felix'] = a", err = "in assignment: Animal is not a Cat"  },

      { line = "add_cat(sa)", err = "in map value: Animal is not a Cat" },
      { line = "add_cat(sb)", err = "in map value: Bird is not a Cat" },
      { line = "add_cat(sc)" },
      { line = "add_animal(sa)" },
      { line = "add_animal(sb)" }, -- unsound but accepted
      { line = "add_animal(sc)" },

      { line = "local a: Animal; a = get_animal(sa)" },
      { line = "local a: Animal; a = get_animal(sb)" },
      { line = "local a: Animal; a = get_animal(sc)" },

      { line = "local c: Cat; c = get_animal(sa)", err = "in assignment: Animal is not a Cat" },
      { line = "local c: Cat; c = get_animal(sb)", err = "in assignment: Animal is not a Cat" },
      { line = "local c: Cat; c = get_animal(sc)", err = "in assignment: Animal is not a Cat" },
   }))

   it("contravariant matching on map keys (see #914)", util.check_lines([[
      local interface Animal
      end

      local record Bird is Animal
      end

      local record Cat is Animal
      end

      local as: {Animal: string}
      local bs: {Bird: string}
      local cs: {Cat: string}

      local function add_cat(m: {Cat: string})
         local c: Cat = {}
         m[c] = "felix"
      end

      local function add_animal(m: {Animal: string})
         local c: Cat = {}
         m[c] = "felix"
      end

      local catobj: Cat

      local function first_cat(m: {Cat: string}): Cat
         return (next(m))
      end

      local function get_animal(m: {Animal: string}): string
         return m[catobj]
      end

      local s: string
   ]], {
      { line = "local c: Cat; s = as[c]" },
      { line = "local c: Cat; s = bs[c]", err = "wrong index type: got Cat, expected Bird" },
      { line = "local c: Cat; s = cs[c]" },
      { line = "local c: Cat; c = first_cat(as)" }, -- unsound but accepted
      { line = "local c: Cat; c = first_cat(bs)", err = "in map key: Cat is not a Bird" },
      { line = "local c: Cat; c = first_cat(cs)" },

      { line = "local a: Animal; s = as[a]" },
      { line = "local a: Animal; s = bs[a]", err = "wrong index type: got Animal, expected Bird" },
      { line = "local a: Animal; s = cs[a]", err = "wrong index type: got Animal, expected Cat"},
      { line = "local a: Animal; a = first_cat(as)" },
      { line = "local a: Animal; a = first_cat(bs)", err = "in map key: Cat is not a Bird"  },
      { line = "local a: Animal; a = first_cat(cs)" },

      { line = "local c: Cat; as[c] = s" },
      { line = "local c: Cat; bs[c] = s", err = "wrong index type: got Cat, expected Bird" },
      { line = "local c: Cat; cs[c] = s" },

      { line = "local a: Animal; as[a] = s" },
      { line = "local a: Animal; bs[a] = s", err = "wrong index type: got Animal, expected Bird" },
      { line = "local a: Animal; cs[a] = s", err = "wrong index type: got Animal, expected Cat"  },

      { line = "add_cat(as)" },
      { line = "add_cat(bs)", err = "in map key: Cat is not a Bird" },
      { line = "add_cat(cs)" },

      { line = "add_animal(as)" },
      { line = "add_animal(bs)", err = "in map key: Animal is not a Bird" },
      { line = "add_animal(cs)", err = "in map key: Animal is not a Cat" },

      { line = "local a: Animal; s = get_animal(as)" },
      { line = "local a: Animal; s = get_animal(bs)", err = "in map key: Animal is not a Bird"  },
      { line = "local a: Animal; s = get_animal(cs)", err = "in map key: Animal is not a Cat" },

      { line = "local c: Cat; s = get_animal(as)" },
      { line = "local c: Cat; s = get_animal(bs)", err = "in map key: Animal is not a Bird" },
      { line = "local c: Cat; s = get_animal(cs)", err = "in map key: Animal is not a Cat" },
   }))
end)

