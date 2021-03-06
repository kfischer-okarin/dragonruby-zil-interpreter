# coding: utf-8
class FunctionError < StandardError; end

class FlowControlException < StandardError; end
class AgainException < FlowControlException; end # TBD: ReturnException will also use FlowControlException as base class

def define_for_evaled_arguments(&implementation)
  lambda { |arguments, context|
    evaled_arguments = arguments.map { |argument| eval_zil argument, context }
    implementation.call(evaled_arguments, context)
  }
end

# helper method to check for argument count
# to be used with rethrowing the error with the `ROUTINE` name in front
def argc!(arguments, count, cmp_type = :==)
  case cmp_type
  when :===
    raise ArgumentError, "`count` (#{count}) not a `Range` object" unless count.is_a?(Range)
    raise FunctionError, "has an arity (#{count.begin} ≤ n ≤ #{count.end}), got #{arguments.length}" unless count === arguments.length
  else
    raise FunctionError, "has an arity (n #{cmp_type} #{count}), got #{arguments.length}" unless arguments.length.send(cmp_type, count)
  end
end

def expect_argument_count!(arguments, expected_count)
  argc!(arguments, expected_count)
end

def expect_argument_count_in_range!(arguments, range)
  argc!(arguments, range, :===)
end

def expect_minimum_argument_count!(arguments, min_count)
  argc!(arguments, min_count, :>=)
end

ZIL_BUILTINS = {}

ZIL_BUILTINS[:LVAL] = define_for_evaled_arguments { |arguments, context|
  expect_argument_count!(arguments, 1)
  var_atom = arguments[0]

  get_local_from_context(context, var_atom)
}

ZIL_BUILTINS[:GVAL] = define_for_evaled_arguments { |arguments, context|
  expect_argument_count!(arguments, 1)
  var_atom = arguments[0]
  raise FunctionError, "No global value for #{var_atom.inspect}" unless context.globals.key? var_atom

  context.globals[var_atom]
}

ZIL_BUILTINS[:VALUE] = define_for_evaled_arguments { |arguments, context|
  expect_argument_count!(arguments, 1)
  var_atom = arguments[0]

  result = get_local_from_context(context, var_atom, throw_flag: false)
  if result != :ZIL_LOCAL_VALUE_NOT_ASSIGNED
    result
  else
    context.globals[var_atom] || (raise FunctionError, "No local nor global value for #{var_atom.inspect}")
  end
}

# <+ ...>
ZIL_BUILTINS[:+] = define_for_evaled_arguments { |arguments|
  arguments.inject(0, :+)
}

# <- ...>
ZIL_BUILTINS[:-] = define_for_evaled_arguments { |arguments|
  if arguments.length == 0
    0
  elsif arguments.length == 1
    0 - arguments[0]
  else
    arguments.inject(:-)
  end
}

# <* ...>
ZIL_BUILTINS[:*] = define_for_evaled_arguments { |arguments|
  arguments.inject(1, :*)
}

# </ ...>
ZIL_BUILTINS[:/] = define_for_evaled_arguments { |arguments|
  # https://mdl-language.readthedocs.io/en/latest/03-built-in-functions/
  # "the division of two FIXes gives a FIX with truncation, not rounding, of the remainder:
  # the intermediate result remains a FIX until a FLOAT argument is encountered."

  if arguments.length == 0 # </ >
    1
  elsif arguments.length == 1 # </ divisor>
    dividend = 1
    divisor = arguments[0]
    if divisor.class == Float
      dividend.to_f / divisor
    else
      (dividend / divisor).to_i
    end
  else  # </ dividend divisor ...>
    i = 1
    dividend = arguments[0]

    while i < arguments.length
      divisor = arguments[i]

      if dividend.class == Float || divisor.class == Float
        dividend = dividend.to_f / divisor.to_f
      else
        dividend = (dividend / divisor).to_i
      end

      i += 1
    end

    dividend
  end
}

# <MIN ...>
ZIL_BUILTINS[:MIN] = define_for_evaled_arguments { |arguments|
  raise FunctionError, "MIN with 0 arguments not supported" if arguments.length == 0
  arguments.min
}

# <RANDOM ...>
ZIL_BUILTINS[:RANDOM] = define_for_evaled_arguments { |arguments|
  raise FunctionError, "RANDOM only supported with 1 argument!" if arguments.length != 1
  range = arguments[0]
  rand(range) + 1
}

ZIL_BUILTINS[:SET] = define_for_evaled_arguments { |arguments, context|
  expect_argument_count!(arguments, 2)
  var_atom = arguments[0]
  context.locals[var_atom] = arguments[1]
}

ZIL_BUILTINS[:SETG] = define_for_evaled_arguments { |arguments, context|
  expect_argument_count!(arguments, 2)
  var_atom = arguments[0]
  context.globals[var_atom] = arguments[1]
}

ZIL_BUILTINS[:BAND] = define_for_evaled_arguments { |arguments|
  expect_argument_count!(arguments, 2)
  arguments[0] & arguments[1]
}

ZIL_BUILTINS[:BOR] = define_for_evaled_arguments { |arguments|
  expect_argument_count!(arguments, 2)
  arguments[0] | arguments[1]
}

ZIL_BUILTINS[:BTST] = define_for_evaled_arguments { |arguments|
  expect_argument_count!(arguments, 2)
  (arguments[0] ^ arguments[1]).zero?
}

ZIL_BUILTINS[:BCOM] = define_for_evaled_arguments { |arguments|
  expect_argument_count!(arguments, 1)
  ~(arguments[0])
}

ZIL_BUILTINS[:SHIFT] = define_for_evaled_arguments { |arguments|
  expect_argument_count!(arguments, 2)
  arguments[0] << arguments[1]
}

# <MOD ...>
ZIL_BUILTINS[:MOD] = define_for_evaled_arguments { |arguments|
  raise FunctionError, "MOD only supported with 2 argument!" if arguments.length != 2
  raise FunctionError, "MOD only supported with FIX argument types!" if arguments[0].class != Fixnum || arguments[1].class != Fixnum
  arguments[0] % arguments[1]
}

# <0? ...>
ZIL_BUILTINS[:"0?"] = define_for_evaled_arguments { |arguments|
  raise FunctionError, "0? only supported with 1 argument!" if arguments.length != 1
  arguments[0] == 0 || arguments[0] == 0.0
}

# <1? ...>
ZIL_BUILTINS[:"1?"] = define_for_evaled_arguments { |arguments|
  raise FunctionError, "1? only supported with 1 argument!" if arguments.length != 1
  arguments[0] == 1 || arguments[0] == 1.0
}

# <G? ...>
ZIL_BUILTINS[:G?] = define_for_evaled_arguments { |arguments|
  raise FunctionError, "G? only supported with 2 arguments!" if arguments.length != 2
  arguments[0] > arguments[1]
}

# <L? ...>
ZIL_BUILTINS[:L?] = define_for_evaled_arguments { |arguments|
  raise FunctionError, "L? only supported with 2 arguments!" if arguments.length != 2
  arguments[0] < arguments[1]
}

# <NOT ...>
ZIL_BUILTINS[:NOT] = define_for_evaled_arguments { |arguments|
  raise FunctionError, "NOT only supported with 1 argument!" if arguments.length != 1
  arguments[0] == false
}

# <AND ...> (FSUBR)
ZIL_BUILTINS[:AND] = lambda { |arguments, context|
  result = false
  arguments.each { |a|
    result = eval_zil(a, context)
    return false if result == false
  }
  result
}

#! shouldn't those just be doable with `Enumerable#all?`
# <AND? ...> (SUBR)
ZIL_BUILTINS[:AND?] = define_for_evaled_arguments { |arguments|
  result = false
  arguments.each { |a|
    result = a
    return false if a == false
  }
  result
}

# or with `Enumerable#any?` in this case
# <OR ...>  (FSUBR)
ZIL_BUILTINS[:OR] = lambda { |arguments, context|
  arguments.each { |a|
    result = eval_zil(a, context)
    return result unless result == false
  }
  false
}

# <OR? ...>  (SUBR)
ZIL_BUILTINS[:OR?] = define_for_evaled_arguments { |arguments|
  arguments.each { |a|
    return a unless a == false
  }
  false
}

# <COND () ...> (FSUBR)
ZIL_BUILTINS[:COND] = lambda { |arguments, context|
  # COND goes walking down its clauses, EVALing the first element of each clause,
  # looking for a non-FALSE result. As soon as it finds a non-FALSE, it forgets
  # about all the other clauses and evaluates, in order, the other elements of
  # the current clause and returns the last thing it evaluates.
  #
  raise FunctionError, "COND requires at least one parameter!" unless arguments.length > 0

  i = 0
  while i < arguments.length
    clause = arguments[i]

    raise FunctionError, "Arguments to COND must be of List type!" unless clause.class == Syntax::List
    raise FunctionError, "COND clauses require at least 1 item!" unless clause.elements.length > 0

    clause_eval = eval_zil(clause.elements[0], context)
    if clause_eval != false # eval 0th element for non-false
      clause.elements.drop(1).each { |clause_element|
        clause_eval = eval_zil(clause_element, context)
      }
      return clause_eval
    end
    i += 1
  end

  false
}

ZIL_BUILTINS[:OBJECT] = define_for_evaled_arguments { |arguments, context|
  # Objects have a name, and a list of properties and values
  expect_minimum_argument_count!(arguments, 1)

  object_name, *object_properties = arguments

  object = { properties: {} }
  object[:name] = object_name

  object_properties.each do |property|
    raise FunctionError, "OBJECT properties require a name and values!" unless property.length > 1

    property_name, *property_values = property

    object[:properties][property_name] = property_values.length == 1 ? property_values[0] : property_values
  end

  context.globals[object_name] = object
}

# Tables are represented internally as arrays which contain "bytes" which can be set/get with PUTB/GETB
# Every other data type is saved as a "word" so basically 2 bytes -
# but for convenience's sake those words are just stored as two byte elements: [value, 0]
# Since in Zork single bytes of words are never accessed - nor vice-versa - this kind of representation
# should be fine.
ZIL_BUILTINS[:TABLE] = define_for_evaled_arguments { |arguments|
  flags, values = ZIL::Table.get_flags_and_values arguments

  ZIL::Table.build flags: flags, values: values
}

ZIL_BUILTINS[:ITABLE] = define_for_evaled_arguments { |arguments|
  if arguments[0].is_a? Symbol
    specifier = arguments[0]
    raise "ITABLE Specifier #{specifier} not yet supported" unless specifier == :NONE

    size = arguments[1]
    flags, default_values = ZIL::Table.get_flags_and_values arguments[2..-1]
  else
    size = arguments[0]
    flags, default_values = ZIL::Table.get_flags_and_values arguments[1..-1]
  end

  ZIL::Table.build flags: flags, values: default_values * size
}

ZIL_BUILTINS[:LTABLE] = define_for_evaled_arguments { |arguments|
  flags, values = ZIL::Table.get_flags_and_values arguments
  flags << :LENGTH unless flags.include? :LENGTH

  ZIL::Table.build flags: flags, values: values
}

ZIL_BUILTINS[:GET] = define_for_evaled_arguments { |arguments|
  expect_argument_count! arguments, 2

  table = arguments[0]
  index = arguments[1]
  table[index * 2] # Double the index since table stores bytes
}

ZIL_BUILTINS[:PUT] = define_for_evaled_arguments { |arguments|
  expect_argument_count! arguments, 3

  table = arguments[0]
  index = arguments[1]
  value = arguments[2]
  table[index * 2] = value # Double the index since table stores bytes
  table
}

ZIL_BUILTINS[:GETB] = define_for_evaled_arguments { |arguments|
  expect_argument_count! arguments, 2

  table = arguments[0]
  index = arguments[1]
  table[index]
}

ZIL_BUILTINS[:PUTB] = define_for_evaled_arguments { |arguments|
  expect_argument_count! arguments, 3

  table = arguments[0]
  index = arguments[1]
  value = arguments[2]
  table[index] = value
  table
}

ZIL_BUILTINS[:NTH] = define_for_evaled_arguments { |arguments|
  expect_argument_count! arguments, 2

  table = arguments[0]
  one_based_index = arguments[1]
  table[one_based_index - 1]
}

# REST and BACK are using a special ZIL::ArrayWithOffset object which implements
# the element accessor ([] and []=) which respect the offset but modify the original
# array
ZIL_BUILTINS[:REST] = define_for_evaled_arguments { |arguments|
  expect_argument_count_in_range! arguments, (1..2)

  array_like_value = arguments[0]
  offset = arguments[1] || 1
  ZIL::ArrayWithOffset.from(array_like_value, offset: offset)
}

ZIL_BUILTINS[:BACK] = define_for_evaled_arguments { |arguments|
  expect_argument_count_in_range! arguments, (1..2)

  array_like_value = arguments[0]
  offset = arguments[1] || 1
  ZIL::ArrayWithOffset.from(array_like_value, offset: -offset)
}

ZIL_BUILTINS[:EMPTY?] = lambda { |arguments, context|
  expect_argument_count! arguments, 1

  array_like_value = arguments[0]
  ZIL_BUILTINS[:LENGTH].call([array_like_value], context).zero?
}

ZIL_BUILTINS[:LENGTH] = define_for_evaled_arguments { |arguments|
  expect_argument_count! arguments, 1

  array_like_value = arguments[0]
  array_like_value.size
}

ZIL_BUILTINS[:LENGTH?] = lambda { |arguments, context|
  expect_argument_count! arguments, 2

  array_like_value = arguments[0]
  length_max = arguments[1]
  ZIL_BUILTINS[:LENGTH].call([array_like_value], context) <= length_max
}

ZIL_BUILTINS[:PUTREST] = define_for_evaled_arguments { |arguments|
  expect_argument_count! arguments, 2

  array_like_value = arguments[0]
  new_rest = arguments[1]
  array_like_value[1..-1] = new_rest.dup
  array_like_value
}
#<ROUTINE name (arguments) #DECL body>
ZIL_BUILTINS[:ROUTINE] = lambda { |arguments, context|
  raise FunctionError, "ROUTINE must have a body!" unless arguments.length > 2
  raise FunctionError, "ROUTINE must provide an argument list!" unless arguments.length > 1
  raise FunctionError, "ROUTINE must provide an argument list! (" + arguments[1].class + ")" unless arguments[1].class == Syntax::List

  name = arguments[0]
  signature = arguments[1]
  body = arguments[2..-1]

  routine = ZIL::Routine.new(name, signature, body)
  context.globals[name] = routine.method(:call)
}

ZIL_BUILTINS[:AGAIN] = lambda { |arguments, context|
  raise AgainException
}

# <ASSIGNED? ...> (FSUBR)
ZIL_BUILTINS[:ASSIGNED?] = lambda { |arguments, context|
  expect_argument_count!(arguments, 1)
  var_atom = arguments[0]

  result = false
  [context.locals, *context.locals_stack].each { |stack|
    if stack.key? var_atom
      result = true
      break
    end
  }

  result
}

# <GASSIGNED? ...> (FSUBR)
ZIL_BUILTINS[:GASSIGNED?] = lambda { |arguments, context|
  expect_argument_count!(arguments, 1)
  var_atom = arguments[0]
  context.globals.key? var_atom
}

