# MicroLogging

[![Build Status](https://travis-ci.org/c42f/MicroLogging.jl.svg?branch=master)](https://travis-ci.org/c42f/MicroLogging.jl)

[![codecov.io](http://codecov.io/github/c42f/MicroLogging.jl/coverage.svg?branch=master)](http://codecov.io/github/c42f/MicroLogging.jl?branch=master)

A prototype for a new logging interface for `Base` in julia-0.7.  For design
discussion see the Julep - https://github.com/JuliaLang/Juleps/pull/30/files


## Quickstart

```julia
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

configure_logging(LogTest, level=MicroLogging.Warn)
@info "Logging at Warn for LogTest module"
LogTest.f(1)

@info "Set all loggers to Debug level"
configure_logging(level=MicroLogging.Debug)
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
configure_logging(level=MicroLogging.Info,
                  handler=MicroLogging.LogHandler(logfile, false))
@info "Logging redirected to a file"
LogTest.f(3)
close(logfile)

configure_logging(handler=MicroLogging.LogHandler(STDOUT,true))
@info "Now directed back to stderr"
```


## MicroLogging implementation choices

### Early filtering

The filtering of log messages should cheap enough that users feel free to leave
them available rather than commenting them out or otherwise disabling them at
compile time. The only way to achieve this is to filter early, before the
entire log message and other log record metadata is fully determined. Thus, we
have the following design challenge:

> Allow early filtering of log records *before* the record is fully constructed.

In most logging libraries, a basic level of filtering is achieved based on an
ordered **log level** which represents a verbosity/severity (debug, info,
warning, error, etc).  Messages more verbose than the currently minimum level
are filtered out.  This seems simple, effective and efficient as a first pass
filter. Naturally, further filtering may also occur based on the log message or
other log record metadata.

*TODO*: can we generalize early filtering without loosing efficiency?


### Logging macros

Efficiency seems to dictate that some filtering decision is done *before* any
logging-specific user code is run. This implies either a logging macro to insert
an early test and branch, or that the log record creation is passed as a
closure. We'd also like to gather information from lexical scope, and to look
up/create the logger for the current module at compile time.

These considerations indicate that a macro be used, which also has the nice side
effect of being visually simple:

```julia
x = 42
@info "my value is x = $x"
```

To achieve early filtering, this example currently expands to something like

```julia
logger = $(get_logger(current_module()))
if shouldlog(logger, MicroLogging.Info)
    handlelog(logger, "my value is x = $x", #=...=#)
end
```

### Logging context

Every log record has various types of context which can be associated with it.
Some types of context include:

* static **lexical context** - based on the location in the code - local
    variables, line number, file, function, module.
* dynamic **caller context** - the current stack trace, and data visible in
    it. Consider, for example, the context which can be passed with the
    femtolisp `with-bindings` construct.
* dynamic **data context** - context created from data structures available at
    log record creation.

Log context can be used in two ways.  First, to dispatch the log record to
appropriate handler *code*.  Second, to enrich the log record with *data* about
the state of the program.

> Where does a log message get sent after it is created?

The python community seems to have settled on using
[per-module contexts](https://docs.python.org/3/library/logging.html#logger-objects).
`MicroLogging` follows this idea, but uses logging macros to set a per-module
logger up automatically, and logs to the current module logger from any
unadorned log statement.

In addition, general data context is supported as a way of finding a log
handler.  For example, using the classic dependency injection approach:

```julia
type MyDataStructure
    logger::Logger
    #...
end
get_logger(ctx::MyDataStructure) = ctx.logger

context = MyDataStructure(#=...=#)

@info context "Message will be redirected to get_logger(context)"
```

> Which metadata is automatically included with the log record?

*TODO*

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

