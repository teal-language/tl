local util = require("spec.util")
local assert = require("luassert")

describe("Contextual Typing Integration", function()
   
   describe("End-to-End Pipeline", function()
      
      it("should parse function literal with untyped parameters", function()
         local code = [[
            local f: function(x: number): number = function(x) return x + 1 end
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should infer parameter types from assignment context", function()
         local code = [[
            local f: function(x: number): number = function(x) return x + 1 end
            local result = f(5)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should infer parameter types in function call context", function()
         local code = [[
            local function apply(f: function(x: number): number, x: number): number
               return f(x)
            end
            
            local result = apply(function(x) return x + 1 end, 5)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle mixed typed and untyped parameters", function()
         local code = [[
            local function process(f: function(x: number, y: string): boolean): boolean
               return f(42, "test")
            end
            
            local result = process(function(x: number, y) return true end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should infer types in nested function contexts", function()
         local code = [[
            local function outer(f: function(g: function(x: number): number): number): number
               return f(function(x) return x * 2 end)
            end
            
            local result = outer(function(g) return g(5) end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should report errors for incompatible inferred types", function()
         local code = [[
            local f: function(x: number): number = function(x) return "string" end
         ]]
         
         local result = util.check(code)
         assert.is_false(result)
      end)
      
      it("should handle generic function types", function()
         local code = [[
            local function map<T, U>(f: function(x: T): U, items: {T}): {U}
               local result: {U} = {}
               for i, item in ipairs(items) do
                  result[i] = f(item)
               end
               return result
            end
            
            local numbers = {1, 2, 3}
            local strings = map(function(x) return tostring(x) end, numbers)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle array method callbacks", function()
         local code = [[
            local function filter(items: {number}, predicate: function(x: number): boolean): {number}
               local result: {number} = {}
               for i, item in ipairs(items) do
                  if predicate(item) then
                     table.insert(result, item)
                  end
               end
               return result
            end
            
            local numbers = {1, 2, 3, 4, 5}
            local evens = filter(numbers, function(x) return x % 2 == 0 end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle event handler callbacks", function()
         local code = [[
            local record EventEmitter
               on: function(self: EventEmitter, event: string, handler: function(data: string): void): void
            end
            
            local emitter: EventEmitter = {}
            
            function emitter:on(event: string, handler: function(data: string): void)
               -- Implementation
            end
            
            emitter:on("message", function(data) print(data) end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should preserve backward compatibility with explicit types", function()
         local code = [[
            local f: function(x: number): number = function(x: number) return x + 1 end
            local result = f(5)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle union types in expected function types", function()
         local code = [[
            local function process(f: function(x: number | string): boolean): boolean
               return f(42) and f("test")
            end
            
            local result = process(function(x) return true end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle optional parameters in inferred functions", function()
         local code = [[
            local function apply(f: function(x: number, y?: string): string): string
               return f(42)
            end
            
            local result = apply(function(x, y) return tostring(x) end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle varargs in inferred functions", function()
         local code = [[
            local function apply(f: function(...: number): number): number
               return f(1, 2, 3)
            end
            
            local result = apply(function(...) 
               local sum = 0
               for _, v in ipairs({...}) do
                  sum = sum + v
               end
               return sum
            end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle record method callbacks", function()
         local code = [[
            local record Handler
               process: function(self: Handler, data: string): void
            end
            
            local function register(handler: Handler): void
               handler:process("test")
            end
            
            local h: Handler = {}
            function h:process(data) print(data) end
            register(h)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle table constructor with function fields", function()
         local code = [[
            local record Callbacks
               on_success: function(result: string): void
               on_error: function(error: string): void
            end
            
            local callbacks: Callbacks = {
               on_success = function(result) print(result) end,
               on_error = function(error) print(error) end,
            }
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle return type inference for callbacks", function()
         local code = [[
            local function transform(f: function(x: number): string): function(x: number): string
               return f
            end
            
            local result = transform(function(x) return tostring(x) end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle multiple levels of nesting", function()
         local code = [[
            local function level1(f: function(g: function(h: function(x: number): number): number): number): number
               return f(function(h) return h(5) end)
            end
            
            local result = level1(function(g) return g(function(x) return x * 2 end) end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle inference with type aliases", function()
         local code = [[
            local type NumberTransform = function(x: number): number
            
            local function apply(f: NumberTransform): number
               return f(42)
            end
            
            local result = apply(function(x) return x + 1 end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle inference with nominal types", function()
         local code = [[
            local record Point
               x: number
               y: number
            end
            
            local function process(f: function(p: Point): number): number
               return f({x = 1, y = 2})
            end
            
            local result = process(function(p) return p.x + p.y end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle inference with interface types", function()
         local code = [[
            local interface Drawable
               draw: function(self: Drawable): void
            end
            
            local function render(obj: Drawable): void
               obj:draw()
            end
            
            local obj: Drawable = {}
            function obj:draw() print("drawing") end
            render(obj)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle inference with enum types", function()
         local code = [[
            local enum Color
               "red"
               "green"
               "blue"
            end
            
            local function process(f: function(c: Color): string): string
               return f("red")
            end
            
            local result = process(function(c) return c end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle inference with array types", function()
         local code = [[
            local function process(f: function(items: {number}): number): number
               return f({1, 2, 3})
            end
            
            local result = process(function(items) 
               local sum = 0
               for _, v in ipairs(items) do
                  sum = sum + v
               end
               return sum
            end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle inference with map types", function()
         local code = [[
            local function process(f: function(map: {string: number}): number): number
               return f({a = 1, b = 2})
            end
            
            local result = process(function(map) 
               local sum = 0
               for _, v in pairs(map) do
                  sum = sum + v
               end
               return sum
            end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle inference with tuple types", function()
         local code = [[
            local function process(f: function(t: number, string): boolean): boolean
               return f(42, "test")
            end
            
            local result = process(function(x, y) return true end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle inference with any type", function()
         local code = [[
            local function process(f: function(x: any): any): any
               return f(42)
            end
            
            local result = process(function(x) return x end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle inference with nil type", function()
         local code = [[
            local function process(f: function(x: nil): void): void
               f(nil)
            end
            
            local result = process(function(x) end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle inference with boolean type", function()
         local code = [[
            local function process(f: function(x: boolean): string): string
               return f(true)
            end
            
            local result = process(function(x) return tostring(x) end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle inference with string type", function()
         local code = [[
            local function process(f: function(x: string): number): number
               return #f("test")
            end
            
            local result = process(function(x) return #x end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
      it("should handle inference with integer type", function()
         local code = [[
            local function process(f: function(x: integer): number): number
               return f(42)
            end
            
            local result = process(function(x) return x + 1 end)
         ]]
         
         local result = util.check(code)
         assert.is_true(result)
      end)
      
   end)
   
end)
