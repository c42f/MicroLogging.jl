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

configure_logging(handler=MicroLogging.LogHandler(STDOUT,true))

@info "Default level is info"
@debug "I am an invisible debug message"

configure_logging(LogTest, level=MicroLogging.Warn)
@info "Logging at Warn for LogTest module"
LogTest.f(1)

@info "Set all loggers to Debug level"
configure_logging(level=MicroLogging.Debug)
LogTest.f(2)

@info """
A big
log
message
in a
multiline
string
"""

for i=1:10
    if i > 7
        @warn "i=$i out of bounds"
        continue
    end
    @info "The value of (1+i) is $(1+i)"
end


@info "Basic progress logging"
for i=1:100
    sleep(0.02)
    i%20 != 0 || @warn "foo"
    @info "task1" progress=i/100
end

#@debug "Progress logging also at debug level"
for i=1:100
    sleep(0.02)
    @debug "task2" progress=i/100
end
