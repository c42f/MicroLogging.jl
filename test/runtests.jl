using MicroLogging
using Base.Test

import MicroLogging: Debug, Info, Warn, Error

if VERSION < v"0.6-"
    # Override Test.@test_broken, which is broken on julia-0.5!
    # See https://github.com/JuliaLang/julia/issues/21008
    macro test_broken(exs...)
        esc(:(@test !($(exs...))))
    end
end


type LogRecord
    context
    level
    message
    kwargs
end

type TestHandler
    records
end

TestHandler() = TestHandler(LogRecord[])

function MicroLogging.logmsg(handler::TestHandler, context, level, msg; kwargs...)
    push!(handler.records, LogRecord(context, level, msg, kwargs))
end

function records!(handler::TestHandler)
    rs = handler.records
    handler.records = LogRecord[]
    rs
end

function simple_records!(handler::TestHandler)
    [(r.context, r.level, r.message) for r in records!(handler)]
end

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
    @test simple_records!(handler) == [
        (Main, Debug, "a"),
        (Main, Info , "b"),
        (Main, Warn , "c"),
        (Main, Error, "d")
    ]

    configure_logging(level=MicroLogging.Info)
    @debug "a"
    @info  "b"
    @warn  "c"
    @error "d"
    @test simple_records!(handler) == [
        (Main, Info , "b"),
        (Main, Warn , "c"),
        (Main, Error, "d")
    ]

    configure_logging(level=MicroLogging.Warn)
    @debug "a"
    @info  "b"
    @warn  "c"
    @error "d"
    @test simple_records!(handler) == [
        (Main, Warn , "c"),
        (Main, Error, "d")
    ]

    configure_logging(level=MicroLogging.Error)
    @debug "a"
    @info  "b"
    @warn  "c"
    @error "d"
    @test simple_records!(handler) == [
        (Main, Error, "d")
    ]
end


#-------------------------------------------------------------------------------
# Macro front end

@testset "Log to custom logger" begin
    handler = TestHandler()
    logger = Logger(:TestContext, MicroLogging.Debug, handler)

    @debug logger "a"
    @info  logger "b"
    @warn  logger "c"
    @error logger "d"

    @test simple_records!(handler) == [
        (:TestContext, Debug, "a"),
        (:TestContext, Info , "b"),
        (:TestContext, Warn , "c"),
        (:TestContext, Error, "d")
    ]
end


@testset "Log message formatting" begin
    handler = TestHandler()
    logger = Logger(:TestContext, MicroLogging.Info, handler)

    # Message may be formatted any way the user pleases
    @info logger begin
        A = ones(4,4)
        "sum(A) = $(sum(A))"
    end
    i = 10.50
    @info logger "$i"
    @info logger @sprintf("%.3f", i)

    @test simple_records!(handler) == [
        (:TestContext, Info, "sum(A) = 16.0"),
        (:TestContext, Info, "10.5"),
        (:TestContext, Info, "10.500")
    ]
end

@testset "Structured logging with key value pairs" begin
    handler = TestHandler()
    logger = Logger(:TestContext, MicroLogging.Info, handler)

    foo_val = 10
    expected_log_line = 1 + @__LINE__
    @info logger "test" progress=0.1 foo=foo_val
    recs = records!(handler)

    @test length(recs) == 1
    kwargs = Dict(recs[1].kwargs)

    # Builtin metadata
    @test kwargs[:location][1] == Base.source_path()
    @test_broken kwargs[:location][2] == expected_log_line # See #1
    @test kwargs[:module_] == Main

    # User-defined metadata
    @test kwargs[:progress] == 0.1
    @test kwargs[:foo] == foo_val
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
    @test simple_records!(handler) == [
        (A, Info , "a"),
        (A, Warn , "a"),
        (A, Error, "a")
    ]

    A.B.b()
    @test isempty(records!(handler))
    @test simple_records!(B_handler) == [
        (A.B, Warn , "b"),
        (A.B, Error, "b")
    ]

    A.B.C.c()
    @test isempty(records!(handler))
    @test simple_records!(B_handler) == [
        (A.B.C, Error, "c")
    ]
end


end
