module LogTest
using MicroLogging
function f(x)
    @debug "a LogTest module debug message $x"
    @info  "a LogTest module info message $x"
    @warn  "a LogTest module warning message $x"
    @error "a LogTest module error message $x"
end
end

using MicroLogging
using Compat
using Base.Markdown

@info md"# Simple logging"
@info "Default level is info"
@debug "I am an invisible debug message"

@info """
A big log
message in a
multi line string
"""

@info "Non-strings may be logged as messages:"
@info reshape(1:16, (4,4))

@info md"# Early filtering of logs, for efficiency"

enable_logging(MicroLogging.Info)  # Default level
@debug begin
    error("Should not be executed")
    "This message is never generated"
end

disable_logging(LogTest, MicroLogging.Warn)
@info "Disable generation for all Debug and Info messages in LogTest"
LogTest.f(1)

@info "Enable all levels globally for all modules"
disable_logging(Main, MicroLogging.BelowMinLevel)
LogTest.f(2)


@info md"# Log suppression with `max_log`"
for i=1:20
    if i > 7
        @warn "i=$i out of bounds (set max_log=2)" [max_log=2]
        continue
    end
    @info "The value of (1+i) is $(1+i)"
end


@info md"# Simple progress logging"
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


@info md"# Exception reporting, with backtrace"
try
    1÷0
catch err
    @error err
end

@info md"# Task-based log dispatch using dynamic scoping"
logstream = IOBuffer()
with_logger(SimpleLogger(logstream, interactive_style=false)) do
    @info "Logging redirected"
    LogTest.f(3)
end
@info """
Logs, captured separately in the with_logger() block:
................................
$(strip(String(take!(logstream))))
................................
"""

@info md"# Formatting logs can't crash the application"
@info "The next log line will report an exception:"
@info "1÷0 = $(1÷0)"
@info "... see, we get to the next line without a catch"
