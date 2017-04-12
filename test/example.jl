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

@info ".......... Simple logging .........."
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

@info ".......... Per module logger config .........."

limit_logging(LogTest, MicroLogging.Warn)
@info "Logging at Warn for LogTest module"
LogTest.f(1)

@info "Set all loggers to Debug level"
limit_logging(MicroLogging.Debug)
LogTest.f(2)


@info ".......... Log suppression with `once` and `max_log`: .........."
for i=1:20
    if i > 7
        @error "i=$i out of bounds (set once=true)" once=true
        @warn "i=$i out of bounds (set max_log=2)" max_log=2
        continue
    end
    @info "The value of (1+i) is $(1+i)"
end


@info ".......... Simple progress logging .........."
for i=1:100
    sleep(0.01)
    i%20 != 0 || @warn "foo"
    @info "task1" progress=i/100
end

#@debug "Progress logging also at debug level"
for i=1:100
    sleep(0.01)
    @debug "task2" progress=i/100
end


@info ".......... Redirect logging to a file .........."
logfile = open("log.txt", "w")
with_logger(MicroLogging.LogHandler(logfile, false)) do
    @info "Logging redirected to a file"
    LogTest.f(3)
end
close(logfile)

@info "Now directed back to stderr"


