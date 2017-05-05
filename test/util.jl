
@testset "internal find_var_uses torture tests" begin

@testset "Basic usage" begin
    # Basic variable use
    @test find_var_uses(:(a+b*c)) == [:a, :b, :c]
    # Deduplication
    @test find_var_uses(:(a*a)) == [:a]
    # Assignment rebinds, doesn't count as a "use".
    @test find_var_uses(:(a=1)) == []
    # Multiple-Exprs find_var_uses; each arg should be an independent block
    # from the point of view of variable assignments.
    @test find_var_uses(:(a=1), :(a+b)) == [:a, :b]
    # keyword args
    @test find_var_uses(:(f(a, b=1, c=2, d=e))) == [:a, :e]
end


@testset "New bindings" begin
    # Introduce new bindings and use them
    @test find_var_uses(:(
        begin
            a = 1
            b = 2
            c = a+b
        end)) == []
    # `local` qualifies a binding, it's not a variable use
    @test find_var_uses(:(
        begin
            local i=1
            local j
            i+1
        end
        )) == []
end


@testset "Scopes" begin
    @test find_var_uses(:(
        begin
            b = 1
            for i=1:10
                c = b   # uses b as bound above
            end
        end)) == []
    @test find_var_uses(:(
        begin
            a = 1
            for i=1:10
                b = a
            end
            c = b # uses b bound from outside the expression
        end)) == [:b]
    @test find_var_uses(:(
        try
            a = 1
        catch err
            show(err)
        end)) == []
end


@testset "Assignment and tuple unpacking" begin
    @test find_var_uses(:(
        begin
            a[i] = 10
        end
        )) == [:a,:i]
    @test find_var_uses(:(
        begin
            a,b = 10,11
            (c,(d,e[f])) = (1,(2,3))
            a+b
        end
        )) == [:e,:f]
end


end
