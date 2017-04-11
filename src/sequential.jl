#some stub work on the "sequential" verilog system.  Eventually this will be
#merged into the @verilog macro.

macro always(a,b...)
  esc(last(b))
end

doc"""
  @sequential takes a function and replaces it with an enclosed function call.
"""
macro sequential(f)
  #grab the function symbol.
  fsymbol = f.args[1].args[1]
  #check to see if there's an @always directive.
  has_always = false
  for arg in f.args[2].args
    if (arg.head == :macrocall) && (arg.args[1] == Symbol("@always"))
      has_always = true
    end
  end

  if (has_always)
    #then our behavior changes.  Create a closure that stores the values externally.
    enclosure_name = Symbol("__enc_", fsymbol)
    esc(quote
      function $enclosure_name()
        $f
      end
      global const $fsymbol = $enclosure_name()
    end)
  else
    f
  end
end

type Register{R}
  log3v::Wire{R}
end

(::Type{Register{R}}){R}() = Register(Wire{R}())
Base.:&{R}(w::Wire{R}, r::Register{R}) = Wire{R}(w.values & r.log3v.values, w.assigned & r.log3v.assigned)
Base.:|{R}(w::Wire{R}, r::Register{R}) = Wire{R}(w.values | r.log3v.values, w.assigned & r.log3v.assigned)

export @sequential, @always, Register
