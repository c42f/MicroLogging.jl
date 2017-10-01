# An simple example of how Memento can be plugged in as a backend to MicroLogging

# ------------------------------------------------------------------------------
module MementoShim

using MicroLogging
using Memento

# Confusingly, this is the thing which goes by the name "logger" in
# MicroLogging terminology.  Here it's just used as a placeholder to dispatch
# to the global Memento logger hierarchy.
immutable LogShim <: AbstractLogger
end

function MicroLogging.handle_message(::LogShim, ml_level, msg, _module, group, id, filepath, line; kwargs...)
    # TODO: Map the `group` keyword (or something equivalent) into the right logger.
    # For now, assume a module-based logger.
    logger = get_logger(_module)

    if     ml_level == MicroLogging.Debug ; level = "debug"
    elseif ml_level == MicroLogging.Info  ; level = "info"
    elseif ml_level == MicroLogging.Warn  ; level = "warn"
    elseif ml_level == MicroLogging.Error ; level = "error"
    end

    # TODO: Capture all the keyword arguments, and other call site metadata
    rec = logger.record(logger.name, level, logger.levels[level], msg)
    @sync log(logger, rec)
end

end


# ------------------------------------------------------------------------------
# A test module containing some logging
module A

using MicroLogging

function foo()
    @debug "message from micrologging"
    @info  "message from micrologging"
    @warn  "message from micrologging"
    @error "message from micrologging"
end

end


# ------------------------------------------------------------------------------
# Log configuration
using MicroLogging
using Memento

# MicroLogging setup - set Memento as backend
global_logger(MementoShim.LogShim())

# Configure Memento
Memento.config("info")
# Do something special for messages coming from module A
A_logger = get_logger(A)
add_handler(A_logger, DefaultHandler(Syslog(:local0, "julia"), DefaultFormatter("{level} {name}: {msg}")))
set_level(A_logger, "warn")


# Now, do the actual logging
@info "Global log message"
A.foo()

