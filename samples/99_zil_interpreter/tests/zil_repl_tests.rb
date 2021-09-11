def test_repl(args, assert)
  zil_context = build_zil_context(args)
  repl_fiber = build_repl_fiber(zil_context)

  repl_fiber.resume '<+ 2 3>'

  assert.equal! zil_context.outputs, [
    '-> 5'
  ]
end

def test_repl_parsing_error(args, assert)
  zil_context = build_zil_context(args)
  repl_fiber = build_repl_fiber(zil_context)

  repl_fiber.resume '<+ xxxxx'

  assert.equal! zil_context.outputs, [
    'ParserError: Invalid syntax at 0:8!'
  ]
end

def test_repl_eval_error(args, assert)
  zil_context = build_zil_context(args)
  repl_fiber = build_repl_fiber(zil_context)

  repl_fiber.resume '%<COND>'

  assert.equal! zil_context.outputs, [
    'EvalError: Cannot eval %<COND>'
  ]
end

def test_repl_function_error(args, assert)
  zil_context = build_zil_context(args)
  repl_fiber = build_repl_fiber(zil_context)

  repl_fiber.resume '<LVAL NONEXISTING>'

  assert.equal! zil_context.outputs, [
    'FunctionError: No local value for :NONEXISTING'
  ]
end

def build_repl_fiber(zil_context)
  Fiber.new {
    zil_context.globals[:REPL].call [], zil_context
  }.tap { |result|
    result.resume # Initial execution
  }
end