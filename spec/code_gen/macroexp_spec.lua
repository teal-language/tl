local util = require("spec.util")

describe("macroexp code generation", function()
   it("can use where with generic types", util.gen([[
      local type Success = record<T>
         where self.error == false

         error: boolean
         value: T
      end

      local type Failure = record<T>
         where self.error == true

         error: boolean
         value: T
      end

      local function ok<T>(value: T): Success<T>
         return {
            error = false,
            value = value,
         }
      end

      local function fail<T>(value: T): Failure<T>
         return {
            error = true,
            value = value,
         }
      end

      local type Maybe<T> = Success<T> | Failure<T>

      local function call_me<T>(maybe: Maybe<T>)
         if maybe is Success<T> then
            print("hello, " .. tostring(maybe.value))
         end
      end

      call_me(ok(8675309))
      call_me(fail(911))
   ]], [[














      local function ok(value)
         return {
            error = false,
            value = value,
         }
      end

      local function fail(value)
         return {
            error = true,
            value = value,
         }
      end



      local function call_me(maybe)
         if maybe.error == false then
            print("hello, " .. tostring(maybe.value))
         end
      end

      call_me(ok(8675309))
      call_me(fail(911))
   ]]))
end)

