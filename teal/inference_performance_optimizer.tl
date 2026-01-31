--------------------------------------------------------------------------------
-- Inference Performance Optimizer for Contextual Typing
-- 
-- This module provides performance optimization for contextual type inference,
-- including caching, early termination, and performance monitoring.
--------------------------------------------------------------------------------

local type types = require("teal.types")
local type Type = types.Type
local type FunctionType = types.FunctionType

local type contextual_typing = require("teal.contextual_typing")
local type InferenceResult = contextual_typing.InferenceResult
local type InferenceContext = contextual_typing.InferenceContext

local type parser = require("teal.parser")
local type Node = parser.Node

--------------------------------------------------------------------------------
-- Performance Optimization Data Structures
--------------------------------------------------------------------------------

local record InferenceCache
   -- Cache key -> InferenceResult mapping
   results: {string: InferenceResult}
   
   -- Track cache hits and misses for statistics
   hits: integer
   misses: integer
   
   -- Maximum cache size to prevent memory bloat
   max_size: integer
   
   -- Current cache size
   current_size: integer
end

local record PerformanceMonitor
   -- Total inference operations
   total_operations: integer
   
   -- Successful inferences
   successful_inferences: integer
   
   -- Failed inferences
   failed_inferences: integer
   
   -- Total time spent in inference (milliseconds)
   total_time_ms: number
   
   -- Peak memory usage (bytes)
   peak_memory_bytes: integer
   
   -- Average inference time (milliseconds)
   average_time_ms: number
   
   -- Recursive type depth limit exceeded count
   depth_limit_exceeded: integer
   
   -- Cache statistics
   cache_hits: integer
   cache_misses: integer
   cache_hit_rate: number
end

local record RecursiveTypeTracker
   -- Track visited types to detect infinite recursion
   visited_types: {string: boolean}
   
   -- Current recursion depth
   current_depth: integer
   
   -- Maximum allowed recursion depth
   max_depth: integer
   
   -- Types that caused recursion limit
   problematic_types: {string}
end

--------------------------------------------------------------------------------
-- Inference Performance Optimizer Implementation
--------------------------------------------------------------------------------

local record InferencePerformanceOptimizer
   -- Caching system for inference results
   cache: InferenceCache
   
   -- Performance monitoring
   monitor: PerformanceMonitor
   
   -- Recursive type tracking
   recursion_tracker: RecursiveTypeTracker
   
   -- Enable/disable optimizations
   enable_caching: boolean
   enable_early_termination: boolean
   enable_monitoring: boolean
   
   -- Performance thresholds
   max_inference_time_ms: number
   max_cache_size: integer
   max_recursion_depth: integer
end

-- Create a new performance optimizer instance
function InferencePerformanceOptimizer:new(): InferencePerformanceOptimizer
   local optimizer: InferencePerformanceOptimizer = {
      cache = {
         results = {},
         hits = 0,
         misses = 0,
         max_size = 1000,
         current_size = 0,
      },
      monitor = {
         total_operations = 0,
         successful_inferences = 0,
         failed_inferences = 0,
         total_time_ms = 0.0,
         peak_memory_bytes = 0,
         average_time_ms = 0.0,
         depth_limit_exceeded = 0,
         cache_hits = 0,
         cache_misses = 0,
         cache_hit_rate = 0.0,
      },
      recursion_tracker = {
         visited_types = {},
         current_depth = 0,
         max_depth = 10,
         problematic_types = {},
      },
      enable_caching = true,
      enable_early_termination = true,
      enable_monitoring = true,
      max_inference_time_ms = 5000.0,  -- 5 second timeout
      max_cache_size = 1000,
      max_recursion_depth = 10,
   }
   return optimizer
end

-- Get or create a cache key for an inference operation
function InferencePerformanceOptimizer:create_cache_key(
   func_literal: Node,
   expected_type: FunctionType
): string
   -- Create a unique key based on function literal and expected type
   local func_id = tostring(func_literal) or "unknown"
   local type_id = tostring(expected_type.typeid or 0)
   return func_id .. "_" .. type_id
end

-- Check if an inference result is cached
function InferencePerformanceOptimizer:get_cached_result(
   func_literal: Node,
   expected_type: FunctionType
): InferenceResult
   
   if not self.enable_caching then
      return nil
   end
   
   local cache_key = self:create_cache_key(func_literal, expected_type)
   local cached_result = self.cache.results[cache_key]
   
   if cached_result then
      self.cache.hits = self.cache.hits + 1
      self.monitor.cache_hits = self.monitor.cache_hits + 1
      return cached_result
   end
   
   self.cache.misses = self.cache.misses + 1
   self.monitor.cache_misses = self.monitor.cache_misses + 1
   return nil
end

-- Cache an inference result
function InferencePerformanceOptimizer:cache_result(
   func_literal: Node,
   expected_type: FunctionType,
   result: InferenceResult
)
   
   if not self.enable_caching then
      return
   end
   
   -- Check if cache is full
   if self.cache.current_size >= self.cache.max_size then
      -- Clear oldest entries (simple FIFO eviction)
      self:evict_cache_entries(self.cache.max_size / 2)
   end
   
   local cache_key = self:create_cache_key(func_literal, expected_type)
   self.cache.results[cache_key] = result
   self.cache.current_size = self.cache.current_size + 1
end

-- Evict cache entries to make room for new ones
function InferencePerformanceOptimizer:evict_cache_entries(count: integer)
   local evicted = 0
   for key in pairs(self.cache.results) do
      if evicted >= count then
         break
      end
      self.cache.results[key] = nil
      self.cache.current_size = self.cache.current_size - 1
      evicted = evicted + 1
   end
end

-- Check if recursion limit has been exceeded
function InferencePerformanceOptimizer:check_recursion_limit(
   type_id: string
): boolean
   
   -- Check if we've already visited this type
   if self.recursion_tracker.visited_types[type_id] then
      self.recursion_tracker.current_depth = self.recursion_tracker.current_depth + 1
      
      if self.recursion_tracker.current_depth > self.recursion_tracker.max_depth then
         table.insert(self.recursion_tracker.problematic_types, type_id)
         self.monitor.depth_limit_exceeded = self.monitor.depth_limit_exceeded + 1
         return true  -- Limit exceeded
      end
   else
      self.recursion_tracker.visited_types[type_id] = true
   end
   
   return false  -- Limit not exceeded
end

-- Reset recursion tracking for a new inference operation
function InferencePerformanceOptimizer:reset_recursion_tracking()
   self.recursion_tracker.visited_types = {}
   self.recursion_tracker.current_depth = 0
end

-- Start timing an inference operation
function InferencePerformanceOptimizer:start_timing(): number
   if not self.enable_monitoring then
      return 0
   end
   
   -- Return current time in milliseconds
   return os.clock() * 1000
end

-- End timing an inference operation and update statistics
function InferencePerformanceOptimizer:end_timing(start_time: number, success: boolean)
   if not self.enable_monitoring then
      return
   end
   
   local end_time = os.clock() * 1000
   local elapsed_time = end_time - start_time
   
   -- Update statistics
   self.monitor.total_operations = self.monitor.total_operations + 1
   self.monitor.total_time_ms = self.monitor.total_time_ms + elapsed_time
   
   if success then
      self.monitor.successful_inferences = self.monitor.successful_inferences + 1
   else
      self.monitor.failed_inferences = self.monitor.failed_inferences + 1
   end
   
   -- Update average time
   self.monitor.average_time_ms = self.monitor.total_time_ms / self.monitor.total_operations
   
   -- Check if we exceeded time limit
   if elapsed_time > self.max_inference_time_ms then
      -- Log warning about slow inference
   end
end

-- Check if early termination should be applied
function InferencePerformanceOptimizer:should_terminate_early(
   elapsed_time: number,
   inference_depth: integer
): boolean
   
   if not self.enable_early_termination then
      return false
   end
   
   -- Terminate if we've exceeded time limit
   if elapsed_time > self.max_inference_time_ms then
      return true
   end
   
   -- Terminate if recursion depth is too high
   if inference_depth > self.max_recursion_depth then
      return true
   end
   
   return false
end

-- Get performance statistics
function InferencePerformanceOptimizer:get_performance_stats(): PerformanceMonitor
   -- Calculate cache hit rate
   local total_cache_accesses = self.monitor.cache_hits + self.monitor.cache_misses
   if total_cache_accesses > 0 then
      self.monitor.cache_hit_rate = self.monitor.cache_hits / total_cache_accesses
   end
   
   return self.monitor
end

-- Clear all caches and reset statistics
function InferencePerformanceOptimizer:clear_all()
   self.cache.results = {}
   self.cache.hits = 0
   self.cache.misses = 0
   self.cache.current_size = 0
   
   self.monitor = {
      total_operations = 0,
      successful_inferences = 0,
      failed_inferences = 0,
      total_time_ms = 0.0,
      peak_memory_bytes = 0,
      average_time_ms = 0.0,
      depth_limit_exceeded = 0,
      cache_hits = 0,
      cache_misses = 0,
      cache_hit_rate = 0.0,
   }
   
   self:reset_recursion_tracking()
end

-- Get cache statistics
function InferencePerformanceOptimizer:get_cache_stats(): {string: integer}
   return {
      cache_size = self.cache.current_size,
      cache_hits = self.cache.hits,
      cache_misses = self.cache.misses,
      max_cache_size = self.cache.max_size,
   }
end

-- Get recursion tracking statistics
function InferencePerformanceOptimizer:get_recursion_stats(): {string: any}
   return {
      current_depth = self.recursion_tracker.current_depth,
      max_depth = self.recursion_tracker.max_depth,
      depth_limit_exceeded = self.monitor.depth_limit_exceeded,
      problematic_types = self.recursion_tracker.problematic_types,
   }
end

-- Enable or disable caching
function InferencePerformanceOptimizer:set_caching_enabled(enabled: boolean)
   self.enable_caching = enabled
   if not enabled then
      self:clear_cache()
   end
end

-- Enable or disable early termination
function InferencePerformanceOptimizer:set_early_termination_enabled(enabled: boolean)
   self.enable_early_termination = enabled
end

-- Enable or disable performance monitoring
function InferencePerformanceOptimizer:set_monitoring_enabled(enabled: boolean)
   self.enable_monitoring = enabled
end

-- Set maximum inference time limit
function InferencePerformanceOptimizer:set_max_inference_time(time_ms: number)
   self.max_inference_time_ms = time_ms
end

-- Set maximum recursion depth
function InferencePerformanceOptimizer:set_max_recursion_depth(depth: integer)
   self.max_recursion_depth = depth
   self.recursion_tracker.max_depth = depth
end

-- Clear the inference result cache
function InferencePerformanceOptimizer:clear_cache()
   self.cache.results = {}
   self.cache.current_size = 0
end

-- Print performance report
function InferencePerformanceOptimizer:print_performance_report()
   local stats = self:get_performance_stats()
   local cache_stats = self:get_cache_stats()
   local recursion_stats = self:get_recursion_stats()
   
   print("\n" .. string.rep("=", 60))
   print("INFERENCE PERFORMANCE REPORT")
   print(string.rep("=", 60))
   
   print("\nOperation Statistics:")
   print("  Total operations: " .. stats.total_operations)
   print("  Successful: " .. stats.successful_inferences)
   print("  Failed: " .. stats.failed_inferences)
   print("  Total time: " .. string.format("%.2f", stats.total_time_ms) .. " ms")
   print("  Average time: " .. string.format("%.2f", stats.average_time_ms) .. " ms")
   
   print("\nCache Statistics:")
   print("  Cache size: " .. cache_stats.cache_size .. " / " .. cache_stats.max_cache_size)
   print("  Cache hits: " .. cache_stats.cache_hits)
   print("  Cache misses: " .. cache_stats.cache_misses)
   print("  Hit rate: " .. string.format("%.1f", stats.cache_hit_rate * 100) .. "%")
   
   print("\nRecursion Statistics:")
   print("  Current depth: " .. recursion_stats.current_depth)
   print("  Max depth: " .. recursion_stats.max_depth)
   print("  Depth limit exceeded: " .. recursion_stats.depth_limit_exceeded)
   
   if #recursion_stats.problematic_types > 0 then
      print("  Problematic types:")
      for _, typ in ipairs(recursion_stats.problematic_types) do
         print("    - " .. typ)
      end
   end
   
   print(string.rep("=", 60) .. "\n")
end

return InferencePerformanceOptimizer
