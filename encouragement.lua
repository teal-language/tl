return function ()
  local busted   = require 'busted'
  local handler  = require 'busted.outputHandlers.base'()

  handler.suiteEnd = function()
    io.write(("%d passed / %d failed / %d errors\n"):format(
        handler.successesCount,
        handler.failuresCount,
        handler.errorsCount))
    return nil, true
  end

  busted.subscribe({'suite','end'}, handler.suiteEnd)
  return handler
end
