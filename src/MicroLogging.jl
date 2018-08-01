__precompile__()

module MicroLogging

using Compat

# ----- Core API to go in Base -----
export
    ## Logger types
    AbstractLogger, LogLevel, NullLogger,
    # Public logger API:
    #   handle_message, shouldlog, min_enabled_level, catch_exceptions
    # (not exported, as they're not generally called by users)
    #
    ## Log creation
    @debug, @info, @warn, @error, @logmsg,
    ## Logger installation and control
    # TODO: Should some of these go into stdlib ?
    with_logger, current_logger, global_logger, disable_logging

# ----- API to go in StdLib package ? -----
export
    SimpleLogger, # Possibly needed in Base?
    # TODO: configure_logging needs a big rethink (see, eg, python's logger
    # config system)
    configure_logging

# ----- MicroLogging stuff, for now -----
export
    InteractiveLogger

# core.jl includes the code which will hopefully go into Base in 0.7
const core_in_base = isdefined(Base, :CoreLogging)

if core_in_base
    import Logging:
        @debug, @info, @warn, @error, @logmsg,
        AbstractLogger,
        LogLevel, BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel,
        with_logger, current_logger, global_logger, disable_logging,
        handle_message, shouldlog, min_enabled_level, catch_exceptions,
        SimpleLogger
else
    include("core.jl")
end

include("InteractiveLogger.jl") # deprecated
include("ConsoleLogger.jl")

include("config.jl")

if !core_in_base
    include("test.jl")
end

function __init__()
    global_logger(ConsoleLogger(STDERR))
end

end
