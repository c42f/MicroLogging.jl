using MicroLogging
using Base.Test

import MicroLogging: LogLevel, Debug, Info, Warn, Error

if VERSION < v"0.6-"
    # Override Test.@test_broken, which is broken on julia-0.5!
    # See https://github.com/JuliaLang/julia/issues/21008
    macro test_broken(exs...)
        esc(:(@test !($(exs...))))
    end
end

# Test helpers

type LogRecord
    level
    message
    kwargs
end

LogRecord(level::LogLevel, message; kwargs...) = LogRecord(level, message, kwargs)

type TestHandler
    records::Vector{LogRecord}
end


TestHandler() = TestHandler(LogRecord[])

function MicroLogging.handlelog(handler::TestHandler, level, msg; kwargs...)
    push!(handler.records, LogRecord(level, msg, kwargs))
end

getlog!(handler::TestHandler) = shift!(handler.records)

Base.isempty(handler::TestHandler) = isempty(handler.records)


function record_matches(r, ref::Tuple)
    (r.level, r.message) == ref
end

function record_matches(r, ref::LogRecord)
    (r.level, r.message) == (ref.level, ref.message) || return false
    rkw = Dict(r.kwargs)
    for (k,v) in ref.kwargs
        (haskey(rkw, k) && rkw[k] == v) || return false
    end
    return true
end

# Use superset operator for improved log message reporting in @test
⊃(r::LogRecord, ref) = record_matches(r, ref)


#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
@testset "MicroLogging" begin

#-------------------------------------------------------------------------------
@testset "Basic logging" begin
    handler = TestHandler()
    configure_logging(handler=handler)

    configure_logging(level=Debug)
    @debug "a"
    @info  "b"
    @warn  "c"
    @error "d"
    @test getlog!(handler) ⊃ (Debug, "a")
    @test getlog!(handler) ⊃ (Info , "b")
    @test getlog!(handler) ⊃ (Warn , "c")
    @test getlog!(handler) ⊃ (Error, "d")

    configure_logging(level=MicroLogging.Info)
    @debug "a"
    @info  "b"
    @warn  "c"
    @error "d"
    @test getlog!(handler) ⊃ (Info , "b")
    @test getlog!(handler) ⊃ (Warn , "c")
    @test getlog!(handler) ⊃ (Error, "d")

    configure_logging(level=MicroLogging.Warn)
    @debug "a"
    @info  "b"
    @warn  "c"
    @error "d"
    @test getlog!(handler) ⊃ (Warn , "c")
    @test getlog!(handler) ⊃ (Error, "d")

    configure_logging(level=MicroLogging.Error)
    @debug "a"
    @info  "b"
    @warn  "c"
    @error "d"
    @test getlog!(handler) ⊃ (Error, "d")

    @test isempty(handler)
end


#-------------------------------------------------------------------------------
# Macro front end

@testset "Log to custom logger" begin
    handler = TestHandler()
    logger = Logger(MicroLogging.Debug, handler)

    @debug logger "a"
    @info  logger "b"
    @warn  logger "c"
    @error logger "d"

    @test getlog!(handler) ⊃ (Debug, "a")
    @test getlog!(handler) ⊃ (Info , "b")
    @test getlog!(handler) ⊃ (Warn , "c")
    @test getlog!(handler) ⊃ (Error, "d")

    @test isempty(handler)
end


@testset "Log message formatting" begin
    handler = TestHandler()
    logger = Logger(MicroLogging.Info, handler)

    # Message may be formatted any way the user pleases
    @info logger begin
        A = ones(4,4)
        "sum(A) = $(sum(A))"
    end
    i = 10.50
    @info logger "$i"
    @info logger @sprintf("%.3f", i)

    @test getlog!(handler) ⊃ (Info, "sum(A) = 16.0")
    @test getlog!(handler) ⊃ (Info, "10.5")
    @test getlog!(handler) ⊃ (Info, "10.500")

    @test isempty(handler)
end

@testset "Custom contexts - dependency injection" begin
    @eval type ThingWithInjectedLogger
        i::Int
        logger
    end
    @eval MicroLogging.get_logger(thing::ThingWithInjectedLogger) = thing.logger

    handler = TestHandler()
    logger = Logger(MicroLogging.Info, handler)

    thing = ThingWithInjectedLogger(42, logger)

    @info thing "Test"

    @test getlog!(handler) ⊃ LogRecord(Info, "Test", context=thing)

    @test isempty(handler)
end

#-------------------------------------------------------------------------------
# Log record structure

@testset "Structured logging with key value pairs" begin
    handler = TestHandler()
    logger = Logger(MicroLogging.Info, handler)

    foo_val = 10
    expected_log_line = 1 + @__LINE__
    @info logger "test" progress=0.1 foo=foo_val
    kwargs = Dict(getlog!(handler).kwargs)

    # Builtin metadata
    @test kwargs[:location][1] == Base.source_path()
    @test_broken kwargs[:location][2] == expected_log_line # See #1
    @test kwargs[:module_] == Main
    @test isa(kwargs[:id], Symbol)

    # User-defined metadata
    @test kwargs[:progress] == 0.1
    @test kwargs[:foo] == foo_val

    @test isempty(handler)
end


#-------------------------------------------------------------------------------
# Heirarchy
@eval module A
    using MicroLogging

    function a()
        @debug "a"
        @info  "a"
        @warn  "a"
        @error "a"
    end

    module B
        using MicroLogging

        function b()
            @debug "b"
            @info  "b"
            @warn  "b"
            @error "b"
        end

        module C
            using MicroLogging

            function c()
                @debug "c"
                @info  "c"
                @warn  "c"
                @error "c"
            end
        end
    end
end

@testset "Logger heirarchy" begin
    handler = TestHandler()
    B_handler = TestHandler()
    # Install root handler
    configure_logging(handler=handler)
    configure_logging(A, level=Info)
    # Override root handler for module B and its children
    configure_logging(A.B, level=Warn, handler=B_handler)
    configure_logging(A.B.C, level=Error)

    A.a()
    @test getlog!(handler) ⊃ LogRecord(Info , "a", context=A)
    @test getlog!(handler) ⊃ LogRecord(Warn , "a", context=A)
    @test getlog!(handler) ⊃ LogRecord(Error, "a", context=A)

    A.B.b()
    @test isempty(handler)
    @test getlog!(B_handler) ⊃ LogRecord(Warn , "b", context=A.B)
    @test getlog!(B_handler) ⊃ LogRecord(Error, "b", context=A.B)

    A.B.C.c()
    @test isempty(handler)
    @test getlog!(B_handler) ⊃ LogRecord(Error, "c", context=A.B.C)

    @test isempty(handler)
    @test isempty(B_handler)
end

end
