#-------------------------------------------------------------------------------
# Logger configuration
# TODO: Lots of design work to do here.  Presumably there should be a standard
# textural log system config system like the python one.

parse_level(level) = level
parse_level(level::String) = parse_level(Symbol(lowercase(level)))
function parse_level(level::Symbol)
    if      level == :belowminlevel  return  BelowMinLevel
    elseif  level == :debug          return  Debug
    elseif  level == :info           return  Info
    elseif  level == :warn           return  Warn
    elseif  level == :error          return  Error
    elseif  level == :abovemaxlevel  return  AboveMaxLevel
    else
        throw(ArgumentError("Unknown log level $level"))
    end
end

"""
    configure_logging(args...; kwargs...)

Call `configure_logging` with the current logger, and update cached log
filtering information.
"""
function configure_logging(args...; kwargs...)
    logger = configure_logging(current_logger(), args...; kwargs...)::AbstractLogger
    # FIXME: Tools for setting this should be in Base.
    if haskey(task_local_storage(), :LOGGER_STATE)
        task_local_storage()[:LOGGER_STATE] = LogState(logger)
    else
        global_logger(logger)
    end
    logger
end

configure_logging(::AbstractLogger, args...; kwargs...) =
    throw(ArgumentError("No configure_logging method matches the provided arguments."))

function configure_logging(logger::SimpleLogger, args...; min_level=Info, kwargs...)
    SimpleLogger(logger.stream, parse_level(min_level))
end

disable_logging(level) = disable_logging(parse_level(level))
