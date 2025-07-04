local tl = require("teal.api.v2")
local util = require("spec.util")

describe("store comments in syntax tree", function()
    it("comments before implicit global function", function()
        local result = tl.check_string([[
            -- this is a comment
            function --[==[ignore me]==] foo() end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("global_function", result.ast[1].kind)
        assert.same("-- this is a comment", result.ast[1].comments[1].text)
    end)
    it("comments before local function", function()
        local result = tl.check_string([[
            -- this is a comment
            local function --[==[ignore me]==] foo() end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_function", result.ast[1].kind)
        assert.same("-- this is a comment", result.ast[1].comments[1].text)
    end)
    it("comments before local variable declaration", function()
        local result = tl.check_string([[
            -- this is a comment
            local --[==[ignore me]==] x = 42
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_declaration", result.ast[1].kind)
        assert.same("-- this is a comment", result.ast[1].comments[1].text)
    end)
    it("comments before local type declaration", function()
        local result = tl.check_string([[
            -- this is a comment
            local --[==[ignore me]==] type Foo = number
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_type", result.ast[1].kind)
        assert.same("-- this is a comment", result.ast[1].comments[1].text)
    end)
    it("comments before local macroexp", function()
        local result = tl.check_string([[
            -- this is a comment
            local --[==[ignore me]==] macroexp foo(): number
                return 2
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_macroexp", result.ast[1].kind)
        assert.same("-- this is a comment", result.ast[1].comments[1].text)
    end)
    it("comments before local record declaration", function()
        local result = tl.check_string([[
            -- this is a comment
            local --[==[ignore me]==] record Foo
                x: number
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_type", result.ast[1].kind)
        assert.same("-- this is a comment", result.ast[1].comments[1].text)
    end)
    it("comments before local enum declaration", function()
        local result = tl.check_string([[
            -- this is a comment
            local --[==[ignore me]==] enum Foo
                "A"
                "B"
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_type", result.ast[1].kind)
        assert.same("-- this is a comment", result.ast[1].comments[1].text)
    end)
    it("comments before local interface declaration", function()
        local result = tl.check_string([[
            -- this is a comment
            local --[==[ignore me]==] interface Foo
                x: number
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_type", result.ast[1].kind)
        assert.same("-- this is a comment", result.ast[1].comments[1].text)
    end)
    it("comments before global function", function()
        local result = tl.check_string([[
            -- this is a comment
            global --[==[ignore me]==] function foo() end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("global_function", result.ast[1].kind)
        assert.same("-- this is a comment", result.ast[1].comments[1].text)
    end)
    it("comments before global variable declaration", function()
        local result = tl.check_string([[
            -- this is a comment
            global --[==[ignore me]==] x = 42
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("global_declaration", result.ast[1].kind)
        assert.same("-- this is a comment", result.ast[1].comments[1].text)
    end)
    it("comments before global type declaration", function()
        local result = tl.check_string([[
            -- this is a comment
            global --[==[ignore me]==] type Foo = number
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("global_type", result.ast[1].kind)
        assert.same("-- this is a comment", result.ast[1].comments[1].text)
    end)
    it("comments before global record declaration", function()
        local result = tl.check_string([[
            -- this is a comment
            global --[==[ignore me]==] record Foo
                x: number
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("global_type", result.ast[1].kind)
        assert.same("-- this is a comment", result.ast[1].comments[1].text)
    end)
    it("comments before global enum declaration", function()
        local result = tl.check_string([[
            -- this is a comment
            global --[==[ignore me]==] enum Foo
                "A"
                "B"
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("global_type", result.ast[1].kind)
        assert.same("-- this is a comment", result.ast[1].comments[1].text)
    end)
    it("comments before global interface declaration", function()
        local result = tl.check_string([[
            -- this is a comment
            global --[==[ignore me]==] interface Foo
                x: number
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("global_type", result.ast[1].kind)
        assert.same("-- this is a comment", result.ast[1].comments[1].text)
    end)
    it("comments before record fields", function()
        local result = tl.check_string([[
            local record Foo
                -- this is a comment
                x: number
                -- another comment
                y: string
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_type", result.ast[1].kind)
        assert.same("newtype", result.ast[1].value.kind)
        local record_def = result.ast[1].value.newtype.def
        assert.same("record", record_def.typename)
        local expected_comments = {
            x = "-- this is a comment",
            y = "-- another comment"
        }
        for field_name, _ in pairs(record_def.fields) do
            assert.same(expected_comments[field_name], record_def.field_comments[field_name][1][1].text)
        end
    end)
    it("comments before record type fields", function()
        local result = tl.check_string([[
            local record Foo
                -- this is a comment
                type x = number
                -- another comment
                type y = string
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_type", result.ast[1].kind)
        assert.same("newtype", result.ast[1].value.kind)
        local record_def = result.ast[1].value.newtype.def
        assert.same("record", record_def.typename)
        local expected_comments = {
            x = "-- this is a comment",
            y = "-- another comment"
        }
        for field_name, _ in pairs(record_def.fields) do
            assert.same(expected_comments[field_name], record_def.field_comments[field_name][1][1].text)
        end
    end)
    it("comments before record nested declarations", function()
        local result = tl.check_string([[
            local record Foo
                -- this is a comment
                record Bar
                    x: number
                end
                -- another comment
                interface Baz
                    y: string
                end
                -- yet another comment
                enum Qux
                    "A"
                    "B"
                end
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_type", result.ast[1].kind)
        assert.same("newtype", result.ast[1].value.kind)
        local record_def = result.ast[1].value.newtype.def
        assert.same("record", record_def.typename)
        local expected_comments = {
            Bar = "-- this is a comment",
            Baz = "-- another comment",
            Qux = "-- yet another comment"
        }
        for field_name, _ in pairs(record_def.fields) do
            assert.same(expected_comments[field_name], record_def.field_comments[field_name][1][1].text)
        end
    end)
    it("comments before record metafields", function()
        local result = tl.check_string([[
            local record Foo
                -- this is a comment
                metamethod __call: function(Foo, string, number): string
                -- another comment
                metamethod __add: function(Foo, Foo): Foo
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_type", result.ast[1].kind)
        assert.same("newtype", result.ast[1].value.kind)
        local record_def = result.ast[1].value.newtype.def
        assert.same("record", record_def.typename)
        local expected_comments = {
            ["__call"] = "-- this is a comment",
            ["__add"] = "-- another comment",
        }
        for field_name, _ in pairs(record_def.meta_fields) do
            assert.same(expected_comments[field_name], record_def.meta_field_comments[field_name][1][1].text)
        end
    end)
    it("comments before record overloaded functions", function()
        local result = tl.check_string([[
            local record Foo
                -- this is a comment
                bar: function(string): string
                -- another comment
                bar: function(number): number
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_type", result.ast[1].kind)
        assert.same("newtype", result.ast[1].value.kind)
        local record_def = result.ast[1].value.newtype.def
        assert.same("record", record_def.typename)
        local expected_comments = {
            ["bar"] = {"-- this is a comment", "-- another comment"}
        }
        for field_name, _ in pairs(record_def.fields) do
            local n = #record_def.field_comments[field_name]
            assert.same(2, n)
            for i = 1, n do
                if not expected_comments[field_name][i] then
                    assert.same({}, record_def.field_comments[field_name][i])
                else
                    assert.same(expected_comments[field_name][i], record_def.field_comments[field_name][i][1].text)
                end
            end
        end
    end)
    it("comments before interface fields", function()
        local result = tl.check_string([[
            local interface Foo
                -- this is a comment
                x: number
                -- another comment
                y: string
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_type", result.ast[1].kind)
        assert.same("newtype", result.ast[1].value.kind)
        local interface_def = result.ast[1].value.newtype.def
        assert.same("interface", interface_def.typename)
        local expected_comments = {
            x = "-- this is a comment",
            y = "-- another comment"
        }
        for field_name, _ in pairs(interface_def.fields) do
            assert.same(expected_comments[field_name], interface_def.field_comments[field_name][1][1].text)
        end
    end)
    it("comments before interface type fields", function()
        local result = tl.check_string([[
            local interface Foo
                -- this is a comment
                type x = number
                -- another comment
                type y = string
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_type", result.ast[1].kind)
        assert.same("newtype", result.ast[1].value.kind)
        local interface_def = result.ast[1].value.newtype.def
        assert.same("interface", interface_def.typename)
        local expected_comments = {
            x = "-- this is a comment",
            y = "-- another comment"
        }
        for field_name, _ in pairs(interface_def.fields) do
            assert.same(expected_comments[field_name], interface_def.field_comments[field_name][1][1].text)
        end
    end)
    it("comments before interface nested declarations", function()
        local result = tl.check_string([[
            local interface Foo
                -- this is a comment
                interface Bar
                    x: number
                end
                -- another comment
                interface Baz
                    y: string
                end
                -- yet another comment
                enum Qux
                    "A"
                    "B"
                end
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_type", result.ast[1].kind)
        assert.same("newtype", result.ast[1].value.kind)
        local interface_def = result.ast[1].value.newtype.def
        assert.same("interface", interface_def.typename)
        local expected_comments = {
            Bar = "-- this is a comment",
            Baz = "-- another comment",
            Qux = "-- yet another comment"
        }
        for field_name, _ in pairs(interface_def.fields) do
            assert.same(expected_comments[field_name], interface_def.field_comments[field_name][1][1].text)
        end
    end)
    it("comments before interface metafields", function()
        local result = tl.check_string([[
            local interface Foo
                -- this is a comment
                metamethod __call: function(Foo, string, number): string
                -- another comment
                metamethod __add: function(Foo, Foo): Foo
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_type", result.ast[1].kind)
        assert.same("newtype", result.ast[1].value.kind)
        local interface_def = result.ast[1].value.newtype.def
        assert.same("interface", interface_def.typename)
        local expected_comments = {
            ["__call"] = "-- this is a comment",
            ["__add"] = "-- another comment",
        }
        for field_name, _ in pairs(interface_def.meta_fields) do
            assert.same(expected_comments[field_name], interface_def.meta_field_comments[field_name][1][1].text)
        end
    end)
    it("comments before interface overloaded functions", function()
        local result = tl.check_string([[
            local interface Foo
                -- this is a comment
                bar: function(string): string
                -- another comment
                bar: function(number): number
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_type", result.ast[1].kind)
        assert.same("newtype", result.ast[1].value.kind)
        local interface_def = result.ast[1].value.newtype.def
        assert.same("interface", interface_def.typename)
        local expected_comments = {
            ["bar"] = {"-- this is a comment", "-- another comment"}
        }
        for field_name, _ in pairs(interface_def.fields) do
            local n = #interface_def.field_comments[field_name]
            assert.same(2, n)
            for i = 1, n do
                if not expected_comments[field_name][i] then
                    assert.same({}, interface_def.field_comments[field_name][i])
                else
                    assert.same(expected_comments[field_name][i], interface_def.field_comments[field_name][i][1].text)
                end
            end
        end
    end)
    it("comments before enum values", function()
        local result = tl.check_string([[
            local enum Foo
                -- this is a comment
                "A"
                -- another comment
                "B"
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_type", result.ast[1].kind)
        assert.same("newtype", result.ast[1].value.kind)
        local enum_def = result.ast[1].value.newtype.def
        assert.same("enum", enum_def.typename)
        local expected_comments = {
            ["A"] = "-- this is a comment",
            ["B"] = "-- another comment"
        }
        for value_name, _ in pairs(enum_def.enumset) do
            assert.same(expected_comments[value_name], enum_def.value_comments[value_name][1].text)
        end
    end)
    it("comments attach to the correct entry in polymorphic function", function()
        local result = tl.check_string([[
            local record MyRecord
                f: function(integer)
                --- it can be a boolean too
                f: function(boolean)
                f: function(number)
            end
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_type", result.ast[1].kind)
        assert.same("newtype", result.ast[1].value.kind)
        local record_def = result.ast[1].value.newtype.def
        assert.same("record", record_def.typename)
        local expected_comments = {
            ["f"] = {nil, "--- it can be a boolean too", nil}
        }
        for field_name, _ in pairs(record_def.fields) do
            local n = #record_def.field_comments[field_name]
            assert.same(3, n)
            for i = 1, n do
                if not expected_comments[field_name][i] then
                    assert.same({}, record_def.field_comments[field_name][i])
                else
                    assert.same(expected_comments[field_name][i], record_def.field_comments[field_name][i][1].text)
                end
            end
        end
    end)

    it("only attaches consecutive comments", function()
        local result = tl.check_string([[
            -- this is a comment
            -- this is another comment

            -- this is a third comment
            local foo = 47
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_declaration", result.ast[1].kind)
        assert.same(1, #result.ast[1].comments)
        assert.same("-- this is a third comment", result.ast[1].comments[1].text)
        assert.same(2, #result.ast.unattached_comments)
        assert.same("-- this is a comment", result.ast.unattached_comments[1].text)
        assert.same("-- this is another comment", result.ast.unattached_comments[2].text)
    end)

    it("only attaches comment that start just before the statement", function()
        local result = tl.check_string([[
            -- this is a comment
            --[=[this is a long comment]=]

            local foo = 47
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_declaration", result.ast[1].kind)
        assert.same(nil, result.ast[1].comments)
        assert.same(2, #result.ast.unattached_comments)
        assert.same("-- this is a comment", result.ast.unattached_comments[1].text)
        assert.same("--[=[this is a long comment]=]", result.ast.unattached_comments[2].text)
    end)

    it("only attaches comments to declarations", function()
        local result = tl.check_string([[
            -- this is a comment
            local foo = 47
            --[=[this is a long comment]=]
            foo = 48
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(2, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_declaration", result.ast[1].kind)
        assert.same(1, #result.ast[1].comments)
        assert.same("-- this is a comment", result.ast[1].comments[1].text)
        assert.same(1, #result.ast.unattached_comments)
        assert.same("--[=[this is a long comment]=]", result.ast.unattached_comments[1].text)
    end)
    it("only attaches long comments that end just before the statement", function()
        local result = tl.check_string([[
            --[=[
                this is a long comment
                that spans multiple lines
            ]=]
            local foo = 47

            --[=[
                this is another long comment
                that spans multiple lines
            ]=]

            local bar = 48
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(2, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_declaration", result.ast[1].kind)
        assert.same(1, #result.ast[1].comments)
        assert.same("--[=[\n                this is a long comment\n                that spans multiple lines\n            ]=]", result.ast[1].comments[1].text)
        assert.same(1, #result.ast.unattached_comments)
        assert.same("--[=[\n                this is another long comment\n                that spans multiple lines\n            ]=]", result.ast.unattached_comments[1].text)
    end)
    it("only attaches at most one long comment", function()
        local result = tl.check_string([[
            --[=[
                this is a long comment
                that spans multiple lines
            ]=]
            --[=[
                this is another long comment
                that spans multiple lines
            ]=]
            local foo = 47
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_declaration", result.ast[1].kind)
        assert.same(1, #result.ast[1].comments)
        assert.same("--[=[\n                this is another long comment\n                that spans multiple lines\n            ]=]", result.ast[1].comments[1].text)
        assert.same(1, #result.ast.unattached_comments)
        assert.same("--[=[\n                this is a long comment\n                that spans multiple lines\n            ]=]", result.ast.unattached_comments[1].text)
    end)
    it("does not mix different comment types", function()
        local result = tl.check_string([[
            -- this is a comment
            --[=[this is a long comment]=]
            -- this is another comment
            local foo = 47
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_declaration", result.ast[1].kind)
        assert.same(1, #result.ast[1].comments)
        assert.same("-- this is another comment", result.ast[1].comments[1].text)
        assert.same(2, #result.ast.unattached_comments)
        assert.same("-- this is a comment", result.ast.unattached_comments[1].text)
        assert.same("--[=[this is a long comment]=]", result.ast.unattached_comments[2].text)
    end)
    it("does attach same line long comments", function()
        local result = tl.check_string([[
            --[=[this is a long comment]=] local foo = 47
        ]])
        assert.same({}, result.syntax_errors)
        assert.same(1, #result.ast)
        assert.same("statements", result.ast.kind)
        assert.same("local_declaration", result.ast[1].kind)
        assert.same(1, #result.ast[1].comments)
        assert.same("--[=[this is a long comment]=]", result.ast[1].comments[1].text)
        assert.same(nil, result.ast.unattached_comments)
    end)
end)
