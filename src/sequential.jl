#some stub work on the "sequential" verilog system.  Eventually this will be
#merged into the @verilog macro.

macro always(p...)
  mainblock = last(p)
  #clean it so that it's not in a begin...end block, instead an array of terms.
  if mainblock.head == :block
    return_ident = :()
    for idx = 1:length(mainblock.args)
      if mainblock.args[idx].head == Symbol("=")
        return_ident = mainblock.args[idx].args[1]
        return_value = mainblock.args[idx].args[2]
        mainblock.args[idx] = :(Verilog.@alwaysassign $(return_ident) $(return_value))
      end
    end
    push!(mainblock.args, :(__return_value = $return_ident))
  end
  esc(mainblock)
end

macro alwaysassign(a, b)
  esc(quote
    if isa($a, Register)
      $a.log3v = $b
    else
      $a = $b
    end
  end)
end

typealias ASTSing Union{Symbol, QuoteNode, Float64, Float32, Int64, UInt64, UInt32, UInt16, UInt8}
typealias ASTNode Union{Expr, ASTSing}
doc"""
  Verilog.isof(e1::Expr, e2::Expr, v::Symbol...)

  checks to see if e1 "is of the form" of e2, with free variables v.

  for example:

  isof(:((x + 2)^2), :(N^2), :N)                                        #==> true
  isof(:(x::Array{Int64, 1}), :(IDENT::Array{TYPE, 1}), :IDENT, :TYPE)  #==> true
  isof(:(x^2 + x^3), :(N^2 + N^3), :N)                                  #==> true
"""
function isof(e1::ASTNode, e2::ASTNode, v::Symbol...)
  d = Dict{Symbol, ASTNode}();
  isof(e1, e2, d, v...)
end
#we can recursively parse the AST.
function isof(e1::ASTNode, e2::ASTNode, d::Dict{Symbol, ASTNode}, v::Symbol...)
  #check if we're comparing singular items.  don't pass false in the case
  if isa(e1, ASTSing)
    e1 == e2 && return true
  end

  #check if e2 is a free variable.
  if isa(e2, Symbol)
    if e2 in v
      if haskey(d, e2)
        return e1 == d[e2]
      else
        d[e2] = e1
        return true
      end
    else
      return false
    end
  end

  #trap any remaining non-expressions
  (isa(e1, ASTSing) || isa(e2, ASTSing)) && return false


  (e1.head == e2.head) || return false
  for idx in 1:length(e2.args)
    isof(e1.args[idx], e2.args[idx], d, v...) || return false
  end
  return true
end


doc"""
  Verilog.isregisterassignment(expr)

  tells you whether or not a given expression is the assignment of a register.
  these need to be flagged for 1) exclusion from whosits and 2) need to be
"""
function isregisterassignment(expr::Expr)
  #first, check to make sure that the top level head is an assignment symbol.
  expr.head == Symbol("=") || return false
  isof(expr.args[2], :(Register{R}()), :R)
end

doc"""
  @sequential takes a function and replaces it with an enclosed function call.

  this will eventually be merged back in to @verilog.  The tricky thing is that
  these functions have to *encode state*, so they need to be transparently
  swapped out for
"""
macro sequential(f)
  #grab the function symbol.
  fsymbol = f.args[1].args[1]
  #check to see if there's an @always directive.
  has_always = false
  fn_block = f.args[2].args

  #allocate expressions in case it is an @always block.
  persist_decls = nothing
  persist_checks = nothing
  persist_assgns = nothing
  last_assignment = nothing

  for idx in 1:length(fn_block)
    if (fn_block[idx].head == :macrocall) && (fn_block[idx].args[1] == Symbol("@always"))
      #only one always allowed.
      has_always && throw(ArgumentError("only one @always allowed per module"))

      for jdx in 2:(length(fn_block[idx].args) - 1)
        if isof(fn_block[idx].args[jdx], :(posedge(WIRE)), :WIRE)
          wiresymbol = fn_block[idx].args[jdx].args[2]
          #generate two things 1) the persistent value symbol, 2) the value check,
          # and 3) the assignment of the persistent value.
          persist_value_ident = Symbol(:__persist_, wiresymbol)
          persist_decls = :($persist_decls; $persist_value_ident = SingleWire())
          if (persist_checks == nothing)
            persist_checks = :((!$persist_value_ident.values[1]) & $wiresymbol.values[1])
          else
            persist_checks = :($persist_checks & (!$persist_value_ident.values[1]) & $wiresymbol.values[1])
          end
          persist_assgns = :($persist_assgns; $persist_value_ident = $wiresymbol)
        end
      end

      #expand the always macro, then replace the old statement in the AST.
      fn_block[idx] = macroexpand(fn_block[idx])

      last_assignment = last(fn_block[idx].args)
      #pop it.
      pop!(fn_block[idx].args)

      has_always = true
    end
  end

  if (has_always)
    #then our behavior changes.  Create a closure that stores the values externally.
    enclosure_name = Symbol("__enc_", fsymbol)
    #push disabling safety checks brackets onto the function.

    register_assignments = nothing
    #parse through, looking for register assignments.
    g = []
    for exp in f.args[2].args
      if isregisterassignment(exp)
        register_assignments = :($register_assignments; $exp)
      else
        push!(g, exp)
      end
    end

    conditional_block = quote
      if $persist_checks
      end
    end

    #append the contents of the function
    append!(conditional_block.args[2].args[2].args, g)

    f.args[2] = conditional_block

    #add safety check toggling.
    unshift!(f.args[2].args, :(Verilog.@safeties_off))
    #make assignments on the persistent values.
    push!(f.args[2].args, last_assignment)
    push!(f.args[2].args, persist_assgns)
    push!(f.args[2].args, :(Verilog.@restore_safety))
    push!(f.args[2].args, :(__return_value))

    #brand f with a type coercion to a wire.
    f.args[1] = Expr(:(::), f.args[1])
    push!(f.args[1].args, :Wire)

    t = quote
      function $enclosure_name()
        $persist_decls
        $register_assignments
        $f
      end
    end
    esc(t)
  else
    f
  end
end

type Register{R}
  log3v::Wire{R}
end

(::Type{Register{R}}){R}() = Register(Wire{R}())
Base.:&{R}(w::Wire{R}, r::Register{R}) = w & r.log3v
Base.:|{R}(w::Wire{R}, r::Register{R}) = w | r.log3v

Base.convert{R}(::Type{Wire}, r::Register{R}) = r.log3v

export @sequential, @always, Register
