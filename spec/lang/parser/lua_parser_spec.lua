util = require("spec.util")

describe("lua next-line function calls", function()
    it("allows calls on the next line in lua parsing mode",  util.check_lua([=[
        local function test(a)
        end

        test
        ("hello world")
     ]=]))
     
    it("allows string literal calls on the next line in lua parsing mode",  util.check_lua([=[
        local function test(a)
        end

        test
        "hello world"
     ]=]))
     
    it("allows calls after multiline string literals in lua parsing mode",  util.check_lua([=[
        local function test(a): function()
           return function() end
        end
        test[[hello
        world]]()
     ]=]))
end)