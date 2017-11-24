@testset "Tests @test_logs macro" begin
    function foo(n)
        @info "Doing foo with n=$n"
        for i=1:n
            @debug "Iteration $i"
        end
    end

    @test_logs (Info,"Doing foo with n=2") foo(2)

    # Regex matching
    @test_logs (Info,r"^Doing foo with n=[0-9]+$") foo(10)
    @test_logs (Info,r"^Doing foo with n=[0-9]+$") foo(1)

    # Debug level log collection
    @test_logs (Info,"Doing foo with n=2") (Debug,"Iteration 1") (Debug,"Iteration 2") min_level=Debug foo(2)
end
