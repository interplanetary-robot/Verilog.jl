const modules = Array{Symbol, 1}()

################################################################################
## INTEGER VERSION.
## a thin shim over the binary version, but shows how effective method rewrite
## can be.

function inject!(f::Expr, expr)
  unshift!(f.args[2].args, expr)
end

function set_output_type!(f::Expr, output_type::Symbol)
  #if the function already has an expression type
  if f.args[1].head == :(::)
    f.args[1].args[2] = output_type
  else
    call_list = f.args[1]
    f.args[1] = Expr(:(::))
    push!(f.args[1].args, call_list)
    push!(f.args[1].args, output_type)
  end
end

function substitute_wire_inputs!(f::Expr)
  #issue a list of places where we need extra wire macros.
  wire_macro_list = Dict{Symbol,Expr}()

  for argument in f.args[1].args[1].args[2:end]
    if isa(argument, Symbol)
      continue
    end

    #a bare wire statement.
    if argument.args[2] == :Wire
      #reset it to Unsigned.
      argument.args[2] = :Unsigned
    elseif argument.args[2] == :SingleWire
      wire_macro_list[argument.args[1]] = :(0:0)
      argument.args[2] = :Unsigned
    elseif isa(argument.args[2], Expr) &&
      (argument.args[2].head == :curly) &&
      (argument.args[2].args[1] == :Wire) &&
      (argument.args[2].args[2].head == :(:))

      #save the needed symbol and wire range parameter.
      wire_macro_list[argument.args[1]] = argument.args[2].args[2]

      #then reset it to Unsigned.
      argument.args[2] = :Unsigned
    end
  end

  wire_macro_list
end

function inject_wire_macro!(f::Expr, identifier, structure)
  inject!(f, :(@wire $identifier $structure))
end

function integer_translate(f::Expr)
  f_integer = copy(f)

  set_output_type!(f_integer, :Unsigned)

  input_wire_list = substitute_wire_inputs!(f_integer)

  for key in keys(input_wire_list)
    inject_wire_macro!(f_integer, key, input_wire_list[key])
  end

  f_integer
end

################################################################################
## MODULE VERSION.
## complete rewrite of the function expression
##

function strip_output_definition!(f::Expr)
  #if the function already has an expression type
  if f.args[1].head == :(::)
    f.args[1] = f.args[1].args[1]# = output_type
  end
end


function strip_wire_inputs!(f::Expr)
  #issue a list of places where we need extra wire macros.
  inputs_list = Vector{Tuple{Symbol, Any}}()

  #make a copy of the new arguments list.
  new_arguments = deepcopy(f.args[1].args[1:1])
  haswires = false

  for argument in f.args[1].args[2:end]
    #a case where we have an untyped argument
    if isa(argument, Symbol)
      push!(new_arguments, argument)
      continue
    end

    #a bare wire statement... Presume a @wire macro statement already exists.
    if argument.args[2] == :Wire
      #push a blank input symbol to the inputs_list stack.
      push!(inputs_list, (argument.args[1], nothing))
    elseif argument.args[2] == :SingleWire
      push!(inputs_list, (argument.args[1], :(0:0)))
    elseif isa(argument.args[2], Expr) &&
      (argument.args[2].head == :curly) &&
      (argument.args[2].args[1] == :Wire) &&
      (argument.args[2].args[2].head == :(:))
      #save the needed symbol and wire range parameter.
      push!(inputs_list, (argument.args[1], argument.args[2].args[2]))
    else
      push!(new_arguments, argument)
    end
  end

  #take the old arguments list and make them the new arguments
  f.args[1].args = new_arguments

  inputs_list
end

function inject_inputs!(f::Expr, inputlist)
  #reverse it, because inject! prepends
  for input in reverse(inputlist)
    inject!(f, :(Verilog.@input $(input[1]) $(input[2])))
  end
end

function inject_verilog_generator!(f::Expr)
  fn_symbol = f.args[1].args[1]
  inject!(f, :(Verilog.@verigen $fn_symbol))
end

#this should be passed the function block.
function linebyline_adaptor!(block::Expr, input_list)
  newargs = []
  for argument in block.args
    if (argument.head == :macrocall)  &&
        (argument.args[1] == Symbol("@wire"))

      #search through the input list for a corresponding input statement and set
      #the parameter value.
      for idx = 1:length(input_list)
        if (input_list[idx][1] == argument.args[2])
          input_list[idx] = (argument.args[2], argument.args[3])
        end
      end
    elseif (argument.head == :(=))
      #all assignments should be surrounded by check to update the list.
      identifier = argument.args[1]
      assignment = argument.args[2]
      push!(newargs, :(Verilog.@assign $identifier $assignment))
    elseif (argument.head == :for)
      #println("forloop block:")
      linebyline_adaptor!(argument.args[2])
      push!(newargs, argument)
    else
      push!(newargs, argument)
    end
  end
  #replace the old arguments with new arguments.
  block.args = newargs
end

function inject_verilog_finisher!(f::Expr)
  push!(f.args[2].args, :(Verilog.@verifin))
end

function module_translate(f::Expr)
  #for now, do nothing.
  f_module = copy(f)
  #check if there's an existing output definition and send it to nothing.
  strip_output_definition!(f_module)
  #strip any inputs that happen to be wires
  input_list = strip_wire_inputs!(f_module)

  (length(input_list) > 0) || throw(ArgumentError("selected function does not appear to be a verilog module."))

  #do a line-by-line analysis and readapt the contents of f_module
  linebyline_adaptor!(f_module.args[2], input_list)

  #inject input macros.
  inject_inputs!(f_module, input_list)

  #next, inject the script generator
  inject_verilog_generator!(f_module)

  #add the last line, which will finish the verilog analysis.
  inject_verilog_finisher!(f_module)

  return f_module
end

################################################################################
# strip module names if it's not in module mode.
function strip_nonmodule!(f::Expr)
  #generate a temporary block
  stripped_block = []
  for argument in f.args[2].args
    if (argument.head == :macrocall) && (argument.args[1] == Symbol("@name_suffix"))
      continue
    end
    push!(stripped_block, argument)
  end
  #reset the block
  f.args[2].args = stripped_block
end

################################################################################

macro verilog(f)
  #first check to see if it's a function.
  if f.head == :function
    #make three copies of the function.

    #First, make the module version.
    f_module = module_translate(f)

    #strip module instructions
    strip_nonmodule!(f)

    #Last make version that substitutes all wires with integers.
    f_integer = integer_translate(f)

    esc(quote
      #release all three forms of the function.
      $f
      $f_integer
      $f_module
    end)
  else
    throw(ArgumentError("@verilog macro must be run on a function."))
  end
end

export @verilog
