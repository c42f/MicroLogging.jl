using MicroLogging
using Test

import MicroLogging: BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel,
    shouldlog, handle_message, min_enabled_level, catch_exceptions,
    configure_logging

import Test: TestLogger

#-------------------------------------------------------------------------------
@testset "Logging" begin

include("config.jl")
include("ConsoleLogger.jl")
include("StickyMessages.jl")

end
