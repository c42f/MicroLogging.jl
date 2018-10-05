using MicroLogging

@info "# Logging macros"
@debug "A message for debugging (filtered out by default)"
@info "Information about normal program operation"
@warn "A potential problem was detected"
@error "Something definitely went wrong"
x = [1 2;3 4]
@info "Support for key value pairs" x a=1 b="asdf"

#-------------------------------------------------------------------------------
@info "# Progress logging"
for i=1:100
    sleep(0.01)
    @info "algorithm1" progress=i/100
end

#-------------------------------------------------------------------------------
@info "# Log record filtering"
@debug begin
    error("Should not be executed unless logging at debug level")
    "A message"
end
configure_logging(min_level=:debug)
@debug "Logging enabled at debug level and above"
for i=1:10
    @warn "Log suppression iteration $i (maxlog=2)" maxlog=2
end
module LogTest
    using MicroLogging
    function f()
        @debug "Message from LogTest"
        @info  "Message from LogTest"
        @warn  "Message from LogTest"
        @error "Message from LogTest"
    end
end
LogTest.f()
configure_logging(LogTest, min_level=:error)
@info "Set log filtering to error level for LogTest module"
LogTest.f()

#-------------------------------------------------------------------------------
@info "# Task-based log dispatch using dynamic scoping"
function some_operation()
    @info "Dispatches to the current task logger, or the global logger"
end
logstream = IOBuffer()
with_logger(SimpleLogger(logstream)) do
    @info "Logging redirected"
    some_operation()
end
@info "Logs, captured separately in the with_logger() block" logstring=strip(String(take!(logstream)))

#-------------------------------------------------------------------------------
@info "# Formatting logs can't crash the application"
@info "Blah $(error("An intentional error"))"

configure_logging(min_level=:info)
nothing
