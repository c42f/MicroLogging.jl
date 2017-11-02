__precompile__()

module MicroLogging

# ----- Core API to go in Base -----
export
    ## Log creation
    @debug, @info, @warn, @error, @logmsg,
    ## Types
    LogLevel, AbstractLogger,
    ## Concrete Loggers
    NullLogger,
    ## Logger installation and control
    # TODO: Should some of these go into stdlib ?
    with_logger, current_logger, global_logger,
    disable_logging
    #
    # The following AbstractLogger functions are part of the public core API
    # but not exported:
    #   handle_message, shouldlog, min_enabled_level, catch_exceptions
    #
    # You don't need these in your namespace, as you only care about them when
    # defining your own logger type.

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
const core_in_base = isdefined(Base, :AbstractLogger)

if core_in_base
    import Base:
        LogLevel, BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel,
        disable_logging, configure_logging,
        handle_message, shouldlog, min_enabled_level, catch_exceptions,
        parse_level
else
    include("core.jl")
end


include("loggers.jl")

function __init__()
    global_logger(InteractiveLogger(STDERR))
end

end
