# MicroLogging

[![Build Status](https://travis-ci.org/c42f/MicroLogging.jl.svg?branch=master)](https://travis-ci.org/c42f/MicroLogging.jl)

[![codecov.io](http://codecov.io/github/c42f/MicroLogging.jl/coverage.svg?branch=master)](http://codecov.io/github/c42f/MicroLogging.jl?branch=master)


## Design goals

A prototype for a new logging frontend for `Base`.  This isn't meant to be a
fully featured logging framework, just a simple API which allows an efficient
implementation.  Logging should be unified so that logs from all packages can be
directed to a common handler in a simple and consistent way.

### Minimalism of user-visible API

Logging should be so simple that you reach for `@info` rather than `println()`.

```julia
x = 42
@info "my value is x = $x"
```

but it should be extensible in the backend.


### Efficiency aims - messages you don't see are "free"

* Early-out to avoid formatting when the message will be filtered.  With the
  default of a per-module `Logger`, designed such that invisible messages cost
  only a load, integer compare and branch.
* Ability to eliminate entire levels of verbose messages as dead code at compile
  time (?)

### Custom log formatters and backends

* Module based log level control in a heirarchy for ease of use.
* Log pieces (module, message, file location, custom key/value pairs?) passed to
  backend for custom formatting
* Non-Base logging frameworks should be able to define backends to send logs to:
  stdout/stderr, files, the network, etc.
* The backend should be swappable, such that all packages using the frontend
  logger get logs redirected there.


