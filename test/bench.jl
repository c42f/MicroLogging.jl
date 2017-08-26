module LogBench

using MicroLogging

struct TrivialLogger <: AbstractLogger; end

MicroLogging.min_enabled_level(::TrivialLogger) = MicroLogging.Warn
MicroLogging.shouldlog(::TrivialLogger, level, a...) = level >= MicroLogging.Error
MicroLogging.logmsg(::TrivialLogger, a...; kws...) = println(a...)

end


using BenchmarkTools
using MicroLogging

@noinline function simple_println(N, dolog)
    for i=1:N
        if dolog[]
            println("A simple operation $i")
        end
    end
end

@noinline function log_debug_msg(N)
    for i=1:N
        @debug "A simple operation $i"
    end
end

@noinline function log_info_msg(N)
    for i=1:N
        @info "A simple operation $i"
    end
end

@noinline function log_warn_msg(N)
    for i=1:N
        @warn "A simple operation $i"
    end
end

N = 1000

# println(), disabled by a simple branch.
# When disabled this is roughly a best case scenario for early log filtering.
bench_println = @benchmark simple_println($N, Ref(false))

# Benchmarks for the three ways that logs can be disabled using MicroLogging:
# 1) The global level filter
disable_logging(:debug)
bench_global_filter =
with_logger(LogBench.TrivialLogger()) do
    @benchmark log_debug_msg($N)
end

# 2) The LogState level filter
bench_logstate_filter =
with_logger(LogBench.TrivialLogger()) do
    @benchmark log_info_msg($N)
end

# 3) The generic shouldlog() filter
bench_shouldlog_filter =
with_logger(LogBench.TrivialLogger()) do
    @benchmark log_warn_msg($N)
end

# current_task().result = mylog

@info "Baseline print with untaken branch"
display(bench_println)

@info "global filter"
display(bench_global_filter)

@info "logstate filter"
display(bench_logstate_filter)

@info "shouldlog filter"
display(bench_shouldlog_filter)
