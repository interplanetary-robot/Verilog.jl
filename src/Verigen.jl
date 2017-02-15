#Verigen.jl - stuff pertaining to verilog generation and processing.

type Verigen
  module_name::Symbol
  inputs::Vector{Tuple{Symbol,UnitRange}}
  wires ::Dict{Symbol,UnitRange}
  assignments::Array{String}
  last_assignment::Symbol
  Verigen(s::Symbol) = new(s, Tuple{Symbol,UnitRange}[], Dict{Symbol,UnitRange}(),String[],:nothing)
end

function v_fmt(r::UnitRange)
  r == (0:0) && return ""
  return "[$(r.stop):$(r.start)] "
end

function describe(v::Verigen)
  output_symbol = v.last_assignment

  inpnames = Set{Symbol}([inp[1] for inp in v.inputs])

  io_declarations = string("\n  ",
    join([string("input ", v_fmt(input[2]), input[1]) for input in v.inputs], ",\n  "),
    ",\n  output ", v_fmt(v.wires[output_symbol]), output_symbol)

  wire_declarations = join([string("  wire ", v_fmt(v.wires[wire]), wire, ";") for wire in keys(v.wires) if
    (!(wire in inpnames)) && (wire != output_symbol)], "\n")

  assignments = join(v.assignments, "\n")
"""
module $(v.module_name)($io_declarations);

$wire_declarations$assignments

endmodule
"""
end

macro verigen(s)
  module_name = QuoteNode(s)
  esc(quote
    __verilog_state = Verilog.Verigen($module_name)
  end)
end

macro verifin()
  esc(quote
    Verilog.describe(__verilog_state)
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

macro assign(ident, expr)
  #later, parse more complicated assignment statements.
  ident_symbol = QuoteNode(ident)
  esc(quote
    #first execute the expression into a temporary variable
    assign_temp = $expr
    if isa(assign_temp, Verilog.WireObject)
      #check to see if the identifier in the wire table.
      if $ident_symbol in keys(__verilog_state.wires)
        push!(__verilog_state.assignments, string("  assign ", $ident_symbol, " = ", assign_temp.lexical_representation, ";"))
      else
        __verilog_state.wires[$ident_symbol] = range(assign_temp)
        push!(__verilog_state.assignments, string("  assign ", $ident_symbol, " = ", assign_temp.lexical_representation, ";"))
        $ident = assign_temp
      end
      #remember the last assignment
      __verilog_state.last_assignment = $ident_symbol
    else
      #just pass the value to ident, without touching it.
      $ident = assign_temp
    end
  end)
end

macro name_suffix(stringvalue)
  esc(quote
    __verilog_state.module_name = string(__verilog_state.module_name, "_", $stringvalue)
  end)
end

export @name_suffix
