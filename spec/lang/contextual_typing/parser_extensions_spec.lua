local util = require("spec.util")
local tl = require("teal.api.v2")

describe("contextual typing parser extensions", function()
   
   describe("untyped parameter parsing", function()
      it("parses function with single untyped parameter", util.check([[
         local f = function(x) return x end
      ]]))
      
      it("parses function with multiple untyped parameters", util.check([[
         local f = function(a, b, c) return a + b + c end
      ]]))
      
      it("parses function with no parameters", util.check([[
         local f = function() return 42 end
      ]]))
      
      it("parses function with varargs", util.check([[
         local f = function(...) return ... end
      ]]))
   end)
   
   describe("typed parameter parsing", function()
      it("parses function with single typed parameter", util.check([[
         local f = function(x: number) return x end
      ]]))
      
      it("parses function with multiple typed parameters", util.check([[
         local f = function(a: number, b: string, c: boolean) return a end
      ]]))
      
      it("parses function with complex parameter types", util.check([[
         local f = function(arr: {number}, callback: function(number): string) 
            return callback(arr[1]) 
         end
      ]]))
   end)
   
   describe("mixed parameter parsing", function()
      it("parses function with mixed typed and untyped parameters", util.check([[
         local f = function(a: number, b, c: string, d) return a end
      ]]))
      
      it("parses function with untyped first, typed last", util.check([[
         local f = function(x, y: number) return x + y end
      ]]))
      
      it("parses function with typed first, untyped last", util.check([[
         local f = function(x: number, y) return x + y end
      ]]))
   end)
   
   describe("AST node creation for inference", function()
      local function validate_function_node_structure(code, expected_param_count)
         local ast, syntax_errors = tl.parse(code, "test.tl")
         assert.same({}, syntax_errors, "Code should not have syntax errors")
         
         -- Find the function literal in the AST
         local function find_function_literal(node)
            if node.kind == "function" then
               return node
            end
            
            -- Check common fields that might contain function literals
            local fields_to_check = {"e1", "e2", "exp", "value", "body", "exps"}
            for _, field in ipairs(fields_to_check) do
               if node[field] and type(node[field]) == "table" and node[field].kind then
                  local result = find_function_literal(node[field])
                  if result then return result end
               end
            end
            
            -- Check array-like fields
            if type(node) == "table" then
               for i = 1, #node do
                  if type(node[i]) == "table" and node[i].kind then
                     local result = find_function_literal(node[i])
                     if result then return result end
                  end
               end
            end
            
            return nil
         end
         
         local func_node = find_function_literal(ast)
         assert.is_not_nil(func_node, "Should find function literal in AST")
         
         -- Validate contextual typing fields are present
         assert.is_not_nil(func_node.inferred_signature, "Should have inferred_signature field")
         assert.is_not_nil(func_node.inference_source, "Should have inference_source field")
         assert.is_not_nil(func_node.inference_confidence, "Should have inference_confidence field")
         assert.is_not_nil(func_node.contextual_type_info, "Should have contextual_type_info field")
         
         -- Validate initial values
         assert.is_nil(func_node.inferred_signature, "inferred_signature should be nil initially")
         assert.is_nil(func_node.inference_source, "inference_source should be nil initially")
         assert.equal(0.0, func_node.inference_confidence, "inference_confidence should be 0.0 initially")
         assert.is_nil(func_node.contextual_type_info, "contextual_type_info should be nil initially")
         
         -- Validate parameter structure
         if expected_param_count > 0 then
            assert.is_not_nil(func_node.args, "Function should have args")
            assert.equal(expected_param_count, #func_node.args, "Parameter count should match expected")
         end
         
         return func_node
      end
      
      it("creates proper AST nodes for untyped parameters", function()
         local func_node = validate_function_node_structure(
            "local f = function(x, y) return x + y end", 2
         )
         
         -- Check that parameters don't have type annotations
         assert.is_nil(func_node.args[1].argtype, "First parameter should not have type")
         assert.is_nil(func_node.args[2].argtype, "Second parameter should not have type")
         
         -- Check parameter names
         assert.equal("x", func_node.args[1].tk, "First parameter name should be 'x'")
         assert.equal("y", func_node.args[2].tk, "Second parameter name should be 'y'")
      end)
      
      it("creates proper AST nodes for typed parameters", function()
         local func_node = validate_function_node_structure(
            "local f = function(x: number, y: string) return x end", 2
         )
         
         -- Check that parameters have type annotations
         assert.is_not_nil(func_node.args[1].argtype, "First parameter should have type")
         assert.is_not_nil(func_node.args[2].argtype, "Second parameter should have type")
         
         -- Check parameter names
         assert.equal("x", func_node.args[1].tk, "First parameter name should be 'x'")
         assert.equal("y", func_node.args[2].tk, "Second parameter name should be 'y'")
      end)
      
      it("creates proper AST nodes for mixed parameters", function()
         local func_node = validate_function_node_structure(
            "local f = function(x: number, y, z: string) return x end", 3
         )
         
         -- Check parameter type annotations
         assert.is_not_nil(func_node.args[1].argtype, "First parameter should have type")
         assert.is_nil(func_node.args[2].argtype, "Second parameter should not have type")
         assert.is_not_nil(func_node.args[3].argtype, "Third parameter should have type")
         
         -- Check parameter names
         assert.equal("x", func_node.args[1].tk, "First parameter name should be 'x'")
         assert.equal("y", func_node.args[2].tk, "Second parameter name should be 'y'")
         assert.equal("z", func_node.args[3].tk, "Third parameter name should be 'z'")
      end)
      
      it("creates proper AST nodes for local functions", function()
         local ast, syntax_errors = tl.parse("local function test(x, y: number) return x + y end", "test.tl")
         assert.same({}, syntax_errors, "Code should not have syntax errors")
         
         -- Find the local function node
         local func_node = nil
         if ast[1] and ast[1].kind == "local_function" then
            func_node = ast[1]
         end
         
         assert.is_not_nil(func_node, "Should find local function node")
         assert.equal("local_function", func_node.kind, "Should be local_function kind")
         
         -- Validate contextual typing fields
         assert.is_not_nil(func_node.inferred_signature, "Should have inferred_signature field")
         assert.is_not_nil(func_node.inference_source, "Should have inference_source field")
         assert.is_not_nil(func_node.inference_confidence, "Should have inference_confidence field")
         assert.is_not_nil(func_node.contextual_type_info, "Should have contextual_type_info field")
      end)
      
      it("creates proper AST nodes for global functions", function()
         local ast, syntax_errors = tl.parse("function test(x, y: number) return x + y end", "test.tl")
         assert.same({}, syntax_errors, "Code should not have syntax errors")
         
         -- Find the global function node
         local func_node = nil
         if ast[1] and ast[1].kind == "global_function" then
            func_node = ast[1]
         end
         
         assert.is_not_nil(func_node, "Should find global function node")
         assert.equal("global_function", func_node.kind, "Should be global_function kind")
         
         -- Validate contextual typing fields
         assert.is_not_nil(func_node.inferred_signature, "Should have inferred_signature field")
         assert.is_not_nil(func_node.inference_source, "Should have inference_source field")
         assert.is_not_nil(func_node.inference_confidence, "Should have inference_confidence field")
         assert.is_not_nil(func_node.contextual_type_info, "Should have contextual_type_info field")
      end)
   end)
   
   describe("backward compatibility", function()
      it("maintains compatibility with existing typed function syntax", util.check([[
         local function add(a: number, b: number): number
            return a + b
         end
         
         local result = add(1, 2)
      ]]))
      
      it("maintains compatibility with method definitions", util.check([[
         local record Point
            x: number
            y: number
         end
         
         function Point:distance(): number
            return math.sqrt(self.x * self.x + self.y * self.y)
         end
      ]]))
      
      it("maintains compatibility with generic functions", util.check([[
         local function identity<T>(x: T): T
            return x
         end
         
         local result = identity(42)
      ]]))
   end)
   
   describe("edge cases", function()
      it("handles empty parameter list", function()
         local func_node = validate_function_node_structure(
            "local f = function() return 42 end", 0
         )
         
         -- Should have empty args or nil args
         if func_node.args then
            assert.equal(0, #func_node.args, "Should have no parameters")
         end
      end)
      
      it("handles single parameter with no type", function()
         local func_node = validate_function_node_structure(
            "local f = function(x) return x end", 1
         )
         
         assert.is_nil(func_node.args[1].argtype, "Parameter should not have type")
         assert.equal("x", func_node.args[1].tk, "Parameter name should be 'x'")
      end)
      
      it("handles varargs parameter", function()
         local ast, syntax_errors = tl.parse("local f = function(...) return ... end", "test.tl")
         assert.same({}, syntax_errors, "Code should not have syntax errors")
         
         -- Find function and check varargs handling
         local function find_function_literal(node)
            if node.kind == "function" then
               return node
            end
            if node.value and node.value.kind == "function" then
               return node.value
            end
            return nil
         end
         
         local func_node = find_function_literal(ast[1])
         assert.is_not_nil(func_node, "Should find function literal")
         
         -- Check that varargs is handled properly
         if func_node.args and #func_node.args > 0 then
            local vararg = func_node.args[#func_node.args]
            assert.equal("...", vararg.tk, "Should have varargs parameter")
         end
      end)
   end)
end)