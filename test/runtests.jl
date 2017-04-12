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

function collect_logs(f::Function)
    handler = TestHandler()
    with_logger(f, handler)
    handler.records
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
    limit_logging(Debug)
    logs = collect_logs() do
        @debug "a"
        @info  "b"
        @warn  "c"
        @error "d"
    end
    @test logs[1] ⊃ (Debug, "a")
    @test logs[2] ⊃ (Info , "b")
    @test logs[3] ⊃ (Warn , "c")
    @test logs[4] ⊃ (Error, "d")
    @test length(logs) == 4

    limit_logging(Info)
    logs = collect_logs() do
        @debug "a"
        @info  "b"
        @warn  "c"
        @error "d"
    end
    @test logs[1] ⊃ (Info , "b")
    @test logs[2] ⊃ (Warn , "c")
    @test logs[3] ⊃ (Error, "d")
    @test length(logs) == 3

    limit_logging(Warn)
    logs = collect_logs() do
        @debug "a"
        @info  "b"
        @warn  "c"
        @error "d"
    end
    @test logs[1] ⊃ (Warn , "c")
    @test logs[2] ⊃ (Error, "d")
    @test length(logs) == 2

    limit_logging(Error)
    logs = collect_logs() do
        @debug "a"
        @info  "b"
        @warn  "c"
        @error "d"
    end
    @test logs[1] ⊃ (Error, "d")
    @test length(logs) == 1
end


#-------------------------------------------------------------------------------
# Macro front end

@testset "Log message formatting" begin
    limit_logging(Info)
    logs = collect_logs() do
        # Message may be formatted any way the user pleases
        @info begin
            A = ones(4,4)
            "sum(A) = $(sum(A))"
        end
        i = 10.50
        @info "$i"
        @info @sprintf("%.3f", i)
    end

    @test logs[1] ⊃ (Info, "sum(A) = 16.0")
    @test logs[2] ⊃ (Info, "10.5")
    @test logs[3] ⊃ (Info, "10.500")
    @test length(logs) == 3
end

#-------------------------------------------------------------------------------
# Log record structure

@testset "Structured logging with key value pairs" begin
    limit_logging(Info)
    foo_val = 10
    logs = collect_logs() do
        @info "test" progress=0.1 foo=foo_val real_line=(@__LINE__)
    end
    @test length(logs) == 1

    kwargs = Dict(logs[1].kwargs)

    # Builtin metadata
    @test kwargs[:location][1] == Base.source_path()
    @test_broken kwargs[:location][2] == kwargs[:real_line] # See #1
    @test kwargs[:module_] == Main
    @test isa(kwargs[:id], Symbol)

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
    limit_logging(A, Info)
    # Override root handler for module B and its children
    limit_logging(A.B, Warn)
    limit_logging(A.B.C, Error)

    logs = collect_logs() do
        A.a()
        A.B.b()
        A.B.C.c()
    end

    @test logs[1] ⊃ LogRecord(Info , "a", module_=A)
    @test logs[2] ⊃ LogRecord(Warn , "a", module_=A)
    @test logs[3] ⊃ LogRecord(Error, "a", module_=A)

    @test logs[4] ⊃ LogRecord(Warn , "b", module_=A.B)
    @test logs[5] ⊃ LogRecord(Error, "b", module_=A.B)

    @test logs[6] ⊃ LogRecord(Error, "c", module_=A.B.C)
end

end
