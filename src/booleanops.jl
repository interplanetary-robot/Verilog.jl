
function Base.:~{R}(w::Wire{R})
  #if any of them are undefined we have a problem.
  unks = unknown_check(w)
  Wire{R}(~w.values, unks)
end

function Base.:&{R}(lhs::Wire{R}, rhs::Wire{R})
  unks = unknown_check(lhs, rhs)
  mask = (~lhs.values & lhs.assigned) | (~rhs.values & rhs.assigned)
  Wire{R}(lhs.values & rhs.values, unks | mask)
end

function Base.:|{R}(lhs::Wire{R}, rhs::Wire{R})
  unks = unknown_check(lhs, rhs)
  mask = (lhs.values & lhs.assigned) | (rhs.values & rhs.assigned)
  Wire{R}(lhs.values | rhs.values, unks | mask)
end

function Base.:^{R}(lhs::Wire{R}, rhs::Wire{R})
  unks = unknown_check(lhs, rhs)
  Wire{R}(lhs.values $ rhs.values, unks)
end

#slow mullin_add test:
#472.227883 seconds (1.30 G allocations: 59.241 GB, 2.72% gc time)

#unary operators.

# A | B
# T | T => T
# T | F => F
# T | X => X
# F | F => F
# F | X => F
# X | X => X

function Base.:&{R}(tgt::Wire{R})
  res = true
  ass = true
  for idx = 1:length(R)
    res = tgt.values[idx] & res
    ass = (!tgt.values[idx] & tgt.assigned[idx]) | (tgt.assigned[idx] & ass)
  end
  Wire(res, ass)
end

function Base.:|{R}(tgt::Wire{R})
  res = false
  ass = true
  for idx = 1:length(R)
    res = tgt.values[idx] | res
    ass = (tgt.values[idx] & tgt.assigned[idx]) | (tgt.assigned[idx] & ass)
  end
  Wire(res, ass)
end

function Base.:^{R}(tgt::Wire{R})
  res = false
  ass = true
  for idx = 1:length(R)
    res = tgt.values[idx] $ res
    ass = tgt.assigned[idx] & ass
  end
  Wire(res, ass)
end

#negated operators
and(x) = (&)(x)
or(x) = (|)(x)
xor(x) = (^)(x)
nand(x) = ~((&)(x))
nor(x)  = ~((|)(x))
xnor(x) = ~((^)(x))
nand(x,y) = ~((&)(x,y))
nor(x,y)  = ~((|)(x,y))
xnor(x,y) = ~((^)(x,y))
Base.:~(::typeof(&)) = nand
Base.:~(::typeof(|)) = nor
Base.:~(::typeof(^)) = xnor

function xorxnor(w::Wire)
  isassigned(w) || throw(UnassignedError())
  Wire([(^)(w), (~^)(w)])
end

export xorxnor, and, or, nand, nor, xnor
