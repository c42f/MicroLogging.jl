
module LogBench

using MicroLogging

@noinline function explicit_test(N, dolog::Bool)
    if dolog
        println("A simple operation $N")
    end
end

@noinline function test_modlogger(N)
    @debug "A simple operation $N"
end


@noinline function test_dynamic_logger(N)
    @debug2 "A simple operation $N"
end

end



using BenchmarkTools
using MicroLogging

bench_explicit_test = @benchmark LogBench.explicit_test(1, false)

bench_modlogger = @benchmark LogBench.test_modlogger(1)

mylog = Logger(MicroLogging.Info, get_logger().handler)
bench_dyn = task_local_storage(:LOGGER, mylog) do
    @benchmark LogBench.test_dynamic_logger(1)
end
#= current_task().result = mylog =#
#= bench_dyn = @benchmark LogBench.test_dynamic_logger(1) =#

display(bench_explicit_test)
println()
display(bench_modlogger)
println()
display(bench_dyn)
