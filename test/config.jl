@testset "Logger configuration" begin
    logs = let
        logger = TestLogger()
        with_logger(logger) do
            @debug "a"
            configure_logging(min_level=Info)
            @debug "a"
            @info  "b"
        end
        logger.logs
    end
    @test length(logs) == 2
    @test ismatch((Debug, "a"), logs[1])
    @test ismatch((Info , "b"), logs[2])

    # Same test as above, but with global logger
    old_logger = global_logger()
    logs = let
        logger = TestLogger(Debug)
        global_logger(logger)
        @debug "a"
        configure_logging(min_level=Info)
        @debug "a"
        @info  "b"
        logger.logs
    end
    global_logger(old_logger)

    @test length(logs) == 2
    @test ismatch((Debug, "a"), logs[1])
    @test ismatch((Info , "b"), logs[2])
end
