using MicroLogging
using Base.Test

import MicroLogging: Debug, Info, Warn, Error

type TestHandler
    messages::Vector{Any}
end

TestHandler() = TestHandler(Vector{Any}())

MicroLogging.logmsg(handler::TestHandler, loggername, level, location, msg) =
    push!(handler.messages, (loggername, level, msg))

function foo(x)
    @debug "foo($x)"
    @info  "foo($x)"
    @warn  "foo($x)"
    @error "foo($x)"
end

#-------------------------------------------------------------------------------
@testset "Basic logging" begin

    handler = TestHandler()
    configure_logging(handler=handler)

    configure_logging(level=Debug)
    foo(1)
    @test handler.messages == [(:Main, Debug, "foo(1)"),
                               (:Main, Info , "foo(1)"),
                               (:Main, Warn , "foo(1)"),
                               (:Main, Error, "foo(1)")]
    empty!(handler.messages)

    configure_logging(level=MicroLogging.Info)
    foo(2)
    @test handler.messages == [(:Main, Info , "foo(2)"),
                               (:Main, Warn , "foo(2)"),
                               (:Main, Error, "foo(2)")]
    empty!(handler.messages)

    configure_logging(level=MicroLogging.Warn)
    foo(3)
    @test handler.messages == [(:Main, Warn , "foo(3)"),
                               (:Main, Error, "foo(3)")]
    empty!(handler.messages)

    configure_logging(level=MicroLogging.Error)
    foo(4)
    @test handler.messages == [(:Main, Error, "foo(4)")]
    empty!(handler.messages)

end


#-------------------------------------------------------------------------------
# Heirarchy
module A
    using MicroLogging
    @makelogger

    function a()
        @debug "a"
        @info  "a"
        @warn  "a"
        @error "a"
    end

    module B
        using MicroLogging
        @makelogger

        function b()
            @debug "b"
            @info  "b"
            @warn  "b"
            @error "b"
        end

        module C
            using MicroLogging
            @makelogger

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
    @test handler.messages == [(:A, Info , "a"),
                               (:A, Warn , "a"),
                               (:A, Error, "a")]
    empty!(handler.messages)

    A.B.b()
    @test B_handler.messages == [(Symbol("A.B"), Warn , "b"),
                                 (Symbol("A.B"), Error, "b")]
    @test isempty(handler.messages)
    empty!(B_handler.messages)

    A.B.C.c()
    @test B_handler.messages == [(Symbol("A.B.C"), Error, "c")]
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
