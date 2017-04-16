#unknown_safety - handles a toggle that lets you switch between checking for
#unknowns and not checking for unknowns.

#creates the assignment safety variable inside a closure for performance reasons.
#this should be run only once, by the library.
function __unknown_safety_function_factory()
  unknown_safe::Bool = true
  (function unknown_check(wires::Wire...)::BitVector
    if unknown_safe
      isassigned(wires[1]) || throw(UnassignedError())
    end
    for w in wires[2:end]
      #check that all the parameters have the same size
      length(w) == length(wires[1]) || throw(SizeMismatchError())
      #and are defined.
      if unknown_safe
        isassigned(w) || throw(UnassignedError())
      end
    end

    if unknown_safe
      trues(length(wires[1]))
    else
      (&)([w.assigned for w in wires]...)
    end
   end,
   function set_unknown_safety(value::Bool)
     unknown_safe = value
     nothing
   end,
   function get_unknown_safety()
     return unknown_safe
   end)
end

doc"""
  `Verilog.unknown_check(wires...)`
  performs a safety check on the unknown state of wires.  If the current system
  is set to trap assignment errors, then throw an error when any attempt is made
  to pull an unknown value.  In both cases, return a bitvector signifying which
  values are known.

  By default, safety against unknown reads is set everywhere except for within
  sequential logic modules.  You may alter this parameter using the
  Verilog.set_unknown_safety() and Verilog.get_unknown_safety() functions.
"""
const (unknown_check, set_unknown_safety, get_unknown_safety) = __unknown_safety_function_factory()

doc"""
  `Verilog.set_unknown_safety!(wires...)`
  sets the unknown safety parameter.  See:  Verilog.unknown_check()
"""
set_unknown_safety

doc"""
  `Verilog.get_unknown_safety!(wires...)`
  gets the unknown safety parameter.  See:  Verilog.unknown_check()
"""
get_unknown_safety

#two helper macros that make this process much easier.
macro safeties_off()
  esc(quote
    __safety = Verilog.get_unknown_safety()
    Verilog.set_unknown_safety(false)
  end)
end
macro restore_safety()
  esc(:(Verilog.set_unknown_safety(__safety)))
end
