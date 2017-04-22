__precompile__()

module MicroLogging

using Compat

export
    # Frontend
    @debug, @info, @warn, @error, @logmsg,
    # Log control
    with_logger, current_logger,
    limit_logging,
    # Logger methods
    logmsg, shouldlog,
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

"""
    @debug message  [key=value ...]  [log_control_hints]
    @info  message  [key=value ...]  [log_control_hints]
    @warn  message  [key=value ...]  [log_control_hints]
    @error message  [key=value ...]  [log_control_hints]
    @logmsg level message [key=value ...]  [log_control_hints]

Create a log record with an informational `message`.  For convenience, four
logging macros `@debug`, `@info`, `@warn` and `@error` are defined which log at
the standard severity levels `Debug`, `Info`, `Warn` and `Error`.  `@logmsg`
allows `level` to be set programmatically to any `LogLevel` or custom log level
types.

`message` can be any type.  You should generally ensure that `string(message)`
gives useful information, but custom logger backends may serialize the message
in a more useful way in general.  The optional `key=value` pairs support
arbitrary user defined metadata which will be passed through to the logging
backend as part of the log record.  By convention, there are some keys and
values which will be interpreted in a special way:

  * `progress=fraction` should be used to indicate progress through an
    algorithmic step named by `message`, it should be a value in the interval
    [0,1], and would generally be used to drive a progress bar or meter.


For extra control, `log_control_hints` is an optional expression containing key
value pairs enclosed in square brackets.  These are eagerly evaluated and
passed as keyword arguments to the `shouldlog()` function to perform early
filtering before the `message` expression is evaluated.

    [hint_key=value ...]

# Examples

```
@debug "Verbose degging information.  Invisible by default"
@info "An informational message"
@warn "Something was odd.  You should pay attention"
@error "A non fatal error occurred"

@debug begin
    sA = sum(A)
    "sum(A) = \$sA is an expensive operation, evaluated only when `shouldlog()` returns true"
end

for i=1:10000
    @info "With the default log filter, you will only see (i = \$i) ten times"  [max_log=10]
    @debug "Algorithm1" progress=i/10000
end

level = Info
@logmsg level "Some message with" a=1 b=2
```

"""
macro logmsg(level, message, exs...)
    level = esc(level)
    message = esc(message)
    logcontrol_kwargs = Any[]
    kwargs = Any[]
    for ex in exs
        if !isa(ex,Expr)
            throw(ArgumentError("Expected key value pair, got $ex"))
        elseif ex.head == :vect
            # Match "log control" keyword argument syntax, eg
            # @info "Foo" [once=true]
            for keyval in ex.args
                if !isa(keyval, Expr) || keyval.head != :(=) || !isa(keyval.args[1], Symbol)
                    throw(ArgumentError("Expected key value pair inside log control, got $keyval"))
                end
                push!(logcontrol_kwargs, Expr(:kw, keyval.args[1], esc(keyval.args[2])))
            end
        elseif ex.head == :(=) && isa(ex.args[1], Symbol)
            # Match key value pairs for structured log records
            push!(kwargs, Expr(:kw, ex.args[1], esc(ex.args[2])))
        else
            throw(ArgumentError("Expected key value pair, got $ex"))
        end
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
            # Bind log message generation into a closure, allowing us to defer
            # creation and formatting of messages until after filtering.
            create_msg = (logger, level, module_, filepath, line, id) ->
                logmsg(logger, level, $message, module_, filepath, line, id; $(kwargs...))
            dispatchmsg(logger, $level, $module_, @__FILE__, $lineno, $id, create_msg;
                        $(logcontrol_kwargs...))
        end
        nothing
    end
end

macro debug(message, exs...)  :(@logmsg Debug $(esc(message)) $(map(esc, exs)...))  end
macro  info(message, exs...)  :(@logmsg Info  $(esc(message)) $(map(esc, exs)...))  end
macro  warn(message, exs...)  :(@logmsg Warn  $(esc(message)) $(map(esc, exs)...))  end
macro error(message, exs...)  :(@logmsg Error $(esc(message)) $(map(esc, exs)...))  end

@eval @doc $(@doc @logmsg) $(Symbol("@debug"))
@eval @doc $(@doc @logmsg) $(Symbol("@info"))
@eval @doc $(@doc @logmsg) $(Symbol("@warn"))
@eval @doc $(@doc @logmsg) $(Symbol("@error"))


"""
    logmsg(logger, level, message, module_, filepath, line, id; key1=val1, ...)

Log a message to `logger` at `level`.  The location at which the message was
generated is given by `module_`, `filepath` and `line`. `id` is an arbitrary
unique `Symbol` to be used as a key to identify the log statement when
filtering.
"""
function logmsg end


"""
    shouldlog(logger, level, module_, filepath, line, id; [key1=value1, ...])

Return true when `logger` accepts a message at `level`, generated at source
location (`module_`,`filepath`,`line`) with unique log identifier `id`.  The
optional key value pairs `key1=value1, ...` are log control hints supplied at
the log site (see `@logmsg`).  By convention, 

    shouldlog(module_limit::LogLimit, level)

Determine whether messages of severity `level` should be generated according to
`module_limit`.
"""
function shouldlog end


function dispatchmsg(logger, level, module_, filepath, line, id, create_msg; log_control...)
    # If `!shouldlog()`, we get a second chance at an early bail-out based on
    # arbitrary logger-specific logic.
    if shouldlog(logger, level, module_, filepath, line, id; log_control...)
        # Catch all exceptions, to prevent log message generation from crashing
        # the program.  This lets users confidently toggle little-used
        # functionality - such as debug logging - in a production system.
        #
        # Users need to override and disable this if they want to use logging
        # as an audit trail.
        try
            create_msg(logger, level, module_, filepath, line, id)
        catch err
            # Try really hard to get the message to the logger, with
            # progressively less information.
            try
                msg = ("Error formatting log message at location ($module_,$filepath,$line).", err)
                logmsg(logger, Error, msg, module_, filepath, line, id)
            catch
                try
                    logmsg(logger, Error, "Error formatting log message", module_, filepath, line, id)
                catch
                end
            end
        end
    end
end

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
is attached to the task.
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

shouldlog(limit::LogLimit, level) = limit.min_level <= level

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

