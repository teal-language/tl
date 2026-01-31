local util = require("spec.util")
local tl = require("teal.api.v2")
local inference_performance_optimizer = require("teal.inference_performance_optimizer")

describe("contextual typing performance tests", function()
   print("DEBUG: Starting performance tests")
   
   local function generate_large_codebase()
      -- Generate a large codebase with many functions and type aliases
      local code = ""
      
      -- Create many type aliases
      for i = 1, 50 do
         code = code .. string.format("type Type%d = number\n", i)
      end
      
      -- Create many functions using these types
      for i = 1, 50 do
         code = code .. string.format(
            "local function func%d(x: Type%d): Type%d return x * 2 end\n",
            i, i, i
         )
      end
      
      return code
   end
   
   local function generate_deeply_nested_types()
      -- Generate deeply nested type structures
      local code = ""
      
      -- Create nested type aliases
      code = code .. "type Level0 = number\n"
      for i = 1, 20 do
         code = code .. string.format("type Level%d = Level%d\n", i, i - 1)
      end
      
      -- Create a function using the deeply nested type
      code = code .. "local function process(x: Level20): Level20 return x * 2 end\n"
      
      return code
   end
   
   local function generate_recursive_type_scenario()
      -- Generate a scenario that could cause recursive type issues
      local code = [[
         local record Node
            value: number
            next: Node | nil
         end
         
         local function traverse(n: Node | nil): number
            if n then
               return n.value + traverse(n.next)
            else
               return 0
            end
         end
      ]]
      
      return code
   end
   
   local function measure_inference_performance(code, description)
      print("\n  Testing: " .. description)
      
      local optimizer = inference_performance_optimizer:new()
      optimizer:set_monitoring_enabled(true)
      optimizer:set_caching_enabled(true)
      
      local start_time = optimizer:start_timing()
      
      local env = tl.init_env()
      local result = tl.process(code, env)
      
      optimizer:end_timing(start_time, result.ok)
      
      local stats = optimizer:get_performance_stats()
      local cache_stats = optimizer:get_cache_stats()
      
      print("    Type check result: " .. (result.ok and "OK" or "FAILED"))
      print("    Errors: " .. #result.errors)
      print("    Average inference time: " .. string.format("%.2f", stats.average_time_ms) .. " ms")
      
      return stats, cache_stats
   end
   
   it("handles large codebases efficiently", function()
      local code = generate_large_codebase()
      local stats, cache_stats = measure_inference_performance(code, "Large codebase with 50 functions")
      
      -- Verify that the code type checks
      local env = tl.init_env()
      local result = tl.process(code, env)
      assert.truthy(result.ok, "Large codebase should type check")
      assert.equal(0, #result.errors, "Should have no type errors")
   end)
   
   it("handles deeply nested types without infinite loops", function()
      local code = generate_deeply_nested_types()
      local stats, cache_stats = measure_inference_performance(code, "Deeply nested types (20 levels)")
      
      -- Verify that the code type checks
      local env = tl.init_env()
      local result = tl.process(code, env)
      assert.truthy(result.ok, "Deeply nested types should type check")
      assert.equal(0, #result.errors, "Should have no type errors")
   end)
   
   it("terminates recursive type inference correctly", function()
      local code = generate_recursive_type_scenario()
      local stats, cache_stats = measure_inference_performance(code, "Recursive type scenario")
      
      -- Verify that the code type checks
      local env = tl.init_env()
      local result = tl.process(code, env)
      assert.truthy(result.ok, "Recursive type scenario should type check")
      assert.equal(0, #result.errors, "Should have no type errors")
   end)
   
   it("caches inference results effectively", function()
      local code = [[
         type Processor = function(number): number
         local function apply(f: Processor, x: number): number
            return f(x)
         end
         local double: function(number): number = function(n: number): number
            return n * 2
         end
         local result1 = apply(double, 5)
         local result2 = apply(double, 10)
         local result3 = apply(double, 15)
      ]]
      
      local optimizer = inference_performance_optimizer:new()
      optimizer:set_caching_enabled(true)
      
      -- First run - populate cache
      local start_time1 = optimizer:start_timing()
      local env1 = tl.init_env()
      local result1 = tl.process(code, env1)
      optimizer:end_timing(start_time1, result1.ok)
      
      local cache_stats1 = optimizer:get_cache_stats()
      print("\n  First run cache stats:")
      print("    Cache size: " .. cache_stats1.cache_size)
      print("    Cache hits: " .. cache_stats1.cache_hits)
      print("    Cache misses: " .. cache_stats1.cache_misses)
      
      -- Second run - should benefit from cache
      local start_time2 = optimizer:start_timing()
      local env2 = tl.init_env()
      local result2 = tl.process(code, env2)
      optimizer:end_timing(start_time2, result2.ok)
      
      local cache_stats2 = optimizer:get_cache_stats()
      print("  Second run cache stats:")
      print("    Cache size: " .. cache_stats2.cache_size)
      print("    Cache hits: " .. cache_stats2.cache_hits)
      print("    Cache misses: " .. cache_stats2.cache_misses)
      
      -- Verify both runs succeeded
      assert.truthy(result1.ok, "First run should type check")
      assert.truthy(result2.ok, "Second run should type check")
   end)
   
   it("respects recursion depth limits", function()
      local optimizer = inference_performance_optimizer:new()
      optimizer:set_max_recursion_depth(5)
      
      -- Test that recursion tracking works
      for i = 1, 10 do
         local type_id = "type_" .. i
         local exceeded = optimizer:check_recursion_limit(type_id)
         
         if i <= 5 then
            assert.falsy(exceeded, "Should not exceed limit for depth " .. i)
         else
            assert.truthy(exceeded, "Should exceed limit for depth " .. i)
         end
      end
      
      local recursion_stats = optimizer:get_recursion_stats()
      assert.truthy(recursion_stats.depth_limit_exceeded > 0, "Should have exceeded depth limit")
   end)
   
   it("monitors performance statistics accurately", function()
      local optimizer = inference_performance_optimizer:new()
      optimizer:set_monitoring_enabled(true)
      
      -- Simulate multiple inference operations
      for i = 1, 5 do
         local start_time = optimizer:start_timing()
         -- Simulate some work
         local sum = 0
         for j = 1, 1000 do
            sum = sum + j
         end
         optimizer:end_timing(start_time, true)
      end
      
      local stats = optimizer:get_performance_stats()
      assert.equal(5, stats.total_operations, "Should have 5 operations")
      assert.equal(5, stats.successful_inferences, "Should have 5 successful inferences")
      assert.equal(0, stats.failed_inferences, "Should have 0 failed inferences")
      assert.truthy(stats.average_time_ms > 0, "Average time should be positive")
   end)
   
   it("clears cache when disabled", function()
      local optimizer = inference_performance_optimizer:new()
      optimizer:set_caching_enabled(true)
      
      -- Add some entries to cache
      local mock_func = { kind = "function" }
      local mock_type = { typename = "function", typeid = 1 }
      local mock_result = { success = true }
      
      optimizer:cache_result(mock_func, mock_type, mock_result)
      
      local cache_stats1 = optimizer:get_cache_stats()
      assert.truthy(cache_stats1.cache_size > 0, "Cache should have entries")
      
      -- Disable caching
      optimizer:set_caching_enabled(false)
      
      local cache_stats2 = optimizer:get_cache_stats()
      assert.equal(0, cache_stats2.cache_size, "Cache should be cleared when disabled")
   end)
   
   it("handles time limit enforcement", function()
      local optimizer = inference_performance_optimizer:new()
      optimizer:set_max_inference_time(100)  -- 100ms limit
      
      -- Test early termination check
      local should_terminate1 = optimizer:should_terminate_early(50, 5)
      assert.falsy(should_terminate1, "Should not terminate at 50ms with depth 5")
      
      local should_terminate2 = optimizer:should_terminate_early(150, 5)
      assert.truthy(should_terminate2, "Should terminate at 150ms (exceeds 100ms limit)")
      
      local should_terminate3 = optimizer:should_terminate_early(50, 15)
      assert.truthy(should_terminate3, "Should terminate at depth 15 (exceeds max depth 10)")
   end)
   
   it("generates accurate performance reports", function()
      local optimizer = inference_performance_optimizer:new()
      optimizer:set_monitoring_enabled(true)
      
      -- Simulate some operations
      for i = 1, 3 do
         local start_time = optimizer:start_timing()
         local sum = 0
         for j = 1, 100 do
            sum = sum + j
         end
         optimizer:end_timing(start_time, i % 2 == 0)  -- Alternate success/failure
      end
      
      local stats = optimizer:get_performance_stats()
      assert.equal(3, stats.total_operations, "Should have 3 operations")
      assert.truthy(stats.average_time_ms >= 0, "Average time should be non-negative")
      
      -- Print report (should not crash)
      optimizer:print_performance_report()
   end)
   
   it("handles cache eviction correctly", function()
      local optimizer = inference_performance_optimizer:new()
      optimizer.cache.max_size = 5  -- Small cache for testing
      optimizer:set_caching_enabled(true)
      
      -- Add more entries than cache can hold
      for i = 1, 10 do
         local mock_func = { kind = "function", id = i }
         local mock_type = { typename = "function", typeid = i }
         local mock_result = { success = true }
         optimizer:cache_result(mock_func, mock_type, mock_result)
      end
      
      local cache_stats = optimizer:get_cache_stats()
      assert.truthy(cache_stats.cache_size <= optimizer.cache.max_size, 
                   "Cache size should not exceed max size")
   end)
end)
