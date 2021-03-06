# Fallback implementation that starts REPL
ZIL_BUILTINS[:GO] = define_for_evaled_arguments { |_, context|
  context.globals[:REPL].call [], context
}

ZIL_BUILTINS[:REPL] = define_for_evaled_arguments { |_, context|
  context.outputs << 'ZIL REPL'
  context.outputs << 'Enter <EXIT> to quit'

  loop do
    input = Fiber.yield
    break if input == '<EXIT>'

    parsed = Parser.parse_string(input)[0]
    result = eval_zil(parsed, context)
    context.outputs << "-> #{result}"
  rescue => e
    context.outputs << "#{e.class}: #{e}"
    next
  end
}
