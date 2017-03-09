#Verigen.jl - stuff pertaining to verilog generation and processing.

type Verigen
  module_name::Symbol
  inputs::Vector{Pair{Symbol,VerilogRange}}
  wires ::Dict{Symbol,VerilogRange}
  assignments::Array{String}
  modulecalls::Array{String}
  dependencies::Set{Tuple}
  last_assignments::Vector{Pair{Symbol,VerilogRange}}
  Verigen(s::Symbol) = new(s, Tuple{Symbol,VerilogRange}[], Dict{Symbol,VerilogRange}(),String[], String[], Set{Tuple}(),[])
end

#formatting for input declarations only.
function v_decl_fmt(r::VerilogRange)
  r == 0:0 && return ""
  return "[$(r.stop):$(r.start)] "
end

function v_fmt(r::VerilogRange)
  r.stop == r.start && return "[$(r.stop)] "
  return "[$(r.stop):$(r.start)] "
end

function v_fmt(i::Integer)
  return "[$i] "
end

type ModuleObject
  moduleparams::Tuple
  modulename::Symbol
  inputlist::Vector{String}
  outputlist::Vector{Pair{Symbol, VerilogRange}}
end

#type for module cache members
type ModuleCache
  txt::String
  module_name::Symbol
  inputs::Vector{Symbol}
  outputlist::Vector{Pair{Symbol, VerilogRange}}
end

const __global_definition_cache = Dict{Tuple,ModuleCache}()
#caches the generated code.  Keys are Tuple{Symbol, Pairs...} where ... are
#pairs of parameter_symbol => parameter.  Values are

const __global_dependency_cache = Dict{Tuple, Set{Tuple}}()
#caches a list of dependencies.  Keys are the same tuple structure as above,
#where pairs are a parameter_symbol =>  parameter.

function describe(v::Verigen)
  output_symbol = v.last_assignment

  inpnames = Set{Symbol}([inp[1] for inp in v.inputs])

  io_declarations = string("\n  ",
    join([string("input ", v_decl_fmt(input[2]), input[1]) for input in v.inputs], ",\n  "),
    ",\n  output ", v_decl_fmt(v.wires[output_symbol]), output_symbol)

  wirestrings = [string("  wire ", v_decl_fmt(v.wires[wire]), wire, ";") for wire in keys(v.wires) if
    (!(wire in inpnames)) && (wire != output_symbol)]

  wire_declarations = string(join(wirestrings, "\n"), length(wirestrings) > 0 ? "\n\n" : "")

  assignments = join(v.assignments, "\n")

  modulecalls = string(join(v.modulecalls, "\n"), length(v.modulecalls) > 0 ? "\n" : "")
"""
module $(v.module_name)($io_declarations);

$wire_declarations$modulecalls$assignments
endmodule
"""
end

function modulecall(moduleparams, params)
  plist = [p.lexical_representation for p in params]
  gdef = __global_definition_cache[moduleparams]
  slist = [".$(gdef.inputs[idx]) ($(plist[idx]))" for idx = 1:length(plist)]
  ModuleObject(moduleparams, gdef.module_name, slist, gdef.output, gdef.output_shape)
end

macro verimode(s, p...)
  if length(p) == 1
    assign_call_parameters = :(__call_parameters = [$(p[1])])
  elseif length(p) > 1
    assign_call_parameters = :(__call_parameters = [])
    for idx = 1:length(p)
      q = p[idx]
      assign_call_parameters = :($assign_call_parameters; push!(__call_parameters, $(q)))
    end
  else
    assign_call_parameters = :()
  end

  m = esc(quote
    __synth_mode = $s
    if __synth_mode == :modulecall
      $assign_call_parameters
    end
  end)
  return m
end

macro verigen(s, p...)
  module_name = QuoteNode(s)

  if length(p) > 0
    listgen = :(ppairs = [])
    for parameter in p
      psym = QuoteNode(parameter)
      listgen = :($listgen; push!(ppairs, $psym => $parameter))
    end
    paramgen = :($listgen; __module_params = ($module_name, ppairs...))
  else
    paramgen = :(__module_params = ($module_name,))
  end

  esc(quote
    $paramgen

    if haskey(Verilog.__global_definition_cache, __module_params)
      if __synth_mode == :verilog
        return Verilog.__global_definition_cache[__module_params].txt
      elseif __synth_mode == :modulecall
        return Verilog.modulecall(__module_params, __call_parameters)
      end
    end

    __verilog_state = Verilog.Verigen($module_name)
  end)
end

macro verifin()
  esc(quote
    txt = Verilog.describe(__verilog_state)
    #set the global definition cache.
    Verilog.__global_definition_cache[__module_params] = Verilog.ModuleCache(txt,
      __verilog_state.module_name,
      [vi[1] for vi in __verilog_state.inputs],
      __verilog_state.last_assignment,
      __verilog_state.wires[__verilog_state.last_assignment])

    #populate the global dependency cache.
    Verilog.__global_dependency_cache[__module_params] = __verilog_state.dependencies

    #return the correct output type depending on what we've set out.
    if __synth_mode == :verilog
      return txt
    elseif __synth_mode == :modulecall
      return Verilog.modulecall(__module_params, __call_parameters)
    end
  end)
end

################################################################################

doc"""
  `@input identifier rangedescriptor`

  binds an input to a given range descriptor.
"""
macro input(identifier, rangedescriptor)
  ident_symbol = QuoteNode(identifier)
  esc(quote
    if (__synth_mode == :verilog || __synth_mode == :modulecall)

      push!(__verilog_state.inputs, ($ident_symbol, $rangedescriptor))
      #also put it in the wires object.
      __verilog_state.wires[$ident_symbol] = $rangedescriptor
      $identifier = Verilog.WireObject{$rangedescriptor}(string($ident_symbol))
    else
      #in the general case
      if isa($identifier, Integer)
        $identifier = Wire{$rangedescriptor}($identifier)
      elseif isa($identifier, Wire)
        $rangedescriptor == range($identifier) || throw(Verilog.SizeMismatchError())
      end
    end
  end)
end

export @input

################################################################################

type AssignError <: Exception; s::String; end

macro assign(ident, expr)
  #later, parse more complicated assignment statements.

  if isa(ident, Symbol)
    ident_symbol = QuoteNode(ident)

    esc(quote
      #check to see if our assignment is passing a wire.
      assign_temp = $expr
      if isa(assign_temp, Verilog.WireObject)
        #check to see if the identifier in the wire table.
        if $ident_symbol in keys(__verilog_state.wires)
          push!(__verilog_state.assignments, string("  assign ", $ident_symbol, " = ", assign_temp.lexical_representation, ";"))
        else
          __verilog_state.wires[$ident_symbol] = range(assign_temp)
          push!(__verilog_state.assignments, string("  assign ", $ident_symbol, " = ", assign_temp.lexical_representation, ";"))
          $ident = Verilog.WireObject{range(assign_temp)}(string($ident_symbol))
        end
        #remember the last assignment
        __verilog_state.last_assignment = $ident_symbol
      elseif isa(assign_temp, Wire)
        #if we're passing it a wire object, then it must be either a direct
        #wire declaration or some sort of wire constant.
        if Verilog.assigned(assign_temp)
          __verilog_state.wires[$ident_symbol] = range(assign_temp)
          push!(__verilog_state.assignments, string("  assign ", $ident_symbol, " = ", Verilog.wo_concat(assign_temp), ";"))
          $ident = Verilog.WireObject{range(assign_temp)}(string($ident_symbol))
        else
          __verilog_state.wires[$ident_symbol] = range(assign_temp)
          $ident = Verilog.WireObject{range(assign_temp)}(string($ident_symbol))
        end
      elseif isa(assign_temp, Verilog.ModuleObject)
        mname = assign_temp.modulename
        idsym = $ident_symbol
        mcaller = string(assign_temp.modulename, "_", idsym)
        iplist = assign_temp.inputlist
        mout = assign_temp.outputname
        push!(__verilog_state.modulecalls, string("  $mname $mcaller(\n    ", join(iplist, ",\n    "), ",\n    .$mout ($idsym));\n"))
        #add this to the list of dependencies.
        push!(__verilog_state.dependencies, assign_temp.moduleparams)
        #create the wire associated with this module call.
        __verilog_state.wires[$ident_symbol] = assign_temp.wiredesc
        #this could be the last assignment.
        __verilog_state.last_assignment = $ident_symbol
        #and also instantiate a new variable with this parameter.
        $ident = Verilog.WireObject{assign_temp.wiredesc}(string($ident_symbol))
      else
        #just pass the value to ident, without touching it.
        $ident = assign_temp
      end
    end)
  elseif ident.head == :ref
    ident_symbol = QuoteNode(ident.args[1])
    ident_reference = ident.args[2]
    esc(quote
      assign_temp = $expr
      if isa($ident_reference, Verilog.RelativeRange)
        parsed_reference = Verilog.parse_msb($ident_reference, __verilog_state.wires[$ident_symbol])
      elseif isa($ident_reference, Verilog.msb)
        parsed_reference = __verilog_state.wires[$ident_symbol].stop - ($ident_reference).value
      elseif isa($ident_reference, Type{Verilog.msb})
        parsed_reference = __verilog_state.wires[$ident_symbol].stop
      else
        parsed_reference = $ident_reference
      end

      if isa(assign_temp, Verilog.WireObject)
        if $ident_symbol in keys(__verilog_state.wires)
          push!(__verilog_state.assignments, string("  assign ", $ident_symbol, Verilog.v_fmt(parsed_reference), "= ", assign_temp.lexical_representation, ";"))
        else
          throw(AssignError("can't make a partial assignment to a nonexistent wire."))
        end
      elseif isa(assign_temp, Verilog.ModuleObject)
        if $ident_symbol in keys(__verilog_state.wires)
          mname = assign_temp.modulename
          mcaller = string(assign_temp.modulename, "_", $ident_symbol, "_", (parsed_reference).stop, "_", (parsed_reference).start)
          mout = assign_temp.outputname
          iplist = assign_temp.inputlist
          idsym = string($ident_symbol, Verilog.v_fmt(parsed_reference))
          push!(__verilog_state.modulecalls, string("  $mname $mcaller(\n    ", join(iplist, ",\n    "), ",\n    .$mout ($idsym));\n"))
          #this could be the last assignment.
          __verilog_state.last_assignment = $ident_symbol
        else
          throw(AssignError("can't make a partial assignment to a nonexistent wire."))
        end
      elseif isa(assign_temp, Verilog.Wire)
        #assume that naked wire objects that are tried to be assigned must be
        #constant values.
        if Verilog.assigned(assign_temp)
          push!(__verilog_state.assignments, string("  assign ", $ident_symbol, Verilog.v_fmt($ident_reference), "= ", Verilog.wo_concat(assign_temp), ";"))
        else
          throw(UnassignedError())
        end
      else
        $ident = $expr
      end
    end)
  else
    #transparently pass on the assigment without intercepting it.
    esc(:($ident = $expr))
  end
end

macro suffix(stringvalue)
  esc(quote
    __verilog_state.module_name = string(__verilog_state.module_name, "_", $stringvalue)
  end)
end

macro final(identifiers...)
  ident_symbol = QuoteNode(identifiers[1])
  esc(:(__verilog_state.last_assignment = $ident_symbol))
end

export @suffix
