module MicroLogging

export Logger,
    @debug, @info, @warn, @error,
    get_logger, configure_logging


#-------------------------------------------------------------------------------
"""
    LogHandler(stream::IO, [interactive_style=isinteractive()])

Simplistic handler for logging to a text stream, with basic per-level color
support.
"""
immutable LogHandler
    stream::IO
    interactive_style::Bool
end

LogHandler(stream::IO) = LogHandler(stream, isinteractive())

function logmsg(handler::LogHandler, context, level, location, msg)
    filename = location[1] === nothing ? "REPL" : basename(location[1])
    if handler.interactive_style
        if     level <= Debug ; color = :cyan       ; bold = false; levelstr = "- DEBUG"
        elseif level <= Info  ; color = :blue       ; bold = false; levelstr = "-- INFO"
        elseif level <= Warn  ; color = :yellow     ; bold = true ; levelstr = "-- WARN"
        elseif level <= Error ; color = :red        ; bold = true ; levelstr = "- ERROR"
        else                    color = :dark_white ; bold = false; levelstr = "- $level"
        end
        # Attempt at avoiding the problem of distracting metadata in info log
        # messages - print metadata to the right hand side.
        metastr = "[$(context):$(filename):$(location[2])] $levelstr"
        msg = rstrip(msg, '\n')
        for (i,msgline) in enumerate(split(msg, '\n'))
            # TODO: This API is inconsistent between 0.5 & 0.6 - fix the bold stuff if possible.
            print_with_color(color, handler.stream, msgline)
            if i == 2
                metastr = "..."
            end
            nspace = max(1, displaysize(handler.stream)[2] - (length(msgline) + length(metastr)))
            print(handler.stream, " "^nspace)
            print_with_color(color, handler.stream, metastr)
            print(handler.stream, "\n")
        end
    else
        print(handler.stream, "$level [$(context):$(filename):$(location[2])]: $msg")
        if !endswith(msg, '\n')
            print(handler.stream, '\n')
        end
    end
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

function Base.show(io::IO, level::LogLevel)
    if     level == Debug ; print(io, "Debug")
    elseif level == Info  ; print(io, "Info")
    elseif level == Warn  ; print(io, "Warn")
    elseif level == Error ; print(io, "Error")
    else                    print(io, "LogLevel($level.level)")
    end
end


#-------------------------------------------------------------------------------
# TODO: Decide whether to parameterize type on a MinLevel, for dead code elim
# of custom verbose levels
type Logger{L<:AbstractLogLevel}
    context        # Indicator of context in which the log event happened; usually a julia module
    min_level::L   # TODO: Hardcode L === LogLevel?
    handler
    children::Vector{Any}
end

Logger{L}(context, parent::Logger{L}=get_logger(current_module())) =
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




