const modules = Array{Symbol, 1}()

################################################################################
## INTEGER VERSION.
## a thin shim over the binary version, but shows how effective method rewrite
## can be.

function inject!(f::Expr, expr)
  unshift!(f.args[2].args, expr)
end

function set_output_type!(f::Expr, output_type)
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
      wire_macro_list[argument.args[1]] = :(0:0v)
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

function inject_input_macro!(f::Expr, identifier, structure)
  inject!(f, :(@input $identifier $structure))
end

function integer_translate(f::Expr)
  f_integer = copy(f)

  set_output_type!(f_integer, :Unsigned)

  input_wire_list = substitute_wire_inputs!(f_integer)

  for key in keys(input_wire_list)
    inject_input_macro!(f_integer, key, input_wire_list[key])
  end

  inject!(f_integer, :(Verilog.@verimode :integermode))

  f_integer
end

################################################################################

include("module_rewrite.jl")

################################################################################
# strip module names if it's not in module mode.
function strip_nonmodule!(f::Expr)
  #generate a temporary block
  stripped_block = []
  for argument in f.args[2].args
    if isa(argument, Expr) &&
      (argument.head == :macrocall) &&
      (argument.args[1] == Symbol("@suffix"))
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
    f_wiretext = wiretext_translate(f)

    #strip module instructions
    strip_nonmodule!(f)
    #Last make version that substitutes all wires with integers.
    f_integer = integer_translate(f)

    inject!(f, :(Verilog.@verimode :wiremode))
    
    esc(quote
      #release all three forms of the function.
      Base.@__doc__ $f
      $f_integer
      $f_module
      $f_wiretext
    end)
  else
    throw(ArgumentError("@verilog macro must be run on a function."))
  end
end

export @verilog
