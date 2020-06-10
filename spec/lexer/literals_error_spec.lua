local tl = require("tl")

describe("lexer errors", function()
    pending("when number suffixes are invalid", function()
        local tokens, errors = tl.lex("100llilliiu")
        assert.same(0, #tokens)
     end)
end)
