#WireObject.jl
# much of the magic happens here as this object can be passed around,
# representing Wire object state.

type WireObject{R};
  lexical_representation::String
end

Base.range{R}(::WireObject{R}) = R
Base.length{R}(::WireObject{R}) = length(R)

Base.:~{R}(w::WireObject{R}) = WireObject{R}(string("~(", w.lexical_representation, ")"))
Base.:&{R}(lhs::WireObject{R}, rhs::WireObject{R}) = WireObject{R}(string("($(lhs.lexical_representation) & $(rhs.lexical_representation))"))
Base.:|{R}(lhs::WireObject{R}, rhs::WireObject{R}) = WireObject{R}(string("($(lhs.lexical_representation) | $(rhs.lexical_representation))"))
Base.:^{R}(lhs::WireObject{R}, rhs::WireObject{R}) = WireObject{R}(string("($(lhs.lexical_representation) ^ $(rhs.lexical_representation))"))

Base.getindex{R}(w::WireObject{R}, r::UnitRange) = WireObject{range(length(r))}(string("$(w.lexical_representation)[$(r.stop):$(r.start)]"))


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
