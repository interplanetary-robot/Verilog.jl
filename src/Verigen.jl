#Verigen.jl - stuff pertaining to verilog generation and processing.

type Verigen
  module_name::Symbol
  inputs::Vector{Tuple{Symbol,VerilogRange}}
  wires ::Dict{Symbol,VerilogRange}
  assignments::Array{String}
  modulecalls::Array{String}
  last_assignment::Symbol
  Verigen(s::Symbol) = new(s, Tuple{Symbol,VerilogRange}[], Dict{Symbol,VerilogRange}(),String[], String[],:nothing)
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
  modulename::Symbol
  inputlist::Vector{String}
  outputname::Symbol
  wiredesc::VerilogRange
end

const __global_definition_cache = Dict{Any,Tuple}()
#caches the generated code.  Keys are Tuple{Symbol, ...} where ... are all other
#parameters; Values are the verilog text for the function.


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
  slist = [".$(gdef[2][idx]) ($(plist[idx]))" for idx = 1:length(plist)]
  oident = gdef[3]
  ostruct = gdef[4]
  ModuleObject(moduleparams[1], slist, oident, ostruct)
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
    paramgen = :(__module_params = ($module_name, $(p...)...))
  else
    paramgen = :(__module_params = ($module_name,))
  end

  esc(quote
    $paramgen

    if haskey(Verilog.__global_definition_cache, __module_params)
      if __synth_mode == :verilog
        return Verilog.__global_definition_cache[__module_params][1]
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
    Verilog.__global_definition_cache[__module_params] = (txt,
      [vi[1] for vi in __verilog_state.inputs],
      __verilog_state.last_assignment,
      __verilog_state.wires[__verilog_state.last_assignment])
    #return the correct output type depending on what we've set out.
    if __synth_mode == :verilog
      return txt
    elseif __synth_mode == :modulecall
      return Verilog.modulecall(__module_params, __call_parameters)
    end
  end)
end

macro input(ident, struct)
  ident_symbol = QuoteNode(ident)
  esc(quote
    push!(__verilog_state.inputs, ($ident_symbol, $struct))
    #also put it in the wires object.
    __verilog_state.wires[$ident_symbol] = $struct
    $ident = Verilog.WireObject{$struct}(string($ident_symbol))
  end)
end

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
      parsed_reference = isa($ident_reference, VerilogRange) ? $ident_reference : Verilog.parse_msb(__module_params.wires[$ident_symbol], $ident_reference)
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

macro name_suffix(stringvalue)
  esc(quote
    __verilog_state.module_name = string(__verilog_state.module_name, "_", $stringvalue)
    __module_params = (__verilog_state.module_name, __module_params[2:end]...)
  end)
end

macro final(identifier)
  ident_symbol = QuoteNode(identifier)
  esc(:(__verilog_state.last_assignment = $ident_symbol))
end

export @name_suffix
