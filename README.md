# MicroLogging

[![Build Status](https://travis-ci.org/c42f/MicroLogging.jl.svg?branch=master)](https://travis-ci.org/c42f/MicroLogging.jl)

[![codecov.io](http://codecov.io/github/c42f/MicroLogging.jl/coverage.svg?branch=master)](http://codecov.io/github/c42f/MicroLogging.jl?branch=master)

## Quickstart

```julia
module LogIt

using MicroLogging

function f(x)
    @debug "enabled $x"
    @info  "enabled $x"
    @warn  "enabled $x"
    @error "enabled $x"
end

end


using MicroLogging

@info "Default level is info"
@debug "I am an invisible debug message"

configure_logging(LogIt, level=MicroLogging.Warn)
@info "Logging at Warn for LogIt module"
LogIt.f(1)

@info "Set all loggers to Debug level"
configure_logging(level=MicroLogging.Debug)
LogIt.f(2)


@info "Redirect logging to a file"
logfile = open("log.txt", "w")
configure_logging(level=MicroLogging.Info,
                  handler=MicroLogging.LogHandler(logfile, false))
@info "Logging redirected to a file"
LogIt.f(3)
close(logfile)
```


## Design goals

A prototype for a new logging frontend for `Base`; perhaps will become
`BaseLogNext` if people like it :-)  Design goals include:

### Minimalism in the user-visible API

Logging should be so simple that you reach for `@info` rather than `println()`:

```julia
x = 42
@info "my value is x = $x"
```

The frontend shouldn't dictate how best to format log messages; if the user
needs `@sprintf`, then so be it.


### Extensible log handlers and simple configuration

Users must be able to intercept logging from all logging contexts in a simple
unified way, and send it to a user-defined log handler:

```julia
configure_logging(handler=MyLogHandler())
```

For this to work, loggers from across the system must be somehow registered.  A
standard way to do this is with a hierarchy of loggers; each logger handles
basic filtering and dispatch of messages for a given context.  From some
experience with python's logger, a generally desired unit of **logging context**
granularity is the module.  Thus, logger macros should log to the current module
logger by default.


### Efficiency - messages you never see should cost almost nothing

There should be an extremely early bailout to avoid formatting messages which
will later be filtered out.  Ideally, the cost of a filtered message would be an
integer load, comparison and predictable branch based on the log level. Thus,
users should feel free to write code such as

```julia
@debug begin
    A = #=Long, complex calculation=#
    "det(A) = $(det(A))"
end
```

knowing that efficiency won't suffer unless they enable `Debug` level logging.


### Design TODOs:

* Do we want custom log levels?
* Should we support arbitrary user supplied key-value pairs as log record data,
  in addition to the message string and parameters extracted from the call site?
* It would be fairly easy to add the ability to eliminate entire levels of
  custom verbose debug messages as dead code at compile time on a per-module
  basis, by putting a minimum level into the Logger type.

