__precompile__()

module MicroLogging

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

import Base.CoreLogging:
    @debug, @info, @warn, @error, @logmsg,
    AbstractLogger, LogLevel,
    BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel,
    disable_logging,
    handle_message, shouldlog, min_enabled_level, catch_exceptions,
    SimpleLogger, LogState,
    with_logger, current_logger, global_logger, disable_logging

include("StickyMessages.jl")

include("ConsoleLogger.jl")
include("InteractiveLogger.jl") # deprecated

include("config.jl")

end
