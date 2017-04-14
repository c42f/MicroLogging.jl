__precompile__()

module MicroLogging

export
    # Frontend
    @debug, @info, @warn, @error, @logmsg,
    # Log control
    with_logger, current_logger,
    limit_logging,
    # Logger methods
    logmsg,
    # Example logger
    SimpleLogger


"""
Severity/verbosity of a log record.

The log level provides a key against which log records may be filtered before
any work is done formatting the log message and other metadata.
"""
@enum LogLevel Debug Info Warn Error


include("handlers.jl")


#-------------------------------------------------------------------------------
# Logging macros and frontend

macro logmsg(level, message, exs...)
    level = esc(level)
    message = esc(message)
    kwargs = Any[]
    for ex in exs
        if !isa(ex,Expr) || ex.head != :(=) || !isa(ex.args[1], Symbol)
            throw(ArgumentError("Expected key value pair, got $ex"))
        end
        push!(kwargs, Expr(:kw, ex.args[1], esc(ex.args[2])))
    end
    module_ = current_module()
    loglimit = log_limiter(module_)
    # FIXME: The following dubious hack gives an approximate line number
    # only - the line of the start of the toplevel expression! See #1.
    lineno = Int(unsafe_load(cglobal(:jl_lineno, Cint)))
    id = Expr(:quote, gensym())
    quote
        loglimit = $loglimit
        if shouldlog(loglimit, $level)
            logger = current_logger()
            # FIXME: Test whether shouldlog(logger,level,id) here is worthwhile
            logmsg(logger, $level, $message;
                   id=$id, module_=$module_, location=(@__FILE__, $lineno),
                   $(kwargs...))
        end
        nothing
    end
end

macro debug(message, exs...)  :(@logmsg Debug $(esc(message)) $(map(esc, exs)...))  end
macro  info(message, exs...)  :(@logmsg Info  $(esc(message)) $(map(esc, exs)...))  end
macro  warn(message, exs...)  :(@logmsg Warn  $(esc(message)) $(map(esc, exs)...))  end
macro error(message, exs...)  :(@logmsg Error $(esc(message)) $(map(esc, exs)...))  end

"""
    function logmsg(logger, level, message; kwargs)

Dispatch `message` to `logger` at `level`.

FIXME: Refine and document keywords.
"""
function logmsg end

#-------------------------------------------------------------------------------
# Logger control and lookup

"""
    with_logger(function, logger)

Execute `function`, directing all log messages to `logger`.

# Example

```julia
function test(x)
    @info "x = \$x"
end

with_logger(logger) do
    test(1)
    test([1,2])
end
```
"""
with_logger(f::Function, loghandler) = task_local_storage(f, :CURRENT_LOGGER, loghandler)


_global_logger = nothing  # See __init__

"""
    current_logger()

Return the logger for the current task, or the global logger if none is
specified.
"""
current_logger() = get(task_local_storage(), :CURRENT_LOGGER, _global_logger)


#-------------------------------------------------------------------------------
# Per-module log limiting machinery

type LogLimit
    min_level::LogLevel
    children::Vector{LogLimit}
end

LogLimit(parent::LogLimit) = LogLimit(parent.min_level, Vector{LogLimit}())
LogLimit(level::LogLevel)  = LogLimit(level, Vector{LogLimit}())

Base.push!(parent::LogLimit, child) = push!(parent.children, child)

"""
    shouldlog(logger, level)

Determine whether messages of severity `level` should be sent to `logger`.
"""
shouldlog(logger::LogLimit, level) = logger.min_level <= level


const _registered_limiters = Dict{Module,LogLimit}() # See __init__

# Get the LogLimit object which should be used to control the minimum log level
# for module `mod`.
function log_limiter(mod::Module=Main)
    get!(_registered_limiters, mod) do
        parent = log_limiter(module_parent(mod))
        loglimit = LogLimit(parent)
        push!(parent, loglimit)
        loglimit
    end
end

"""
    limit_logging(module, level)

Limit log messages from `module` and its submodules to levels greater than or
equal to `level`, which defaults to Info when a module is loaded.  This is a
*global* setting per module, intended to make debug logging extremely cheap
when disabled.
"""
function limit_logging(logger::LogLimit, level)
    logger.min_level = level
    for child in logger.children
        limit_logging(child, level)
    end
end

limit_logging(level) = limit_logging(Main, level)
limit_logging(mod::Module, level) = limit_logging(log_limiter(mod), level)


function __init__()
    _registered_limiters[Main] = LogLimit(Info)
    global _global_logger = SimpleLogger(STDERR)
end


end

