using MicroLogging
using Base.Test

import MicroLogging: Debug, Info, Warn, Error

type TestHandler
    messages::Vector{Any}
end

TestHandler() = TestHandler(Vector{Any}())

function MicroLogging.logmsg(handler::TestHandler, context, level, msg; kwargs...)
    push!(handler.messages, (context, level, msg))
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
    @test handler.messages == [(Main, Debug, "a"),
                               (Main, Info , "b"),
                               (Main, Warn , "c"),
                               (Main, Error, "d")]
    empty!(handler.messages)

    configure_logging(level=MicroLogging.Info)
    @debug "a"
    @info  "b"
    @warn  "c"
    @error "d"
    @test handler.messages == [(Main, Info , "b"),
                               (Main, Warn , "c"),
                               (Main, Error, "d")]
    empty!(handler.messages)

    configure_logging(level=MicroLogging.Warn)
    @debug "a"
    @info  "b"
    @warn  "c"
    @error "d"
    @test handler.messages == [(Main, Warn , "c"),
                               (Main, Error, "d")]
    empty!(handler.messages)

    configure_logging(level=MicroLogging.Error)
    @debug "a"
    @info  "b"
    @warn  "c"
    @error "d"
    @test handler.messages == [(Main, Error, "d")]
    empty!(handler.messages)

end

#-------------------------------------------------------------------------------

@testset "Log to custom logger" begin
    handler = TestHandler()
    logger = Logger(:TestContext, MicroLogging.Debug, handler)

    @debug logger "a"
    @info  logger "b"
    @warn  logger "c"
    @error logger "d"

    @test handler.messages == [(:TestContext, Debug, "a"),
                               (:TestContext, Info , "b"),
                               (:TestContext, Warn , "c"),
                               (:TestContext, Error, "d")]
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

    @test handler.messages == [(:TestContext, Info, "sum(A) = 16.0"),
                               (:TestContext, Info, "10.5"),
                               (:TestContext, Info, "10.500")]
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
    configure_logging(handler=handler)
    configure_logging(A, level=Info)
    configure_logging(A.B, level=Warn, handler=B_handler)
    configure_logging(A.B.C, level=Error)
    A.a()
    @test handler.messages == [(A, Info , "a"),
                               (A, Warn , "a"),
                               (A, Error, "a")]
    empty!(handler.messages)

    A.B.b()
    @test B_handler.messages == [(A.B, Warn , "b"),
                                 (A.B, Error, "b")]
    @test isempty(handler.messages)
    empty!(B_handler.messages)

    A.B.C.c()
    @test B_handler.messages == [(A.B.C, Error, "c")]
    @test isempty(handler.messages)
end


#-------------------------------------------------------------------------------
#=

function logger_macro_forms()
    # Access logger
    @info logger "bar()"
    # Computation
    @info begin
        a = 0.5
        @sprintf("a = %.2f, a^2 = %.2f", a, a.^2)
    end
end


function baz()
    # Loggers as variables
    handler = MicroLogging.LogHandler(STDOUT)
    logger = Logger(:LocalLogger, handler, MicroLogging.Warn)
    @debug logger "baz()"
    @info  logger "baz()"
    @warn  logger "baz()"
    @error logger "baz()"
end


#=
function qux()
    # Custom log levels ??
    @logmsg logger :mylevel "asdf" 
    @logmsg Debug2 "asdf" 
    @logmsg :level "asdf" 
end
=#


type TestHandler
    messages::Vector{Any}
end

TestHandler() = TestHandler(Vector{Any}())

MicroLogging.logmsg(handler::TestHandler, loggername, level, location, msg) =
    push!(handler.messages, (loggername, level, msg))


@testset "Basic logging"

    handler = TestHandler()
    configure_logging(Main,
configure_logging(Main,
    level=MicroLogging.Debug,
    handler=TestHandler()
)
Foo.foo(1)
Foo.foo(1)

println()

Foo.Bar.bar()

println()
Foo.Bar.baz()

=#

end
