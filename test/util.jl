using Base.Test
import MicroLogging: @propagate_sourceloc

macro test_propagate_sourceloc()
    @propagate_sourceloc quote
        (@__LINE__, @__FILE__, @__LINE__)
    end
end

@testset "@propagate_sourceloc" begin
    loc = @test_propagate_sourceloc()
    expected_line = (@__LINE__) - 1
    if Compat.macros_have_sourceloc
        @test loc[1] == expected_line == loc[3]
    else
        @test_broken loc[1] == expected_line == loc[3]
    end
    @test basename(loc[2]) == "util.jl"
end
