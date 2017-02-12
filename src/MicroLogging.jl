module MicroLogging

export Logger,
    @debug, @info, @warn, @error,
    get_logger, configure_logging


#-------------------------------------------------------------------------------
"""
    LogHandler(stream::IO, [usecolor=true])

Simplistic handler for logging to a text stream, with basic per-level color
support.
"""
immutable LogHandler
    stream::IO
    usecolor::Bool
end

LogHandler(stream::IO) = LogHandler(stream, true)

function logmsg(handler::LogHandler, context, level, location, msg)
    if     level <= Debug ; color = :cyan       ; levelstr = "DEBUG:"
    elseif level <= Info  ; color = :blue       ; levelstr = "INFO: "
    elseif level <= Warn  ; color = :yellow     ; levelstr = "WARN: "
    elseif level <= Error ; color = :red        ; levelstr = "ERROR:"
    else                    color = :dark_white ; levelstr = string(level)
    end
    if handler.usecolor
        Base.print_with_color(color, handler.stream, levelstr)
    else
        print(handler.stream, levelstr)
    end
    filename = location[1] === nothing ? "REPL" : basename(location[1])
    fullmsg = " [$(context):$(filename):$(location[2])]: $msg\n"
    Base.print(handler.stream, fullmsg)
end



#-------------------------------------------------------------------------------
# TODO: Do we need user-defined log levels ?
abstract AbstractLogLevel

"""
Predefined log levels, for fast log filtering
"""
immutable LogLevel <: AbstractLogLevel
    level::Int
end
const Debug = LogLevel(0)
const Info  = LogLevel(10)
const Warn  = LogLevel(20)
const Error = LogLevel(30)

Base.:<=(l1::LogLevel, l2::LogLevel) = l1.level <= l2.level



#-------------------------------------------------------------------------------
# TODO: Decide whether to parameterize type on a MinLevel, for dead code elim
# of custom verbose levels
type Logger{L<:AbstractLogLevel}
    context        # Indicator of context in which the log event happened; usually a julia module
    min_level::L   # TODO: Hardcode L === LogLevel?
    handler
    children::Vector{Any}
end

Logger{L}(context, parent::Logger{L}) =
    Logger{L}(context, parent.min_level, parent.handler, Vector{Any}())

Logger(context, level, handler) =
    Logger{typeof(level)}(context, level, handler, Vector{Any}())

Base.push!(parent::Logger, child) = push!(parent.children, child)

log_to_handler(logger::Logger, level, location, msg) =
    logmsg(logger.handler, logger.context, level, location, msg)

"""
    shouldlog(logger, level)

Determine whether messages of severity `level` should be sent to `logger`.
"""
shouldlog(logger::Logger, level) = logger.min_level <= level


# Logging macros
for (mname, level) in [(:debug, Debug),
                       (:info, Info),
                       (:warn, Warn),
                       (:error, Error)]
    @eval macro $mname(exs...)
        if length(exs) == 1
            logger_ex = get_logger(current_module())
            msg = esc(exs[1])
        elseif length(exs) == 2
            logger_ex = esc(exs[1])
            msg = esc(exs[2])
        else
            # TODO: User-defined key-value pairs?
            error("@$mname must be called with one or two arguments")
        end
        # FIXME: The following dubious hack gives an approximate line number
        # only!  See #1
        lineno = Int(unsafe_load(cglobal(:jl_lineno, Cint)))
        quote
            logger = $logger_ex
            if shouldlog(logger, $($level))
                # TODO: Add current_module() here explicitly as extra location context?
                log_to_handler(logger, $($level), (@__FILE__, $lineno), $msg)
            end
            nothing
        end
    end
end


#-------------------------------------------------------------------------------
# All registered module loggers
const _registered_loggers = Dict{Module,Any}(
    Main=>Logger(Main, Info, LogHandler(STDERR))
)

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


#-------------------------------------------------------------------------------

#=
macro logtrace(func)
    assert(isa(func, Expr) && func.head == :function && func.args[2].head == :block)
    enter_msg = "Enter $(func.args[1].args[1])"
    exit_msg = "Exit $(func.args[1].args[1])"
    unshift!(func.args[2].args, :(MicroLogging.@trace $enter_msg))
    push!(func.args[2].args, :(MicroLogging.@trace $exit_msg))
    esc(func)
end
=#

end




