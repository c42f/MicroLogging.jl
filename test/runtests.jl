using MicroLogging
using Base.Test
using Compat
import MicroLogging: LogLevel, BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel,
    shouldlog, handle_message, min_enabled_level, catch_exceptions,
    configure_logging

import Base: ismatch

#-------------------------------------------------------------------------------
# Log records
struct LogRecord
    level
    message
    _module
    group
    id
    file
    line
    kwargs
end
LogRecord(args...; kwargs...) = LogRecord(args..., kwargs)

#-------------------------------------------------------------------------------
# Logger with extra test-related state
mutable struct TestLogger <: AbstractLogger
    logs::Vector{LogRecord}
    min_level::LogLevel
    catch_exceptions::Bool
    shouldlog_args
end

TestLogger(; min_level=BelowMinLevel, catch_exceptions=false) = TestLogger(LogRecord[], min_level, catch_exceptions, nothing)
min_enabled_level(logger::TestLogger) = logger.min_level

function shouldlog(logger::TestLogger, level, _module, group, id)
    logger.shouldlog_args = (level, _module, group, id)
    true
end

function handle_message(logger::TestLogger, level, msg, _module,
                        group, id, file, line; kwargs...)
    push!(logger.logs, LogRecord(level, msg, _module, group, id, file, line, kwargs))
end

# Don't catch exceptions generating messages for the test logger
catch_exceptions(logger::TestLogger) = logger.catch_exceptions

function configure_logging(logger::TestLogger; min_level=Info)
    logger.min_level = min_level
    logger
end

function collect_test_logs(f; kwargs...)
    logger = TestLogger(; kwargs...)
    with_logger(f, logger)
    logger.logs
end


#--------------------------------------------------
# Log testing tools
macro test_logs(exs...)
    length(exs) >= 1 || throw(ArgumentError("""`@test_logs` needs at least one arguments.
                               Usage: `@test_logs [msgs...] expr_to_run`"""))
    args = Any[]
    kwargs = Any[]
    for e in exs[1:end-1]
        if e isa Expr && e.head == :(=)
            push!(kwargs, Expr(:kw, e.args...))
        else
            push!(args, esc(e))
        end
    end
    # TODO: Better error reporting in @test
    ex = quote
        @test ismatch_logs($(args...); $(kwargs...)) do
            $(esc(exs[end]))
        end
    end
    if Compat.macros_have_sourceloc
        # Propagate source code location of @test_logs to @test macro
        ex.args[2].args[2] = __source__
    end
    ex
end

function ismatch_logs(f, patterns...; kwargs...)
    logs = collect_test_logs(f; kwargs...)
    length(logs) == length(patterns) || return false
    for (pattern,log) in zip(patterns, logs)
        ismatch(pattern, log) || return false
    end
    return true
end

function ismatch(ref::Tuple, r::LogRecord)
    stdfields = (r.level, r.message, r._module, r.group, r.id, r.file, r.line)
    ref == stdfields[1:length(ref)]
end


#--------------------------------------------------
@testset "Logging" begin

include("core.jl")
include("config.jl")

end
