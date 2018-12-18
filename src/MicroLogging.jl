__precompile__()

module MicroLogging

using Compat

# ----- Core API (in Base as of julia-0.7) -----
export
    ## Logger types
    AbstractLogger, LogLevel, NullLogger, SimpleLogger,
    # Public logger API:
    #   handle_message, shouldlog, min_enabled_level, catch_exceptions
    # (not exported, as they're not generally called by users)
    #
    ## Log creation
    @debug, @info, @warn, @error, @logmsg,
    ## Logger installation and control
    with_logger, current_logger, global_logger, disable_logging

# ----- MicroLogging & stdlib Logging API -----
export
    # TODO: configure_logging needs a big rethink (see, eg, python's logger
    # config system)
    configure_logging,
    ConsoleLogger,
    InteractiveLogger

const core_in_base = isdefined(Base, :CoreLogging)

if core_in_base
    import Base.CoreLogging:
        @debug, @info, @warn, @error, @logmsg,
        AbstractLogger, LogLevel,
        BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel,
        disable_logging,
        handle_message, shouldlog, min_enabled_level, catch_exceptions,
        SimpleLogger, LogState,
        with_logger, current_logger, global_logger, disable_logging
else
    # 0.6-specific code which went into Base in 0.7
    include("core.jl")
end

include("StickyMessages.jl")

include("ConsoleLogger.jl")
include("InteractiveLogger.jl") # deprecated

include("config.jl")

if !core_in_base
    include("test.jl")
end

if VERSION < v"0.7"
# Init a global logger in 0.6 so that users don't need to do any manual setup.
# We avoid this in 0.7 and above because Base already has a functional default
# logger.
function __init__()
    global_logger(ConsoleLogger(stderr))
end
end

end
