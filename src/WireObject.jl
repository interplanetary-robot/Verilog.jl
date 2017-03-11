#WireObject.jl
# much of the magic happens here as this object can be passed around,
# representing Wire object state.

type WireObject{R};
  lexical_representation::String
end

Base.range{R}(::WireObject{R}) = R
Base.length{R}(::WireObject{R}) = length(R)

lr(w) = w.lexical_representation

#lexical transformations for logical operators.
#unary logical operators
Base.:~{R}(w::WireObject{R}) = WireObject{R}(string("~(", w.lexical_representation, ")"))
Base.:&{R}(w::WireObject{R}) = WireObject{0:0v}(string("&(", w.lexical_representation, ")"))
Base.:|{R}(w::WireObject{R}) = WireObject{0:0v}(string("|(", w.lexical_representation, ")"))
Base.:^{R}(w::WireObject{R}) = WireObject{0:0v}(string("^(", w.lexical_representation, ")"))
#make single-wire objects pass through without doing any collection.
Base.:&(w::WireObject{0:0v}) = w
Base.:|(w::WireObject{0:0v}) = w
Base.:^(w::WireObject{0:0v}) = w

Base.:&(w1::WireObject, w2::WireObject, w3::WireObject, ws::WireObject...) = WireObject{0:0v}(string("&({",join([lr(w) for w in [w1, w2, w3, ws...]], ", "),"})"))
Base.:|(w1::WireObject, w2::WireObject, w3::WireObject, ws::WireObject...) = WireObject{0:0v}(string("|({",join([lr(w) for w in [w1, w2, w3, ws...]], ", "),"})"))
Base.:^(w1::WireObject, w2::WireObject, w3::WireObject, ws::WireObject...) = WireObject{0:0v}(string("^({",join([lr(w) for w in [w1, w2, w3, ws...]], ", "),"})"))

#presume that R & S have been checked to be the same size (for now).
#binary logical operators
Base.:&{R,S}(lhs::WireObject{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("($(lr(lhs)) & $(lr(rhs)))")
Base.:|{R,S}(lhs::WireObject{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("($(lr(lhs)) | $(lr(rhs)))")
Base.:^{R,S}(lhs::WireObject{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("($(lr(lhs)) ^ $(lr(rhs)))")

xorxnor{R}(w::WireObject{R}) = WireObject{1:0v}("{^($(lr(w))), ~^($(lr(w)))}")

#lexical transformations for arithmetic operatiors
Base.:*{R}(lhs::Int, rhs::WireObject{R}) = WireObject{range(length(R) * lhs)}("{$lhs{$(lr(rhs))}}")

#other arithmetic operators
Base.:+{R,S}(lhs::WireObject{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("($(lr(lhs)) + $(lr(rhs)))")
Base.:-{R,S}(lhs::WireObject{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("($(lr(lhs)) - $(lr(rhs)))")
Base.:*{R,S}(lhs::WireObject{R}, rhs::WireObject{S}) = WireObject{range(length(R) + length(S))}("($(lr(lhs)) * $(lr(rhs)))")

Base.:-{R}(lhs::WireObject{R}) = WireObject{range(length(R))}("-($(lr(lhs)))")

#shifters
Base.:(<<){R,S}(lhs::WireObject{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("($(lr(lhs)) << $(lr(rhs)))")
Base.:(>>){R,S}(lhs::WireObject{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("($(lr(lhs)) >> $(lr(rhs)))")
Base.:(>>>){R,S}(lhs::WireObject{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("(\$signed($(lr(lhs))) >>> $(lr(rhs)))")

#comparative operators
Base.:>{R,S}(lhs::WireObject{R}, rhs::WireObject{S})  = WireObject{range(length(R))}("($(lr(lhs)) > $(lr(rhs)))")
Base.:<{R,S}(lhs::WireObject{R}, rhs::WireObject{S})  = WireObject{range(length(R))}("($(lr(lhs)) < $(lr(rhs)))")
Base.:(>=){R,S}(lhs::WireObject{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("($(lr(lhs)) >= $(lr(rhs)))")
Base.:(<=){R,S}(lhs::WireObject{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("($(lr(lhs)) <= $(lr(rhs)))")
Base.:(==){R,S}(lhs::WireObject{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("($(lr(lhs)) == $(lr(rhs)))")

function Base.getindex{R}(w::WireObject{R}, r::VerilogRange)
  if (r.stop == r.start)
    WireObject{range(length(r))}(string("$(lr(w))[$(r.stop)]"))
  elseif (r.stop > r.start)
    WireObject{range(length(r))}(string("$(lr(w))[$(r.stop):$(r.start)]"))
  else
    WireObject{range(length(r))}(string("{",join(["$(lr(w))[$idx]" for idx in reverse(r)],", "),"}"))
  end
end

Base.getindex{R}(w::WireObject{R}, r::RelativeRange) = getindex(w, parse_msb(r, R))
Base.getindex{R}(w::WireObject{R}, ::Type{msb}) = getindex(w, R.stop)
Base.getindex{R}(w::WireObject{R}, m::msb) = getindex(w, R.stop - m.value)

Base.getindex{R}(w::WireObject{R}, i::Int) = WireObject{0:0v}(string("$(lr(w))[$i]"))
#Concatenation with wires using the Wire() operator.  Make the assumption that
#any "wire" object that doesn't derive from an existing WireObject must be a
#constant.  We can then transparently overload the Wire() operator with no
#ambiguities.
typealias WOO Union{WireObject, Wire}

wo_concat(w::WireObject) = w.lexical_representation
wo_concat(w::Wire) = string("$(length(w))'b", join(reverse(w.values).*1))

function (::Type{Wire})(ws::WOO...)
  l = sum(length, ws)
  WireObject{range(l)}(string("{", join([wo_concat(w) for w in ws],",") ,"}"))
end

#binary logical operators with constants on the right:
Base.:&{R,S}(lhs::WireObject{R}, rhs::Wire{S}) = WireObject{range(length(R))}(string("($(lr(lhs)) & {$(wo_concat(rhs))})"))
Base.:|{R,S}(lhs::WireObject{R}, rhs::Wire{S}) = WireObject{range(length(R))}(string("($(lr(lhs)) | {$(wo_concat(rhs))})"))
Base.:^{R,S}(lhs::WireObject{R}, rhs::Wire{S}) = WireObject{range(length(R))}(string("($(lr(lhs)) ^ {$(wo_concat(rhs))})"))
#binary logical operators with constants on the left:
Base.:&{R,S}(lhs::Wire{R}, rhs::WireObject{S}) = WireObject{range(length(R))}(string("({$(wo_concat(lhs))} & $(lr(rhs)))"))
Base.:|{R,S}(lhs::Wire{R}, rhs::WireObject{S}) = WireObject{range(length(R))}(string("({$(wo_concat(lhs))} | $(lr(rhs)))"))
Base.:^{R,S}(lhs::Wire{R}, rhs::WireObject{S}) = WireObject{range(length(R))}(string("({$(wo_concat(lhs))} ^ $(lr(rhs)))"))

#arithmetic operators with constants on the left:
Base.:+{R,S}(lhs::Wire{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("($(wo_concat(lhs)) + $(lr(rhs)))")
Base.:-{R,S}(lhs::Wire{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("($(wo_concat(lhs)) - $(lr(rhs)))")
Base.:*{R,S}(lhs::Wire{R}, rhs::WireObject{S}) = WireObject{range(length(R) + length(S))}("($(wo_concat(lhs)) * $(lr(rhs)))")
#arithmetic operators with constants on the right:
Base.:+{R,S}(lhs::WireObject{R}, rhs::Wire{S}) = WireObject{range(length(R))}("($(lr(lhs)) + $(wo_concat(rhs)))")
Base.:-{R,S}(lhs::WireObject{R}, rhs::Wire{S}) = WireObject{range(length(R))}("($(lr(lhs)) - $(wo_concat(rhs)))")
Base.:*{R,S}(lhs::WireObject{R}, rhs::Wire{S}) = WireObject{range(length(R) + length(S))}("($(lr(lhs)) * $(wo_concat(rhs)))")

#comparative operators with constants on the left:
Base.:<{R,S}(lhs::Wire{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("($(wo_concat(lhs)) < $(lr(rhs)))")
Base.:>{R,S}(lhs::Wire{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("($(wo_concat(lhs)) > $(lr(rhs)))")
Base.:(<=){R,S}(lhs::Wire{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("($(wo_concat(lhs)) <= $(lr(rhs)))")
Base.:(>=){R,S}(lhs::Wire{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("($(wo_concat(lhs)) >= $(lr(rhs)))")
Base.:(==){R,S}(lhs::Wire{R}, rhs::WireObject{S}) = WireObject{range(length(R))}("($(wo_concat(lhs)) == $(lr(rhs)))")
#comparative operators with constants on the right:
Base.:<{R,S}(lhs::WireObject{R}, rhs::Wire{S}) = WireObject{range(length(R))}("($(lr(lhs)) < $(wo_concat(rhs)))")
Base.:>{R,S}(lhs::WireObject{R}, rhs::Wire{S}) = WireObject{range(length(R))}("($(lr(lhs)) > $(wo_concat(rhs)))")
Base.:(<=){R,S}(lhs::WireObject{R}, rhs::Wire{S}) = WireObject{range(length(R))}("($(lr(lhs)) <= $(wo_concat(rhs)))")
Base.:(>=){R,S}(lhs::WireObject{R}, rhs::Wire{S}) = WireObject{range(length(R))}("($(lr(lhs)) >= $(wo_concat(rhs)))")
Base.:(==){R,S}(lhs::WireObject{R}, rhs::Wire{S}) = WireObject{range(length(R))}("($(lr(lhs)) == $(wo_concat(rhs)))")
