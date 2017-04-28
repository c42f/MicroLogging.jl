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
A big
log
message
in a
multiline
string
"""

@info "Non-strings are converted to strings"
@info reshape(1:16, (4,4))

@info md"# Early filtering of logs per module, for efficiency"

limit_logging(LogTest, MicroLogging.Warn)
@info "Logging at Warn for LogTest module"
LogTest.f(1)

@info "Set all loggers to Debug level"
limit_logging(MicroLogging.Debug)
LogTest.f(2)


@info md"# Log suppression with `once` and `max_log`"
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


@info md"# Redirect logging to an IO stream"
logstream = IOBuffer()
with_logger(SimpleLogger(logstream, interactive_style=false)) do
    @info "Logging redirected"
    LogTest.f(3)
end

@info "Now directed back to stderr"
@info """
Contents of redirected IO stream buffer:
................................
$(strip(String(take!(logstream))))
................................
"""

@info md"# Exception reporting, with backtrace"
try
    1÷0
catch err
    @error err
end

