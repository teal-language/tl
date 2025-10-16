local util = require("spec.util")

describe("records", function()
   it("report error on fields (regression test for #456)", util.check_type_error([[
      local record Rec
         m: string
      end

      local function t1(): Rec
         return { m = 42 }
      end

      local function t2(): Rec
         local x = { m = 42 }
         return x
      end

      local function f(_: Rec) end
      f({ m = 42 })

      local t: Rec = { m = 42 }
   ]], {
      { y = 6, msg = "in record field: m: got integer, expected string" },
      { y = 11, msg = "record field doesn't match: m: got integer, expected string" },
      { y = 15, msg = "in record field: m: got integer, expected string" },
      { y = 17, msg = "in record field: m: got integer, expected string" },
   }))

   it("reports an error on extra fields", util.check_type_error([[
      local record A
         a: string
      end

      local test_a = { a = "test", bad = "this" }
      local test_b = { a = "test" }

      local test_it: A = test_a
      local test_it_2: A = test_b
   ]], {
      { y = 8, msg = ") is not a record A: record field doesn't exist: bad" },
   }))

   it("refines self on fields inherited from interfaces (regression test for #877)", util.check([[
      -- Define an interface that uses self.
      -- Using self should automatically refine implementations to map self to the impl.
      local interface Container
         new: function(): self
      end

      -- Calling Foo.new should return a Foo (that is, replace `self` with `Foo`)
      local record Foo is Container end

      -- Use another collaborating record to demonstrate the bug.
      local record SomeRecord
         update: function(self: SomeRecord)
      end

      local function foo<C is Container>(c: C)
      end

      -- Calling foo, which expects a Container, from this outer scope works.
      local outerValue = Foo.new()
      foo(outerValue) -- works!

      -- Calling foo from within SomeRecord.update does not work.
      function SomeRecord:update()
         local value = Foo.new()
         foo(value) -- works!
      end
   ]]))

   pending("refines generic self on fields inherited from interfaces (regression test for #877)", util.check([[
      -- Define an interface that uses self.
      -- Using self should automatically refine implementations to map self to the impl.
      local interface Container<T>
         new: function(val: T): self
         myfield: T
      end

      -- Calling Foo.new should return a Foo (that is, replace `self` with `Foo`)
      local record Foo<T> is Container<T>
      end

      -- Use another collaborating record to demonstrate the bug.
      local record SomeRecord
         update: function(self: SomeRecord)
      end

      -- FIXME resolution of generic constraints doesn't work
      local function foo<T, C is Container<T>>(c: C)
         print(tostring(c.myfield))
      end

      -- Calling foo, which expects a Container, from this outer scope works.
      local outerValue = Foo.new(1)
      foo(outerValue) -- works!

      -- Calling foo from within SomeRecord.update does not work.
      function SomeRecord:update()
         local value = Foo.new("hello")
         foo(value) -- works!
      end
   ]]))

   it("early-outs on nonexistent nested record types (regression test for #986)", util.check_type_error([[
      local record Example
      end

      local fails: Example.A.B = {}
   ]], {
      { y = 4, msg = "unknown type Example.A.B" }
   }))
end)

