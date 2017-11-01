__precompile__()

module MicroLogging

export
    @debug, @info, @warn, @error, @logmsg,
    with_logger, current_logger, global_logger,
    disable_logging, configure_logging,
    AbstractLogger,
    handle_message, shouldlog, min_enabled_level,
    SimpleLogger,
    # From MicroLogging
    InteractiveLogger

# core.jl includes the code which will hopefully go into Base in 0.7
const core_in_base = isdefined(Base, :AbstractLogger)

if core_in_base
    import Base:
        LogLevel, BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel,
        disable_logging, configure_logging,
        handle_message, shouldlog, min_enabled_level,
        parse_level
else
    include("core.jl")
end


include("loggers.jl")

function __init__()
    global_logger(InteractiveLogger(STDERR))
end

end
