# module_rewrite.jl - rewriting the function as a verilog module generator


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
  param_list = Symbol[]

  for argument in f.args[1].args[2:end]
    #a case where we have an untyped argument
    if isa(argument, Symbol)
      push!(param_list, argument)
      push!(new_arguments, argument)
      continue
    end

    #a bare wire statement... Presume a @wire macro statement already exists.
    if argument.args[2] == :Wire
      #push a blank input symbol to the inputs_list stack.
      push!(inputs_list, (argument.args[1], nothing))
    elseif argument.args[2] == :SingleWire
      push!(inputs_list, (argument.args[1], :(0:0v)))
    elseif isa(argument.args[2], Expr) &&
      (argument.args[2].head == :curly) &&
      (argument.args[2].args[1] == :Wire) &&
      (argument.args[2].args[2].head == :(:))
      #save the needed symbol and wire range parameter.
      push!(inputs_list, (argument.args[1], argument.args[2].args[2]))
    else
      push!(param_list, argument.args[1])
      push!(new_arguments, argument)
    end
  end

  #take the old arguments list and make them the new arguments
  f.args[1].args = new_arguments

  inputs_list, param_list
end

function inject_inputs!(f::Expr, inputlist)
  #reverse it, because inject! prepends
  for input in reverse(inputlist)
    inject!(f, :(Verilog.@input $(input[1]) $(input[2])))
  end
end

function inject_verilog_generator!(f::Expr, params)
  fn_symbol = f.args[1].args[1]
  inject!(f, :(Verilog.@verigen($fn_symbol, $(params...))))
end

#this should be passed the function block.
function linebyline_adaptor!(block::Expr, input_list = nothing)
  newargs = []
  for argument in block.args
    if isa(argument, Symbol)
      identifier = argument
      push!(newargs, :(Verilog.@final $identifier))
    elseif (input_list != nothing) &&
        (argument.head == :macrocall)  &&
        ((argument.args[1] == Symbol("@input"))
        || (argument.args[1] == Symbol("@wire")))

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
    elseif (argument.head == :if)
      linebyline_adaptor!(argument.args[2])
      if length(argument) == 3
        linebyline_adaptor!(argument.args[3])
      end
      push!(newargs, argument)
    else
      push!(newargs, argument)
    end
  end
  #replace the old arguments with new arguments.
  block.args = newargs
  nothing
end

function inject_verilog_finisher!(f::Expr)
  push!(f.args[2].args, :(Verilog.@verifin))
end

function module_transform!(f_module::Expr, input_list, params_list)
  #do a line-by-line analysis and readapt the contents of f_module
  linebyline_adaptor!(f_module.args[2], input_list)

  #add the last line, which will finish the verilog analysis.
  inject_verilog_finisher!(f_module)

  #inject input macros.
  inject_inputs!(f_module, input_list)

  #next, inject the script generator

  inject_verilog_generator!(f_module, params_list)
end

function module_translate(f::Expr)
  #for now, do nothing.
  f_module = copy(f)
  #check if there's an existing output definition and send it to nothing.
  strip_output_definition!(f_module)
  #strip any inputs that happen to be wires
  input_list, params_list = strip_wire_inputs!(f_module)

  (length(input_list) > 0) || throw(ArgumentError("selected function does not appear to be a verilog module."))

  module_transform!(f_module, input_list, params_list)

  set_output_type!(f_module, :String)

  inject!(f_module, :(Verilog.@verimode :verilog))

  return f_module
end



################################################################################
## TEXT rewrite.
## what happens when you submit a "text rewrite" to the

function substitute_wire_inputs_as_wiretext!(f::Expr)
  #issue a list of places where we need extra wire macros.
  inputs_list = Vector{Tuple{Symbol, Any}}()
  param_list = Symbol[]

  for argument in f.args[1].args[2:end]
    if isa(argument, Symbol)
      push!(param_list, argument)
      continue
    end

    #a bare wire statement.
    if argument.args[2] == :Wire
      #reset it to Unsigned.
      argument.args[2] = :(Verilog.WireObject)
      #save the needed symbol and wire range parameter.
      push!(inputs_list, (argument.args[1], nothing))
    elseif argument.args[2] == :SingleWire
      argument.args[2] = :(Verilog.WireObject{0:0v})

      #save the needed symbol and wire range parameter.
      push!(inputs_list, (argument.args[1], :(0:0v)))
    elseif isa(argument.args[2], Expr) &&
      (argument.args[2].head == :curly) &&
      (argument.args[2].args[1] == :Wire) &&
      (argument.args[2].args[2].head == :(:))

      colondef = argument.args[2].args[2]

      #then reset it to WireObject
      argument.args[2] = :(Verilog.WireObject{$colondef})

      #save the needed symbol and wire range parameter.
      push!(inputs_list, (argument.args[1], argument.args[2].args[2]))
    else
      push!(param_list, argument.args[1])
    end
  end

  inputs_list, param_list
end

function wiretext_translate(f::Expr)
  f_wiretext = copy(f)

  input_list,param_list = substitute_wire_inputs_as_wiretext!(f_wiretext)

  module_transform!(f_wiretext, input_list, param_list)

  set_output_type!(f_wiretext, :(Verilog.ModuleObject))

  input_identifiers = [t[1] for t in input_list]

  inject!(f_wiretext, :(Verilog.@verimode :modulecall $(input_identifiers...)))

  f_wiretext
end
