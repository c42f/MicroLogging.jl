@testset "@test_logs" begin
    function foo(n)
        @info "Doing foo with n=$n"
        for i=1:n
            @debug "Iteration $i"
        end
    end

    @test_logs (Info,"Doing foo with n=2") foo(2)

    # Log pattern matching
    # Regex
    @test_logs (Info,r"^Doing foo with n=[0-9]+$") foo(10)
    @test_logs (Info,r"^Doing foo with n=[0-9]+$") foo(1)
    # Level symbols
    @test_logs (:debug,) min_level=Debug @debug "foo"
    @test_logs (:info,)  @info  "foo"
    @test_logs (:warn,)  @warn  "foo"
    @test_logs (:error,) @error "foo"

    # Pass through so the value of the expression can also be tested
    @test (@test_logs (Info,"blah") (@info "blah"; 42)) == 42

    # Debug level log collection
    @test_logs (Info,"Doing foo with n=2") (Debug,"Iteration 1") (Debug,"Iteration 2") min_level=Debug foo(2)

    @test_logs (Debug,"Iteration 5") min_level=Debug match_mode=:any foo(10)

    # Test failures
    fails = @testset NoThrowTestSet "check that @test_logs detects bad input" begin
        @test_logs (Warn,) foo(1)
        @test_logs (Warn,) match_mode=:any @info "foo"
        @test_logs (Debug,) @debug "foo"
    end
    @test length(fails) == 3
    @test fails[1] isa LogTestFailure
    @test fails[2] isa LogTestFailure
    @test fails[3] isa LogTestFailure
end

if MicroLogging.core_in_base
# Can't meaningfully use @test_deprecated, except with support in Base
function newfunc()
    42
end
@deprecate oldfunc newfunc

@testset "@test_deprecated" begin
    @test_deprecated oldfunc()

    # Expression passthrough
    @test (@test_deprecated oldfunc()) == 42

    fails = @testset NoThrowTestSet "check that @test_deprecated detects bad input" begin
        @test_deprecated newfunc()
        @test_deprecated r"Not found in message" oldfunc()
    end
    @test length(fails) == 2
    @test fails[1] isa LogTestFailure
    @test fails[2] isa LogTestFailure
end
end
