using MicroLogging
using Compat


@info "Simple logging" banner=true
@info "Default level is info"
@debug "I am an invisible debug message"
@info """
A big log
message in a
multi line string
"""
@info "Non-strings may be logged as messages:"
@info reshape(1:16, (4,4))
try
    1÷0
catch err
    @info "An error logged as the message:"
    @error err
end


@info "Early filtering of logs, for efficiency" banner=true
@debug begin
    error("Should not be executed")
    "This message is never generated"
end
configure_logging(min_level=:debug)
@debug "Logging enabled at debug level and above"
@info "Log suppression with `max_log`" banner=true
for i=1:20
    if i > 7
        @warn "i=$i out of bounds (set max_log=2)" max_log=2
        continue
    end
    @info "The value of (1+i) is $(1+i)"
end


@info "Simple progress logging" banner=true
for i=1:100
    sleep(0.01)
    i%40 != 0 || @warn "foo"
    @info "algorithm1" progress=i/100
end
@debug "Progress logging also at debug (or any) log level"
for i=1:100
    sleep(0.01)
    @debug "algorithm2" progress=i/100
end


@info "Task-based log dispatch using dynamic scoping" banner=true
function some_operation()
    @info "Dispatches to the current task logger, or the global logger"
end
logstream = IOBuffer()
with_logger(SimpleLogger(logstream)) do
    @info "Logging redirected"
    some_operation()
end
@info """
Logs, captured separately in the with_logger() block:
................................
$(strip(String(take!(logstream))))
................................
"""


@info "Formatting logs can't crash the application" banner=true
@info "The next log line will report an exception:"
@info "1÷0 = $(1÷0)"
@info "... and we get to the next line without a catch"


@info "Logging may be completely disabled below a given level, per module" banner=true
module LogTest
    using MicroLogging
    function f(x)
        @debug "a LogTest module debug message $x"
        @info  "a LogTest module info message $x"
        @warn  "a LogTest module warning message $x"
        @error "a LogTest module error message $x"
    end
    module SubModule
        using MicroLogging
        function f()
            @debug "Message from sub module"
            @info  "Message from sub module"
            @warn  "Message from sub module"
            @error "Message from sub module"
        end
    end
end
configure_logging(min_level=:warn)
@warn "Early log filtering to warn level and above"
LogTest.f(1)
LogTest.SubModule.f()
@warn "Early log filtering to info and above (the default)"
configure_logging(min_level=:info)
LogTest.f(2)
