local util = require("spec.util")

describe("coroutine", function()
   describe("create", function()
      it("returns a thread", util.check([[
         local t: thread = coroutine.create(function() end)
      ]]))
   end)

   describe("isyieldable", function()
      it("returns a boolean", util.check([[
         local b: boolean = coroutine.isyieldable()
      ]]))

   end)

   describe("resume", function()
      it("returns a boolean", util.check([[
         local t = coroutine.create(function() end)
         local ok: boolean = coroutine.resume(t)
      ]]))

   end)

   describe("running", function()
      it("returns a thread and boolean", util.check([[
         local t, is_main: thread, boolean = coroutine.running()
      ]]))

   end)

   describe("status", function()
      it("returns a string", util.check([[
         local t = coroutine.create(function() end)
         local s: string = coroutine.status(t)
      ]]))

   end)

   describe("wrap", function()
      it("returns a function", util.check([[
         local f: function = coroutine.wrap(function() end)
      ]]))

   end)

   describe("yield", function()
      it("exists", util.check([[
         coroutine.create(function()
            coroutine.yield()
         end)
      ]]))

   end)
end)
