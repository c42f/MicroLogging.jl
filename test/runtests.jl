using MicroLogging
using Base.Test

#if !MicroLogging.core_in_base
    using MicroLogging.LogTest
    import MicroLogging.LogTest: @test_logs, @test_deprecated
    import MicroLogging.LogTest: collect_test_logs, TestLogger
#end

using Compat

import MicroLogging: BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel,
    shouldlog, handle_message, min_enabled_level, catch_exceptions,
    configure_logging

# Copied from stdlib/Test/test/runtests.jl
mutable struct NoThrowTestSet <: Test.AbstractTestSet
    results::Vector
    NoThrowTestSet(desc) = new([])
end
Test.record(ts::NoThrowTestSet, t::Test.Result) = (push!(ts.results, t); t)
Test.finish(ts::NoThrowTestSet) = ts.results


#-------------------------------------------------------------------------------
@testset "Logging" begin

include("test_logs.jl")
include("core.jl")
include("config.jl")

end
