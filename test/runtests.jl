using MicroLogging
using Base.Test
using Compat
import MicroLogging: LogLevel, BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel

if VERSION < v"0.6-"
    # Override Test.@test_broken, which is broken on julia-0.5!
    # See https://github.com/JuliaLang/julia/issues/21008
    macro test_broken(exs...)
        esc(:(@test !($(exs...))))
    end
end

# Test helpers

mutable struct LogRecord
    level
    message
    _module
    group
    id
    file
    line
    kwargs
    shouldlog_args
end

LogRecord(args...; kwargs...) = LogRecord(args..., kwargs)
LogRecord(level, msg, _module=nothing, group=nothing, id=nothing, file=nothing, line=nothing; kwargs...) =
	LogRecord(level, msg, _module, group, id, file, line, kwargs, nothing)

mutable struct TestLogger <: AbstractLogger
    records::Vector{LogRecord}
    min_level::LogLevel
    catch_exceptions::Bool
    shouldlog_args
end

TestLogger(min_level=BelowMinLevel; catch_exceptions=true) = TestLogger(LogRecord[], min_level, catch_exceptions, nothing)

MicroLogging.min_enabled_level(logger::TestLogger) = logger.min_level
MicroLogging.catch_exceptions(logger::TestLogger) = logger.catch_exceptions

function MicroLogging.configure_logging(logger::TestLogger; min_level=Info)
    logger.min_level = min_level
    logger
end

function MicroLogging.shouldlog(logger::TestLogger, level, _module, group, id)
    logger.shouldlog_args = (level, _module, group, id)
    true
end

function MicroLogging.handle_message(logger::TestLogger, level, msg, _module,
                                     group, id, file, line; kwargs...)
    push!(logger.records, LogRecord(level, msg, _module, group, id, file, line,
                                    kwargs, logger.shouldlog_args))
end

function collect_logs(f::Function, min_level=BelowMinLevel)
    logger = TestLogger(min_level)
    with_logger(f, logger)
    logger.records
end

function record_matches(r, ref::Tuple)
    if length(ref) == 1
        return (r.level,) == ref
    else
        return (r.level, r.message) == ref
    end
end

function record_matches(r, ref::LogRecord)
    (r.level, r.message) == (ref.level, ref.message)       || return false
    (ref._module  == nothing || r._module  == ref._module) || return false
    (ref.group    == nothing || r.group    == ref.group)   || return false
    (ref.id       == nothing || r.id       == ref.id)      || return false
    (ref.file     == nothing || r.file     == ref.file)    || return false
    (ref.line     == nothing || r.line     == ref.line)    || return false
    rkw = Dict(r.kwargs)
    for (k,v) in ref.kwargs
        (haskey(rkw, k) && rkw[k] == v) || return false
    end
    return true
end

# Use superset operator for improved log message reporting in @test
⊃(r::LogRecord, ref) = record_matches(r, ref)

macro test_logs(exs...)
    length(exs) >= 1 || throw(ArgumentError("""`@test_logs` needs at least one arguments.
                               Usage: `@test_logs [msgs...] expr_to_run`"""))
    quote
        @test ismatch_logs($(exs[1:end-1]...)) do
            $(esc(exs[end]))
        end
    end
end

function ismatch_logs(f, patterns...)
    logs = collect_logs(f)
    length(logs) == length(patterns) || return false
    for (pattern,log) in zip(patterns, logs)
        ismatch(pattern, log) || return false
    end
    return true
end

function Base.ismatch(ref::Tuple, r::LogRecord)
    if length(ref) == 1
        return (r.level,) == ref
    else
        return (r.level, r.message) == ref
    end
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
    logs = collect_logs() do
        # Message may be formatted any way the user pleases
        @info begin
            A = ones(4,4)
            "sum(A) = $(sum(A))"
        end
        x = 10.50
        @info "$x"
        @info @sprintf("%.3f", x)
    end

    @test logs[1] ⊃ (Info, "sum(A) = 16.0")
    @test logs[2] ⊃ (Info, "10.5")
    @test logs[3] ⊃ (Info, "10.500")
    @test length(logs) == 3
end

@testset "Programmatically defined levels" begin
    logs = collect_logs() do
        for level ∈ [Info,Warn]
            @logmsg level "X"
        end
    end

    @test logs[1] ⊃ (Info, "X")
    @test logs[2] ⊃ (Warn, "X")
    @test length(logs) == 2
end

@testset "Structured logging with key value pairs" begin
    foo_val = 10
    bar_val = 100
    logs = collect_logs() do
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
    @test record2 ⊃ (Info,"test2")
    kwargs = Dict(record2.kwargs)
    @test kwargs[:value_in_msg_block] === 1000.0

    # Splatting of keywords
    record3 = logs[3]
    @test record3 ⊃ (Info,"test3")
    kwargs = Dict(record3.kwargs)
    @test sort(collect(keys(kwargs))) == [:a, :b]
    @test kwargs[:a] === 1
    @test kwargs[:b] === 2.0
end

@testset "Log message exception handling" begin
    # Errors are caught by default
    logs = collect_logs() do
        @info "foo $(1÷0)"
        @info "bar"
    end
    @test logs[1] ⊃ (Error,)
    @test logs[2] ⊃ (Info,"bar")
    @test length(logs) == 2
    @test_throws DivideError with_logger(TestLogger(catch_exceptions=false)) do
        @info "foo $(1÷0)"
    end
end

@testset "Special keywords" begin
    logs = collect_logs() do
        @info "foo" _module=MicroLogging _id=:asdf _group=:somegroup _file="/a/file" _line=-10
    end
    @test length(logs) == 1
    record = logs[1]
    @test record._module == MicroLogging
    @test record.group == :somegroup
    @test record.id == :asdf
    @test record.file == "/a/file"
    @test record.line == -10
    # Test consistency with shouldlog() function arguments
    @test record.level   == record.shouldlog_args[1]
    @test record._module == record.shouldlog_args[2]
    @test record.group   == record.shouldlog_args[3]
    @test record.id      == record.shouldlog_args[4]
end


#-------------------------------------------------------------------------------
# Early log level filtering

@testset "Early log filtering" begin
    @testset "Log filtering, per task logger" begin
        logs = collect_logs() do
            @debug "a"
            configure_logging(min_level=Info)
            @debug "a"
            @info  "b"
            configure_logging(min_level=Error)
            @warn  "c"
            @error "d"
        end

        @test logs[1] ⊃ (Debug, "a")
        @test logs[2] ⊃ (Info , "b")
        @test logs[3] ⊃ (Error, "d")
        @test length(logs) == 3
    end

    @testset "Log filtering, global logger" begin
        # Same test as above, but with global logger
        old_logger = global_logger()
        logger = TestLogger(Debug)
        global_logger(logger)
        @debug "a"
        configure_logging(min_level=Info)
        @debug "a"
        @info  "b"
        configure_logging(min_level=Error)
        @test_throws ArgumentError configure_logging("unknown_argument")
        @warn  "c"
        @error "d"
        logs = logger.records
        global_logger(old_logger)

        @test logs[1] ⊃ (Debug, "a")
        @test logs[2] ⊃ (Info , "b")
        @test logs[3] ⊃ (Error, "d")
        @test length(logs) == 3
    end

    @testset "Log level filtering - global flag" begin
        # Test utility: Log once at each standard level
        function log_each_level()
            collect_logs() do
                @debug "a"
                @info  "b"
                @warn  "c"
                @error "d"
            end
        end

        disable_logging(BelowMinLevel)
        logs = log_each_level()
        @test logs[1] ⊃ (Debug, "a")
        @test logs[2] ⊃ (Info , "b")
        @test logs[3] ⊃ (Warn , "c")
        @test logs[4] ⊃ (Error, "d")
        @test length(logs) == 4

        disable_logging(Debug)
        logs = log_each_level()
        @test logs[1] ⊃ (Info , "b")
        @test logs[2] ⊃ (Warn , "c")
        @test logs[3] ⊃ (Error, "d")
        @test length(logs) == 3

        disable_logging(Info)
        logs = log_each_level()
        @test logs[1] ⊃ (Warn , "c")
        @test logs[2] ⊃ (Error, "d")
        @test length(logs) == 2

        disable_logging(Warn)
        logs = log_each_level()
        @test logs[1] ⊃ (Error, "d")
        @test length(logs) == 1

        disable_logging("Warn")
        logs = log_each_level()
        @test logs[1] ⊃ (Error, "d")
        @test length(logs) == 1

        disable_logging(Error)
        logs = log_each_level()
        @test length(logs) == 0

        # Reset to default
        disable_logging(BelowMinLevel)
    end
end

#-------------------------------------------------------------------------------

@eval module A
    using MicroLogging
    function a()
        @info  "a"
    end

    module B
        using MicroLogging
        function b()
            @info  "b"
        end
    end
end

@testset "Capture of module information" begin
    logs = collect_logs() do
        A.a()
        A.B.b()
    end

    @test logs[1] ⊃ LogRecord(Info, "a", A)
    @test logs[2] ⊃ LogRecord(Info, "b", A.B)
    @test length(logs) == 2
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
    logs = collect_logs(Info) do
        @logmsg LogLevelTest.critical "blah"
        @logmsg LogLevelTest.debug_verbose "blah"
    end

    @test logs[1] ⊃ (LogLevelTest.critical, "blah")
    @test length(logs) == 1
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

end
