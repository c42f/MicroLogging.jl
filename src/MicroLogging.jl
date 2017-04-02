__precompile__()

module MicroLogging

export Logger,
    @debug, @info, @warn, @error,
    get_logger, configure_logging


include("handlers.jl")

"""
Severity/verbosity of a log record.

The log level provides a key against which log records may be filtered before
any work is done formatting the log message and other metadata.
"""
@enum LogLevel Debug Info Warn Error


#-------------------------------------------------------------------------------
# TODO: Decide whether to parameterize type on a MinLevel, for dead code elim
# of custom verbose levels
type Logger
    context        # Indicator of context in which the log event happened; usually a julia module
    min_level::LogLevel
    handler
    children::Vector{Any}
end

Logger(context, parent::Logger=get_logger(current_module())) =
    Logger(context, parent.min_level, parent.handler, Vector{Any}())

Logger(context, level, handler) = Logger(context, level, handler, Vector{Any}())

Base.push!(parent::Logger, child) = push!(parent.children, child)

log_to_handler(logger::Logger, level, msg; kwargs...) =
    logmsg(logger.handler, logger.context, level, msg; kwargs...)

"""
    shouldlog(logger, level)

Determine whether messages of severity `level` should be sent to `logger`.
"""
shouldlog(logger::Logger, level) = logger.min_level <= level

function match_log_macro_exprs(exs, context, macroname)
    # Match key,value pairs
    args = Any[]
    kwargs = Any[]
    for ex in exs
        if isa(ex,Expr) && ex.head == :(=)
            isa(ex.args[1], Symbol) || throw(ArgumentError("Expected key value pair, got $ex"))
            push!(kwargs, Expr(:kw, ex.args[1], esc(ex.args[2])))
        else
            push!(args, ex)
        end
    end
    if length(args) == 1
        logger_ex = get_logger(context)
        msg = esc(args[1])
    elseif length(args) == 2
        logger_ex = esc(args[1])
        msg = esc(args[2])
    else
        error("@$macroname must be called with one or two arguments")
    end
    logger_ex, msg, kwargs
end

# Logging macros
for (macroname, level) in [(:debug, Debug),
                           (:info,  Info),
                           (:warn,  Warn),
                           (:error, Error)]
    @eval macro $macroname(exs...)
        mod = current_module()
        logger_ex, msg, kwargs = match_log_macro_exprs(exs, mod, $(Expr(:quote, macroname)))
        # FIXME: The following dubious hack gives an approximate line number
        # only - the line of the start of the toplevel expression! See #1.
        lineno = Int(unsafe_load(cglobal(:jl_lineno, Cint)))
        quote
            logger = $logger_ex
            if shouldlog(logger, $($level))
                log_to_handler(logger, $($level), $msg;
                    id=gensym(), module_=$mod, location=(@__FILE__, $lineno),
                    $(kwargs...))
            end
            nothing
        end
    end
end


#-------------------------------------------------------------------------------
# All registered module loggers
const _registered_loggers = Dict{Module,Any}()

function __init__()
    _registered_loggers[Main] = Logger(Main, Info, LogHandler(STDERR))
end


"""
    get_logger(module)

Get the logger which will be used from within `module`, creating it and adding
it to the logging heirarchy if it doesn't yet exist.  The logger heirarchy is
taken from the module heirarchy.
"""
# TODO: Allow code contexts other than Module?
function get_logger(mod::Module=Main)
    get!(_registered_loggers, mod) do
        parent = get_logger(module_parent(mod))
        logger = Logger(mod, parent)
        push!(parent, logger)
        logger
    end
end

# TODO: @set_logger MyLogger

#-------------------------------------------------------------------------------
# Log system config
"""
    configure_logging([module|logger]; level=l, handler=h)

Configure logging system
"""
function configure_logging(logger; level=nothing, handler=nothing)
    if level !== nothing
        logger.min_level = level
    end
    if handler !== nothing
        logger.handler = handler
    end
    for child in logger.children
        configure_logging(child; level=level, handler=handler)
    end
end

configure_logging(mod::Module=Main; kwargs...) = configure_logging(get_logger(mod); kwargs...)


end

