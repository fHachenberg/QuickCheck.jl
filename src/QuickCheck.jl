# A Julia implementation of QuickCheck, a specification-based tester
#
# QuickCheck was originally written for Haskell by Koen Claessen and John Hughes
# http://www.cse.chalmers.se/~rjmh/QuickCheck/

module QuickCheck

export property
export condproperty
export quantproperty

function lambda_arg_types(f::Function)
    if !isa(f, Function)
        error("You must supply either an anonymous function with typed arguments or an array of argument types.")
    end
    # [eval(var.args[2]) for var in Base.uncompressed_ast(f.code).args[1]]
    c = methods(f).ms
    if length(c) != 1
      error("The function must have one, and only one method.")
  end
  [c[1].sig.parameters[2:end]...]
end

# Simple properties
function property(prop::Function, typs::Vector, ntests)
    arggens = [size -> generator(typ, size) for typ in typs]
    quantproperty(prop, typs, ntests, arggens...)
end
property(prop::Function, typs::Vector) = property(prop, typs, 100)
property(prop::Function, ntests) = property(prop, lambda_arg_types(prop), ntests)
property(prop::Function) = property(prop, 100)

# Conditional properties
function condproperty(prop::Function, typs::Vector, ntests, maxtests, argconds...)
    arggens = [size -> generator(typ, size) for typ in typs]
    check_property(prop, arggens, argconds, ntests, maxtests)
end
condproperty(prop::Function, args...) = condproperty(prop, lambda_arg_types(prop), args...)

# Quantified properties (custom generators)
function quantproperty(prop::Function, typs::Vector, ntests, arggens...)
    argconds = [(_...)->true for t in typs]
    check_property(prop, arggens, argconds, ntests, ntests)
end
quantproperty(prop::Function, args...) = quantproperty(prop, lambda_arg_types(prop), args...)

function check_property(prop::Function, arggens, argconds, ntests, maxtests)
    totalTests = 0
    for i in 1:ntests
        goodargs = false
        args = []
        while !goodargs
            totalTests += 1
            if totalTests > maxtests
                println("Arguments exhausted after $i tests.")
                return
            end
            args = [arggen(div(i,2)+3) for arggen in arggens]
            goodargs = all([cond(args...) for cond in argconds])
        end
        if !prop(args...)
            error("Falsifiable, after $i tests:\n$args")
        end
    end
    println("OK, passed $ntests tests.")
end

# Default generators for primitive types
generator(::Type{T}, size) where T <: Unsigned = convert(T, rand(1:size))
generator(::Type{T}, size) where T <: Signed = convert(T, rand(-size:size))
generator(::Type{T}, size) where T <: AbstractFloat = convert(T, (rand()-0.5).*size)
# This won't generate interesting UTF-8, but doing that is a Hard Problem
generator(::Type{T}, size) where T <: String = convert(T, randstring(size))

generator(::Type{Any}, size) = error("Property variables cannot by typed Any.")

# Generator for array types
function generator(::Type{Array{T,n}}, size) where {T,n}
    dims = [rand(1:size) for i in 1:n]
    reshape([generator(T, size) for x in 1:prod(dims)], dims...)
end

# Generator for composite types
function generator(::Type{C}, size) where C
    if C.types == ()
        error("No generator defined for type $C.")
    end
    C([generator(T, size) for T in C.types]...)
end

end
