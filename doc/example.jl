using MicroLogging

@info "# Simple logging"
@info "Default level is info"
@debug "I am an invisible debug message"

x = [1 2;3 4]
@info "Support for key value pairs" x a=1 b="asdf"

try
    1÷0
catch err
    @error "Formatting of exceptions",err
end


@info "# Early filtering of logs, for efficiency"
@debug begin
    error("Should not be executed")
    "This message is never generated"
end
configure_logging(min_level=:debug)
@debug "Logging enabled at debug level and above"
for i=1:10
    @warn "Log suppression iteration $i (max_log=2)" max_log=2
end


@info "# Simple progress logging"
for i=1:100
    sleep(0.01)
    @info "algorithm1" progress=i/100
end


@info "# Task-based log dispatch using dynamic scoping"
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


@info "# Formatting logs can't crash the application"
@info "1÷0 = $(1÷0)"

@error """
       Multiline messages      | 11.1
       are readably justified  | 22.2
       """


@info "# Logging may be completely disabled below a given level, per module"
module LogTest
    using MicroLogging
    function f(x)
        @debug "A LogTest module debug message $x"
        @info  "A LogTest module info message $x"
        @warn  "A LogTest module warning message $x"
        @error "A LogTest module error message $x"
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
