module MicroLogging

export Logger,
    @debug, @info, @warn, @error,
    @makelogger,
    root_logger, configure_logging


#-------------------------------------------------------------------------------
immutable LogHandler
    stream::IO
    usecolor::Bool
end

LogHandler(stream::IO) = LogHandler(stream, true)

function logmsg(handler::LogHandler, loggername, level, location, msg)
    if     level == Debug ; color = :cyan       ; levelstr = "DEBUG:"
    elseif level == Info  ; color = :blue       ; levelstr = "INFO :"
    elseif level == Warn  ; color = :yellow     ; levelstr = "WARN :"
    elseif level == Error ; color = :red        ; levelstr = "ERROR:"
    else                    color = :dark_white ; levelstr = string(level)
    end
    if handler.usecolor
        Base.print_with_color(color, handler.stream, levelstr)
    else
        print(handler.stream, levelstr)
    end
    fullmsg = " [($(loggername)) $(location[1]):$(location[2])]: $msg\n"
    Base.print(handler.stream, fullmsg)
end



#-------------------------------------------------------------------------------
abstract AbstractLogLevel

immutable LogLevel <: AbstractLogLevel
    level::Int
end
const Debug = LogLevel(-10)
const Info  = LogLevel(0)
const Warn  = LogLevel(10)
const Error = LogLevel(20)

Base.:<=(l1::LogLevel, l2::LogLevel) = l1.level <= l2.level



#-------------------------------------------------------------------------------
type Logger{L}
    name::Symbol
    min_level::L
    handler
    children::Vector{Logger}
end

Logger{L}(name, parent::Logger{L}) = Logger{L}(Symbol(name), parent.min_level,
                                               parent.handler, Vector{Module}())
Logger(name, handler, level=Info) = Logger{typeof(level)}(Symbol(name), level,
                                                          handler, Vector{Module}())
const _root_logger = Logger(:Main, LogHandler(STDERR))

Base.push!(parent::Logger, child) = push!(parent.children, child)

const logger = _root_logger
root_logger() = _root_logger

function configure_logging(; kwargs...)
    configure_logging(root_logger(); kwargs...)
end

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

function configure_logging(m::Module; kwargs...)
    mod = find_logger_module(m)
    configure_logging(mod.logger; kwargs...)
end


shouldlog(logger::Logger, level) = logger.min_level <= level

logmsg(logger::Logger, level, location, msg) = logmsg(logger.handler, logger.name, level, location, msg)


function find_logger_module(m::Module)
    while module_name(m) !== :Main
        if isdefined(m, :logger)
            return m
        end
        m = module_parent(m)
    end
    return MicroLogging
end


# Logging macros
for (mname, level) in [(:debug, Debug),
                       (:info, Info),
                       (:warn, Warn),
                       (:error, Error)]
    @eval macro $mname(exs...)
        if length(exs) == 1
            mod = find_logger_module(current_module())
            logger_ex = :($mod.logger)
            msg = esc(exs[1])
        elseif length(exs) == 2
            logger_ex = esc(exs[1])
            msg = esc(exs[2])
        else
            error("@$mname must be called with one or two arguments")
        end
        quote
            logger = $logger_ex
            if shouldlog(logger, $($level))
                logmsg(logger, $($level), (@__FILE__, @__LINE__), $msg)
            end
            nothing
        end
    end
end


#-------------------------------------------------------------------------------
# Create per-module logger


"""
Create a logger for the current module
"""
macro makelogger()
    modname = string(current_module())
    parent_logger = find_logger_module(module_parent(current_module())).logger
    esc(
    quote
        const logger = Logger($modname, $parent_logger)
        push!($parent_logger, logger)
    end
    )
end


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




