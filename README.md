# MicroLogging

[![Build Status](https://travis-ci.org/c42f/MicroLogging.jl.svg?branch=master)](https://travis-ci.org/c42f/MicroLogging.jl)

[![codecov.io](http://codecov.io/github/c42f/MicroLogging.jl/coverage.svg?branch=master)](http://codecov.io/github/c42f/MicroLogging.jl?branch=master)


## Design goals

A prototype for a new logging API for `Base` in julia-0.7.

### Simplicity

Logging should be simple enough that you can reach for `info` rather than
`println()`.

* Zero logger setup for simple uses.
* Freedom in formatting the log message.  Simple string interpolation,
  `@sprintf` and `fmt()`, etc should all be fine.
* Context information for log messages should be automatically gathered without
  a syntax burden. For example, the file, line number, module, stack trace, etc.
* It should be simple to control the filtering of log messages.
* A clear guideline about the meaning and appropriate use of standard log
  levels.


### Flexibility for advanced users

* For *all* packages using the standard logging API, it should be simple to
  intercept, filter and redirect logs a unified way.
* Log records are more than a string: loggers typically gather context
  information both lexically (eg, module, file name, line number) and
  dynamically (eg, time, stack trace, thread id).
* Formatting and dispatch of log records should be in the hands of the user if
  they need it. For example, a log handler library may need to write json
  records across the network to a log server.
* It should be possible to log in a user defined log context if necessary, as
  automatically choosing a context may not suit all cases.  For example, if the
  module is chosen as the default context, users may want to be more specific.
  Users may also want to have a logger context per data structure rather than
  using the lexical scope, particularly in multithreaded cases.

Possible extensions
* User-defined log levels ?
* User-supplied key-value pairs for additional log context?


### Efficiency - messages you never see should cost almost nothing

The cost of basic log filtering should be so cheap that people are happy to
leave complex debug logging in place, to be turned on if necessary.  Cost
comes in three flavours:

* Cost in user code, to construct quantities which will only be used in the
  log message.
* Cost in the logging library, to determine whether to filter a message.
* Cost in the logging library of collecting context information and
  to dispatch/format log records.



## Quickstart

```julia

using MicroLogging

@info "Default level is info"
@debug "I am an invisible debug message"

module LogTest

using MicroLogging

function f(x)
    @debug "enabled $x"
    @info  "enabled $x"
    @warn  "enabled $x"
    @error "enabled $x"
end

end

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

@info "Redirect logging to a file"
logfile = open("log.txt", "w")
configure_logging(level=MicroLogging.Info,
                  handler=MicroLogging.LogHandler(logfile, false))
@info "Logging redirected to a file"
LogTest.f(3)
close(logfile)
```


## MicroLogging implementation choices

### Logging macros

Efficiency seems to dictate that some portion of log filtering be done *before*
any logging-specific user code is run. This implies either logging macros to
insert an early test and branch, or that the message formatting work is passed
as a closure. We'd also like to gather information from lexical scope, and to
look up the logger statically if possible.

These considerations seem to indicate that a macro be used, which also has the
nice side effect of being visually simple:

```julia
x = 42
@info "my value is x = $x"
```

### Logging context

From some experience with python's logger, a generally desired unit of
**logging context** granularity is the module.  Thus, logger macros should log
to the current module logger by default.


### Configuration

For simple catchall configuration to work, we need some kind of registry of
logger instances for all logging contexts.  A standard way to do this is with a
hierarchy of loggers; each logger handles basic filtering and dispatch of
messages for a given context.

```julia
configure_logging(handler=MyLogHandler())
```

### Efficiency - messages you never see should cost almost nothing

The following should be fast

```julia
@debug begin
    A = #=Long, complex calculation=#
    "det(A) = $(det(A))"
end
```

... FIXME more to write here

