#Verigen.jl - stuff pertaining to verilog generation and processing.

type Verigen
  module_name::Symbol
  inputs::Vector{Pair{Symbol,VerilogRange}}
  wires ::Dict{Symbol,Tuple{VerilogRange, Tuple}}
  assignments::Array{String}
  modulecalls::Array{String}
  dependencies::Set{Tuple}
  last_assignments::Vector{Pair{Symbol,VerilogRange}}
  Verigen(s::Symbol) = new(s, Tuple{Symbol,VerilogRange}[], Dict{Symbol,Tuple{VerilogRange, Tuple}}(),String[], String[], Set{Tuple}(),[])
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


function wire_shape(w::Tuple{VerilogRange, Tuple})
  v_decl_fmt(w[1])
end
function array_shape(w::Tuple{VerilogRange, Tuple})
  join(["[$(l-1):0]" for l in w[2]])
end

function describe(v::Verigen)
  outputs = v.last_assignments

  inpnames = Set{Symbol}([inp[1] for inp in v.inputs])

  io_declarations = string("\n  ",
    join([string("input ", v_decl_fmt(input[2]), input[1]) for input in v.inputs], ",\n  "),
    ",\n  ",
    join([string("output ", v_decl_fmt(output[2]), output[1]) for output in outputs], ",\n  "))

  wirestrings = [string("  wire ", wire_shape(v.wires[wire]), wire, array_shape(v.wires[wire]), ";") for wire in keys(v.wires) if
    (!(wire in inpnames)) && !(wire in [output[1] for output in outputs])]

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
  ModuleObject(moduleparams, gdef.module_name, slist, gdef.outputlist)
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
      __verilog_state.last_assignments)

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

      push!(__verilog_state.inputs, ($ident_symbol => $rangedescriptor))
      #also put it in the wires object.
      __verilog_state.wires[$ident_symbol] = ($rangedescriptor, ())
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

  ##############################################################################
  ## AN ASSIGNMENT THAT IS AN ASSIGNMENT TO A SINGLE IDENTIFIER
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
          __verilog_state.wires[$ident_symbol] = (range(assign_temp), ())
          push!(__verilog_state.assignments, string("  assign ", $ident_symbol, " = ", assign_temp.lexical_representation, ";"))
          $ident = Verilog.WireObject{range(assign_temp)}(string($ident_symbol))
        end
        #remember the last assignment
        __verilog_state.last_assignments = [$ident_symbol => range(assign_temp)]
      elseif isa(assign_temp, Wire)
        #if we're passing it a wire object, then it must be either a direct
        #wire declaration or some sort of wire constant.
        if Verilog.assigned(assign_temp)
          __verilog_state.wires[$ident_symbol] = (range(assign_temp), ())
          push!(__verilog_state.assignments, string("  assign ", $ident_symbol, " = ", Verilog.wo_concat(assign_temp), ";"))
          $ident = Verilog.WireObject{range(assign_temp)}(string($ident_symbol))
        else
          __verilog_state.wires[$ident_symbol] = (range(assign_temp), ())
          $ident = Verilog.WireObject{range(assign_temp)}(string($ident_symbol))
        end
      elseif isa(assign_temp, Verilog.ModuleObject)
        mname = assign_temp.modulename
        idsym = $ident_symbol
        mcaller = string(assign_temp.modulename, "_", idsym)
        iplist = assign_temp.inputlist
        mout = assign_temp.outputlist[1].first
        push!(__verilog_state.modulecalls, string("  $mname $mcaller(\n    ", join(iplist, ",\n    "), ",\n    .$mout ($idsym));\n"))
        #add this to the list of dependencies.
        push!(__verilog_state.dependencies, assign_temp.moduleparams)
        #create the wire associated with this module call.
        assign_range = assign_temp.outputlist[1].second
        __verilog_state.wires[$ident_symbol] = (assign_range, ())
        #this could be the last assignment.
        __verilog_state.last_assignments = [$ident_symbol => assign_range]
        #and also instantiate a new variable with this parameter.
        $ident = Verilog.WireObject{assign_range}(string($ident_symbol))
      elseif isa(assign_temp, Array) && (typeof(assign_temp).parameters[1] <: Wire)
        wtype = typeof(assign_temp).parameters[1]
        wdim = typeof(assign_temp).parameters[2]
        wrange = wtype.parameters[1]
        #make sure this array object has a defined type (and not just a blank wire)
        @assert isa(wrange, Verilog.VerilogRange)
        wa_size = size(assign_temp)

        __verilog_state.wires[$ident_symbol] = (wrange, wa_size)
        #go ahead and overwrite all of these with empty wires of the correct type.
        #reassign assign_temp as an array of wireobjects with the same dimensions
        #as the array of wires.
        assign_temp = Array{Verilog.WireObject{wrange}, wdim}(wa_size...)
        for idx = 1:length(assign_temp)
          #fill the wireobject with the appropriate dereferencing indexes.
          name = string($ident_symbol, join(map((n) -> "[$(n-1)]", ind2sub(wa_size, idx))))
          assign_temp[idx] = Verilog.WireObject{wrange}(name)
        end
        $ident = assign_temp
      else
        #just pass the value to ident, without touching it.
        $ident = assign_temp
      end
    end)

  ##############################################################################
  ## ASSIGNING TO AN ARRAY REFERENT.  THIS COULD EITHER BE A WIRE SUBRANGE OR IT
  ## COULD BE AN ARRAY OF WIRES.

  elseif ident.head == :ref
    ident_base = ident.args[1]
    ident_symbol = QuoteNode(ident.args[1])
    ident_reference = ident.args[2]
    esc(quote
      ##########################################################################
      # array-of-wires case.
      if isa($ident_base, Array) && (typeof($ident_base).parameters[1] <: Verilog.WireObject)
        @assert isa($ident_reference, Integer)
        if isa($expr, Wire)
          push!(__verilog_state.assignments, string("  assign ", ($ident).lexical_representation, " = ", Verilog.wo_concat($expr), ";"))
        elseif isa($expr, Verilog.WireObject)
          push!(__verilog_state.assignments, string("  assign ", ($ident).lexical_representation, " = ", ($expr).lexical_representation, ";"))
        elseif isa($expr, Verilog.ModuleObject)
          mname = $expr.modulename
          #create the output "look"
          idsym = string($ident_symbol, "[", ($ident_reference - 1), "]")
          #create verilog's caller assignment name, which can't have brackets,
          #use an underscore to make it a subscript.
          mcaller = string($expr.modulename, "_", $ident_symbol, "_", ($ident_reference - 1))
          iplist = $expr.inputlist
          mout = $expr.outputlist[1].first
          push!(__verilog_state.modulecalls, string("  $mname $mcaller(\n    ", join(iplist, ",\n    "), ",\n    .$mout ($idsym));\n"))
          #add this to the list of dependencies.
          push!(__verilog_state.dependencies, $expr.moduleparams)
          #asserting that the sizes match.
          if length(($expr).outputlist[1].second) != length($ident)
            print("length of ", $expr.outputlist[1], " mismatches ")
            print("length of ", $ident, ".")
            throw(Verilog.SizeMismatchError())
          end
        end
      else
      ##########################################################################
      # wire subrange case
        assign_temp = $expr
        if isa($ident_reference, Verilog.RelativeRange)
          parsed_reference = Verilog.parse_msb($ident_reference, (__verilog_state.wires[$ident_symbol])[1])
        elseif isa($ident_reference, Verilog.msb)
          parsed_reference = (__verilog_state.wires[$ident_symbol])[1].stop - ($ident_reference).value
        elseif isa($ident_reference, Type{Verilog.msb})
          parsed_reference = (__verilog_state.wires[$ident_symbol])[1].stop
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
            mout = assign_temp.outputlist[1].first
            iplist = assign_temp.inputlist
            idsym = string($ident_symbol, Verilog.v_fmt(parsed_reference))
            push!(__verilog_state.modulecalls, string("  $mname $mcaller(\n    ", join(iplist, ",\n    "), ",\n    .$mout ($idsym));\n"))

            #this could be the last assignment.
            __verilog_state.last_assignment = [$ident_symbol => range(assign_temp)]
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
      end
    end)

  ##############################################################################
  ## ASSIGNING FROM A MODULE CALL TO A TUPLE.  WIRE ARRAY ASSIGNMENTS NOT
  ## SUPPORTED (FOR NOW)

  elseif ident.head == :tuple
    ident_list = ident.args
    assign_temp = expr

    #unroll the process of assigning the arguments.  This gets created no matter what,
    #it might not get used in the case that some other set of variables is using
    #a tuple assignment.
    assignment_code = :()
    for idx = 1:length(ident_list)
      ident = ident_list[idx]
      ident_symbol = QuoteNode(ident_list[idx])
      if isa(ident, Symbol)
        #unroll this!
        assignment_code = quote
          $assignment_code
          #update the full list of identifiers.
          push!(idlist, string($ident_symbol))
          push!(oplist, string(".", output_list[$idx].first, " (", $ident_symbol, ")"))
          #create the wire associated with this module call.
          __verilog_state.wires[$ident_symbol] = (output_list[$idx].second, ())
          #instantiate a new variable with this parameter.
          $ident = Verilog.WireObject{output_list[$idx].second}(string($ident_symbol))
        end

      elseif isa(ident, Expr) && (ident.head == :ref)

        #the case where it's a reference, it could either be a wire subreference
        #or it could be a wire array.

        ident_ref = ident.args[1]
        ident_symbol = QuoteNode(ident.args[1])
        ident_range = ident.args[2]

        assignment_code = quote
          $assignment_code

          #check if it's a wire object.
          if isa($ident_ref, Array) && (typeof($ident_ref).parameters[1] <: Verilog.WireObject)
            #assert that the index is not something strange.
            @assert isa($ident_range, Integer)
            #push this into the identifier list
            push!(idlist, string($ident_symbol, "_", $ident_range - 1))
            #push this onto the output list.
            push!(oplist, string(".", output_list[$idx].first, " (", $ident_symbol,"[", $ident_range - 1,"])"))
          elseif isa($ident_ref, Verilog.WireObject)
            wirerange = output_list[$idx].second
            dest_range = $ident_range
            if isa(dest_range, Integer)
              @assert (length(wirerange) == 1)
              push!(idlist, string($ident_symbol, "_", dest_range))
            else
              @assert (length(wirerange) == length(dest_range))
              push!(idlist, string($ident_symbol, "_", dest_range.start == dest_range.stop ? dest_range.start : "$(wirerange.stop)_$(wirerange.start)"))
            end
            push!(oplist, string(".", output_list[$idx].first, " (", $ident_symbol, strip(Verilog.v_fmt(dest_range)),")"))
          end
        end

      else #do nothing.
      end
    end

    #we're trying to make a tuple assignment.
    esc(quote
      if isa($assign_temp, Verilog.ModuleObject)

        #assign the module name.
        mname = $assign_temp.modulename
        idlist = String[]
        input_list = $assign_temp.inputlist
        output_list = $assign_temp.outputlist
        ident_list = $ident_list
        iplist = $assign_temp.inputlist
        oplist = String[]

        #do the unrolled assignment.
        $assignment_code

        mcaller = string($assign_temp.modulename, "_", join(idlist, "_"))

        #add this to the list of module calls.
        push!(__verilog_state.modulecalls, string("  $mname $mcaller(\n    ", join(iplist, ",\n    "), ",\n    ",
                                                                              join(oplist, ",\n    "), ");\n"))
        #add this to the list of dependencies.
        push!(__verilog_state.dependencies, $assign_temp.moduleparams)

      else
        #just do the boring assignment
        $ident = $assign_temp
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
  if length(identifiers) == 1
    ident_symbol = QuoteNode(identifiers[1])
    esc(:(__verilog_state.last_assignments = [$ident_symbol => (__verilog_state.wires[$ident_symbol])[1]]))
  else
    #println(:($identifiers))
    esc(quote
      pairlist = []
      for sym in $identifiers
        push!(pairlist, sym => (__verilog_state.wires[sym])[1])
      end
      __verilog_state.last_assignments = pairlist
    end)
  end
end

export @suffix
