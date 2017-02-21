# MicroLogging

[![Build Status](https://travis-ci.org/c42f/MicroLogging.jl.svg?branch=master)](https://travis-ci.org/c42f/MicroLogging.jl)

[![codecov.io](http://codecov.io/github/c42f/MicroLogging.jl/coverage.svg?branch=master)](http://codecov.io/github/c42f/MicroLogging.jl?branch=master)


## Design goals

A prototype for a new logging interface for `Base` in julia-0.7.  The design
goals fit into three rough categories - simplicity, flexibility and efficiency.

Logging should be **simple to use** so that package authors can reach for `info`
rather than `println()`.  We should have:

* A minimum of syntax - ideally just a logger verb and the message in most
  cases.  Context information for log messages (file name, line number, module,
  stack trace, etc.) should be automatically gathered without a syntax burden.
* Freedom in formatting the log message - simple string interpolation,
  `@sprintf` and `fmt()`, etc should all be fine.
* Zero logger setup for simple uses.
* Easy filtering of log messages.
* Clear guidelines about the meaning and appropriate use of standard log levels
  for consistency between packages, along with guiding the appropriate use of
  logging vs stdout.
* To encourage the use of logging over ad-hoc console output, the default
  console log handler should emphasize the *log message*, and metadata should be
  printed in a non-intrusive way.


The API should be **flexibile enough** for advanced users:

* For all packages using the standard logging API, it should be simple to
  intercept, filter and redirect logs in a unified and centrally controlled way.
* Log records are more than a string: loggers typically gather context
  information both lexically (eg, module, file name, line number) and
  dynamically (eg, time, stack trace, thread id).
* Formatting and dispatch of log records should be in the hands of the user if
  they need it. For example, a log handler library may need to write json
  records across the network to a log server.
* It should be possible to log to a user defined log context; automatically
  choosing a context for zero setup logging may not suit all cases.  For
  example, in some cases we may want to use a log context explicitly attached to
  a user-defined data structure.
* Possible extensions
    * User supplied `key=value` pairs for additional log context?
    * Support for user defined log levels ?


The design should allow for an **efficient implementation**, to encourage
the availability of logging in production systems; logs you don't see should be
almost free, and logs you do see should be cheap to produce. The runtime cost
comes in three flavours:

* Cost in the logging library, to determine whether to filter a message.
* Cost in user code, to construct quantities which will only be used in the
  log message.
* Cost in the logging library in collecting context information and
  to dispatch and format log records.



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

Efficiency seems to dictate that the main log filtering decision is done
*before* any logging-specific user code is run. This implies either a logging
macro to insert an early test and branch, or that the message formatting work
is passed as a closure. We'd also like to gather information from lexical
scope, and to look up/create a logger statically with the correct context.

These considerations seem to indicate that a macro be used, which also has the
nice side effect of being visually simple:

```julia
x = 42
@info "my value is x = $x"
```

### Logging context, levels, and filtering

The filtering of any given log message should be so cheap that users feel free
to leave it available rather than commenting it out or otherwise disabling it at
compile time.  In most logging libraries, simple filtering is achieved based on
an ordered **log level** (or severity - debug,info,warning,error, etc) which is
individually controllable per **logger context**.  Messages less severe than the
currently minimum level for the context are filtered out.  This seems simple,
effective and efficient as a first pass filter and there doesn't seem to be a
strong reason to change it.

The appropriate granularity for logger context can be debated, but the python
community seems to have settled on using
[per-module contexts](https://docs.python.org/3/library/logging.html#logger-objects).
`MicroLogging` follows this idea, but uses logging macros to set a per-module
logger up automatically, and log to the current module logger from any unadorned
log statement.

### Configuration

For simple catchall configuration to work, we need some kind of registry of
logger instances for all logging contexts. A standard way to manage and
configure the set of loggers is to arrange them in a hierarchy - here we mirror
the module hierarchy by default.

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

