using MicroLogging
using Compat
using Compat.Test

import MicroLogging: BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel,
    shouldlog, handle_message, min_enabled_level, catch_exceptions,
    configure_logging

if MicroLogging.core_in_base
    import Compat.Test: collect_test_logs, TestLogger, LogTestFailure
else
    using MicroLogging.LogTest
    import MicroLogging.LogTest: @test_logs, @test_deprecated
    import MicroLogging.LogTest: collect_test_logs, TestLogger, LogTestFailure

    # Copied from stdlib/Test/test/runtests.jl
    mutable struct NoThrowTestSet <: Test.AbstractTestSet
        results::Vector
        NoThrowTestSet(desc) = new([])
    end
    Test.record(ts::NoThrowTestSet, t::Test.Result) = (push!(ts.results, t); t)
    Test.finish(ts::NoThrowTestSet) = ts.results
end

#-------------------------------------------------------------------------------
@testset "Logging" begin

if !MicroLogging.core_in_base
    include("test_logs.jl")
    include("core.jl")
end

include("config.jl")
include("ConsoleLogger.jl")
include("StickyMessages.jl")

end
