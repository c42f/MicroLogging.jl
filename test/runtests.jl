using MicroLogging
using Base.Test
using Compat
import MicroLogging: LogLevel, BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel,
    shouldlog, handle_message, min_enabled_level, catch_exceptions,
    configure_logging

import Base: ismatch

if VERSION < v"0.6-"
    # Override Test.@test_broken, which is broken on julia-0.5!
    # See https://github.com/JuliaLang/julia/issues/21008
    macro test_broken(exs...)
        esc(:(@test !($(exs...))))
    end
end

# Test helpers

#--------------------------------------------------
# A logger which does nothing, except enable exceptions to propagate
struct AllowExceptionsLogger <: AbstractLogger ; end
handle_message(logger::AllowExceptionsLogger) = nothing
catch_exceptions(logger::AllowExceptionsLogger) = false

#--------------------------------------------------
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

#--------------------------------------------------
# Logger with extra test-related state
mutable struct TestLogger <: AbstractLogger
    logs::Vector{LogRecord}
    min_level::LogLevel
    shouldlog_args
end

TestLogger(min_level=BelowMinLevel) = TestLogger(LogRecord[], min_level, nothing)
min_enabled_level(logger::TestLogger) = logger.min_level

function shouldlog(logger::TestLogger, level, _module, group, id)
    logger.shouldlog_args = (level, _module, group, id)
    true
end

function handle_message(logger::TestLogger, level, msg, _module,
                        group, id, file, line; kwargs...)
    push!(logger.logs, LogRecord(level, msg, _module, group, id, file, line, kwargs))
end

function configure_logging(logger::TestLogger; min_level=Info)
    logger.min_level = min_level
    logger
end

function collect_test_logs(f; min_level=Debug)
    logger = TestLogger(min_level)
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

function ismatch_logs(f, patterns...; min_level=BelowMinLevel, kwargs...)
    logs = collect_test_logs(f; min_level=min_level, kwargs...)
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

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
@testset "MicroLogging" begin

@testset "Basic logging" begin
    @test_logs (Debug, "a") @debug "a"
    @test_logs (Info,  "a") @info  "a"
    @test_logs (Warn,  "a") @warn  "a"
    @test_logs (Error, "a") @error "a"
end

#-------------------------------------------------------------------------------
# Front end

@testset "Log message formatting" begin
    @test_logs (Info, "sum(A) = 16.0") @info begin
        A = ones(4,4)
        "sum(A) = $(sum(A))"
    end
    x = 10.50
    @test_logs (Info, "10.5") @info "$x"
    @test_logs (Info, "10.500") @info @sprintf("%.3f", x)
end

@testset "Programmatically defined levels" begin
    level = Info
    @test_logs (Info, "X") @logmsg level "X"
    level = Warn
    @test_logs (Warn, "X") @logmsg level "X"
end

@testset "Structured logging with key value pairs" begin
    foo_val = 10
    bar_val = 100
    logs = collect_test_logs() do
        @info "test"  bar_val  progress=0.1  foo=foo_val  2*3  real_line=(@__LINE__)
        @info begin
            value_in_msg_block = 1000.0
            "test2"
        end value_in_msg_block
        test_splatting(;kws...) = @info "test3" kws...
        test_splatting(a=1,b=2.0)
    end
    @test length(logs) == 3

    record = logs[1]

    kwargs = Dict(record.kwargs)

    # Builtin metadata
    @test record._module == Main
    @test record.file == Base.source_path()
    if Compat.macros_have_sourceloc # See #1
        @test record.line == kwargs[:real_line]
    end
    @test record.id == :Main_02d1fa22

    # User-defined metadata
    @test kwargs[:bar_val] === bar_val
    @test kwargs[:progress] == 0.1
    @test kwargs[:foo] === foo_val
    @test kwargs[Symbol(:(2*3))] === 6

    # Keyword values accessible from message block
    record2 = logs[2]
    @test ismatch((Info,"test2"), record2)
    kwargs = Dict(record2.kwargs)
    @test kwargs[:value_in_msg_block] === 1000.0

    # Splatting of keywords
    record3 = logs[3]
    @test ismatch((Info,"test3"), record3)
    kwargs = Dict(record3.kwargs)
    @test sort(collect(keys(kwargs))) == [:a, :b]
    @test kwargs[:a] === 1
    @test kwargs[:b] === 2.0
end

@testset "Log message exception handling" begin
    # Exceptions in message creation are caught by default
    @test_logs (Error,) @info "foo $(1÷0)"
    # Exceptions propagate if explicitly disabled for the logger type
    @test_throws DivideError with_logger(AllowExceptionsLogger()) do
        @info "foo $(1÷0)"
    end
end

@testset "Special keywords" begin
    logger = TestLogger()
    with_logger(logger) do
        @info "foo" _module=MicroLogging _id=:asdf _group=:somegroup _file="/a/file" _line=-10
    end
    @test length(logger.logs) == 1
    record = logger.logs[1]
    @test record._module == MicroLogging
    @test record.group == :somegroup
    @test record.id == :asdf
    @test record.file == "/a/file"
    @test record.line == -10
    # Test consistency with shouldlog() function arguments
    @test record.level   == logger.shouldlog_args[1]
    @test record._module == logger.shouldlog_args[2]
    @test record.group   == logger.shouldlog_args[3]
    @test record.id      == logger.shouldlog_args[4]
end


#-------------------------------------------------------------------------------
# Early log level filtering

@testset "Early log filtering" begin
    @testset "Log filtering, per task logger" begin
        @test_logs (Warn, "c") min_level=Warn begin
            @info "b"
            @warn "c"
        end
    end

    @testset "Log filtering, global logger" begin
        old_logger = global_logger()
        logs = let
            logger = TestLogger(Warn)
            global_logger(logger)
            @info "b"
            @warn "c"
            logger.logs
        end
        global_logger(old_logger)

        @test length(logs) == 1
        @test ismatch((Warn , "c"), logs[1])
    end

    @testset "Log level filtering - global flag" begin
        # Test utility: Log once at each standard level
        function log_each_level()
            @debug "a"
            @info  "b"
            @warn  "c"
            @error "d"
        end

        disable_logging(BelowMinLevel)
        @test_logs (Debug, "a") (Info, "b") (Warn, "c") (Error, "d")  log_each_level()

        disable_logging(Debug)
        @test_logs (Info, "b") (Warn, "c") (Error, "d")  log_each_level()

        disable_logging(Info)
        @test_logs (Warn, "c") (Error, "d")  log_each_level()

        disable_logging(Warn)
        @test_logs (Error, "d")  log_each_level()

        disable_logging("Warn")
        @test_logs (Error, "d")  log_each_level()

        disable_logging(Error)
        @test_logs log_each_level()

        # Reset to default
        disable_logging(BelowMinLevel)
    end
end

#-------------------------------------------------------------------------------

@eval module LogModuleTest
    using MicroLogging
    function a()
        @info  "a"
    end

    module Submodule
        using MicroLogging
        function b()
            @info  "b"
        end
    end
end

@testset "Capture of module information" begin
    @test_logs(
        (Info, "a", LogModuleTest),
        (Info, "b", LogModuleTest.Submodule),
        begin
            LogModuleTest.a()
            LogModuleTest.Submodule.b()
        end
    )
end


#-------------------------------------------------------------------------------

# Custom log levels

@eval module LogLevelTest
    using MicroLogging

    struct MyLevel
        level::Int
    end

    Base.convert(::Type{MicroLogging.LogLevel}, l::MyLevel) = MicroLogging.LogLevel(l.level)

    const critical = MyLevel(10000)
    const debug_verbose = MyLevel(-10000)
end

@testset "Custom log levels" begin
    @test_logs (LogLevelTest.critical, "blah") @logmsg LogLevelTest.critical "blah"
    logs = collect_test_logs(min_level=Debug) do
        @logmsg LogLevelTest.debug_verbose "blah"
    end
    @test length(logs) == 0
end


#-------------------------------------------------------------------------------

@testset "SimpleLogger" begin
    @test MicroLogging.shouldlog(SimpleLogger(STDERR), Debug) === false
    @test MicroLogging.shouldlog(SimpleLogger(STDERR), Info) === true
    @test MicroLogging.shouldlog(SimpleLogger(STDERR, Debug), Debug) === true

    function genmsg(level, message, _module, filepath, line; kws...)
        io = IOBuffer()
        logger = SimpleLogger(io, Debug)
        MicroLogging.handle_message(logger, level, message, _module, :group, :id,
                                    filepath, line; kws...)
        s = String(take!(io))
        # Remove the small amount of color, as `Base.print_with_color` can't be
        # simply controlled.
        s = replace(s, r"^\e\[1m\e\[..m(.- )\e\[39m\e\[22m", s"\1")
        # println(s)
        s
    end

    # Simple
    @test genmsg(Info, "msg", Main, "some/path.jl", 101) ==
    """
    I- msg -Info:Main:path.jl:101
    """

    # Multiline message
    @test genmsg(Warn, "line1\nline2", Main, "some/path.jl", 101) ==
    """
    W- line1
    |  line2 -Warn:Main:path.jl:101
    """

    # Keywords
    @test genmsg(Error, "msg", Base, "other.jl", 101, a=1, b="asdf") ==
    """
    E- msg -Error:Base:other.jl:101
    |  a = 1
    |  b = asdf
    """
end

include("config.jl")

end
