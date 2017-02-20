#WireObject.jl
# much of the magic happens here as this object can be passed around,
# representing Wire object state.

type WireObject{R};
  lexical_representation::String
end

Base.range{R}(::WireObject{R}) = R
Base.length{R}(::WireObject{R}) = length(R)

#lexical transformations for logical operators.
#unary logical operators
Base.:~{R}(w::WireObject{R}) = WireObject{R}(string("~(", w.lexical_representation, ")"))
Base.:&{R}(w::WireObject{R}) = WireObject{0:0}(string("&(", w.lexical_representation, ")"))
Base.:|{R}(w::WireObject{R}) = WireObject{0:0}(string("|(", w.lexical_representation, ")"))
Base.:^{R}(w::WireObject{R}) = WireObject{0:0}(string("^(", w.lexical_representation, ")"))

#presume that R & S have been checked to be the same size (for now).
#binary logical operators
Base.:&{R,S}(lhs::WireObject{R}, rhs::WireObject{S}) = WireObject{range(length(R))}(string("($(lhs.lexical_representation) & $(rhs.lexical_representation))"))
Base.:|{R,S}(lhs::WireObject{R}, rhs::WireObject{S}) = WireObject{range(length(R))}(string("($(lhs.lexical_representation) | $(rhs.lexical_representation))"))
Base.:^{R,S}(lhs::WireObject{R}, rhs::WireObject{S}) = WireObject{range(length(R))}(string("($(lhs.lexical_representation) ^ $(rhs.lexical_representation))"))

#lexical transformations for arithmetic operatiors
Base.:*{R}(lhs::Int, rhs::WireObject{R}) = WireObject{range(length(R) * lhs)}(string("{$lhs{$(rhs.lexical_representation)}}"))

Base.getindex{R}(w::WireObject{R}, r::UnitRange) = WireObject{range(length(r))}(string("$(w.lexical_representation)[$(r.stop):$(r.start)]"))
Base.getindex{R}(w::WireObject{R}, i::Int) = WireObject{0:0}(string("$(w.lexical_representation)[$i]"))
Base.getindex{R}(w::WireObject{R}, r::StepRange) = WireObject{range(length(r))}(string("{",join(["$(w.lexical_representation)[$idx]" for idx in r],","),"}"))

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

#binary logical operators with constants on the left:
Base.:&{R,S}(lhs::WireObject{R}, rhs::Wire{S}) = WireObject{range(length(R))}(string("($(lhs.lexical_representation) & {$(wo_concat(rhs))})"))
Base.:|{R,S}(lhs::WireObject{R}, rhs::Wire{S}) = WireObject{range(length(R))}(string("($(lhs.lexical_representation) | {$(wo_concat(rhs))})"))
Base.:^{R,S}(lhs::WireObject{R}, rhs::Wire{S}) = WireObject{range(length(R))}(string("($(lhs.lexical_representation) ^ {$(wo_concat(rhs))})"))
#binary logical operators with constants on the right:
Base.:&{R,S}(lhs::Wire{R}, rhs::WireObject{S}) = WireObject{range(length(R))}(string("({$(wo_concat(lhs))} & $(rhs.lexical_representation))"))
Base.:|{R,S}(lhs::Wire{R}, rhs::WireObject{S}) = WireObject{range(length(R))}(string("({$(wo_concat(lhs))} | $(rhs.lexical_representation))"))
Base.:^{R,S}(lhs::Wire{R}, rhs::WireObject{S}) = WireObject{range(length(R))}(string("({$(wo_concat(lhs))} ^ $(rhs.lexical_representation))"))
