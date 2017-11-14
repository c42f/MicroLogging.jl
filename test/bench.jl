module LogBench

using MicroLogging

struct TrivialLogger <: AbstractLogger; end

MicroLogging.min_enabled_level(::TrivialLogger) = MicroLogging.Warn
MicroLogging.shouldlog(::TrivialLogger, level, a...) = level >= MicroLogging.Error
MicroLogging.handle_message(::TrivialLogger, a...; kws...) = println(a...)

end


using BenchmarkTools
using MicroLogging

# Here's various loops which would be tight if they didn't have logging
# statements inside.  The benchmarks measure the impact of filtering in various
# ways.

@noinline function simple_println(N, dolog)
    s = 0.0
    for i=1:N
        if dolog
            println("A simple operation i=$i")
        end
        s += 0.3
    end
    s
end

@noinline function simple_println_ref(N, dolog)
    s = 0.0
    for i=1:N
        if dolog[]
            println("A simple operation i=$i")
        end
        s += 0.3
    end
    s
end

@noinline function log_debug_msgs(N)
    s = 0.0
    for i=1:N
        @debug "A simple operation" i
        s += 0.3
    end
    s
end

@noinline function log_info_msgs(N)
    s = 0.0
    for i=1:N
        @info "A simple operation" i
        s += 0.3
    end
    s
end

@noinline function log_warn_msgs(N)
    s = 0.0
    for i=1:N
        @warn "A simple operation" i
        s += 0.3
    end
    s
end

N = 1000


#-------------------------------------------------------------------------------
# The benchmarks compare the efficiency of early log filtering in the logging
# macros to the best case hand coded scenario: a boolean value guarding a call
# to println().
#
# In simple_println() the compiler knows the test is a loop invariant and might
# hoist it out entirely.
bench_println = @benchmark simple_println($N, false)

# In simple_println_ref(), the compiler can't hoist the load out of the loop.
# If the loop is simple enough this can make a huge difference.
bench_println_ref = @benchmark simple_println_ref($N, Ref(false))


#-------------------------------------------------------------------------------
# Benchmarks for the three ways that logs can be disabled using MicroLogging:
# 1) The global level filter
disable_logging(:debug)
bench_global_filter =
with_logger(LogBench.TrivialLogger()) do
    @benchmark log_debug_msgs($N)
end

# 2) The LogState level filter
# This could be a lot faster, but going through the TLS hash map is somewhat
# costly.
bench_logstate_filter =
with_logger(LogBench.TrivialLogger()) do
    @benchmark log_info_msgs($N)
end

# 3) The generic shouldlog() filter
bench_shouldlog_filter =
with_logger(LogBench.TrivialLogger()) do
    @benchmark log_warn_msgs($N)
end

# current_task().result = mylog

@info "Baseline print with untaken branch"
display(bench_println)

@info "Baseline print with untaken branch, loading from a ref"
display(bench_println_ref)

@info "global filter"
display(bench_global_filter)

@info "logstate filter"
display(bench_logstate_filter)

@info "shouldlog filter"
display(bench_shouldlog_filter)
