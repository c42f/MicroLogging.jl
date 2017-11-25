using MicroLogging
using Base.Test

#if !MicroLogging.core_in_base
    using MicroLogging.Test
import MicroLogging.Test: @test_logs
#end

using Compat

import MicroLogging: BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel,
    shouldlog, handle_message, min_enabled_level, catch_exceptions,
    configure_logging

import MicroLogging.Test: collect_test_logs, TestLogger

#-------------------------------------------------------------------------------
@testset "Logging" begin

include("test_logs.jl")
include("core.jl")
include("config.jl")

end
