@testset "Logger configuration" begin
    logs = let
        logger = TestLogger(min_level=Debug)
        with_logger(logger) do
            @debug "a"
            configure_logging(min_level=Info)
            @debug "a"
            @info  "b"
        end
        logger.logs
    end
    @test length(logs) == 2
    @test occursin((Debug, "a"), logs[1])
    @test occursin((Info , "b"), logs[2])

    # Same test as above, but with global logger
    old_logger = global_logger()
    logs = let
        logger = TestLogger(min_level=Debug)
        global_logger(logger)
        @debug "a"
        configure_logging(min_level=Info)
        @debug "a"
        @info  "b"
        logger.logs
    end
    global_logger(old_logger)

    @test length(logs) == 2
    @test occursin((Debug, "a"), logs[1])
    @test occursin((Info , "b"), logs[2])
end

@testset "disable_logging with parse_level" begin
    # Test utility: Log once at each standard level
    function log_each_level()
        @debug "a"
        @info  "b"
        @warn  "c"
        @error "d"
    end

    disable_logging("Info")
    @test_logs (Warn, "c") (Error, "d")  log_each_level()

    disable_logging(BelowMinLevel)
end
