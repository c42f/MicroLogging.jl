
abstract type SimpleLogFilter end

# Simple filters don't affect early filtering by default
min_enabled_level(f::SimpleLogFilter) = nothing
shouldlog(f::SimpleLogFilter, args...; kwargs...) = true
catch_exceptions(f::SimpleLogFilter) = nothing

# Simple filters pass message directly through to sink by default, but they can
# modify the message by overriding this function.
handle_message(f::SimpleLogFilter, sink, args...; kwargs...) =
    handle_message(sink, args...; kwargs...)

struct FilteringLogger{P<:AbstractLogger,F<:SimpleLogFilter} <: AbstractLogger
    parent::P
    filter::F
end

shouldlog(f::FilteringLogger, args...) = shouldlog(f.filter, args...) && shouldlog(f.parent, args...)
catch_exceptions(f::FilteringLogger) = something(catch_exceptions(f.filter), catch_exceptions(f.parent))

min_enabled_level(f::FilteringLogger) = something(min_enabled_level(f.filter), min_enabled_level(f.parent))

function handle_message(f::FilteringLogger, args...; kwargs...)
    if !shouldlog(f.filter, args...; kwargs...)
        return
    end
    handle_message(f.filter, f.parent, args...; kwargs...)
end


struct ComposedLogFilter{F,G} <: SimpleLogFilter
    filter1::F
    filter2::G
end

Base.:∘(f1::SimpleLogFilter, f2::SimpleLogFilter) = ComposedLogFilter(f1, f2)

FilteringLogger(parent::AbstractLogger, f::ComposedLogFilter) =
    FilteringLogger(FilteringLogger(parent, f.filter2), f.filter1)

#-------------------------------------------------------------------------------

struct LogLevelFilter <: SimpleLogFilter
    default_min_level::LogLevel
    module_limits::Dict{Module,LogLevel}
end

function LogLevelFilter(min_level=Info, limits::Pair...)
    LogLevelFilter(min_level, Dict{Module,LogLevel}(limits...))
end

function min_enabled_level(f::LogLevelFilter)
    min_level = f.default_min_level
    for (_,level) ∈ f.module_limits
        if level < min_level
            min_level = level
        end
    end
    min_level
end

shouldlog(f::LogLevelFilter, level, _module, group, id) =
    !(level < get(f.module_limits, _module, f.default_min_level))

shouldlog(f::LogLevelFilter, args...; kwargs...) = true


"""
    MaxlogFilter()

Filter messages from log statements with a `maxlog=N` key value pair, which
occur more than `N` times.
"""
struct MaxlogFilter <: SimpleLogFilter
    message_limits::Dict{Any,Int}
end

shouldlog(f::MaxlogFilter, level, _module, group, id) = get(f.message_limits, id, 1) > 0

function shouldlog(f::MaxlogFilter, args...; maxlog=nothing, kwargs...)
    if maxlog === nothing || !(maxlog isa Integer)
        return true
    end
    remaining = get!(f.message_limits, id, maxlog)
    f.message_limits[id] = remaining - 1
    remaining > 0
end

struct CatchLogErrors <: SimpleLogFilter
    catch_exceptions::Bool
end

catch_exceptions(f::CatchLogErrors) = f.catch_exceptions

# TODO: Sticky filter

#-------------------------------------------------------------------------------
function filterlogs(func, sf::SimpleLogFilter)
    parent = current_logger()
    logger = FilteringLogger(parent, sf)
    with_logger(func, logger)
    # TODO: For sticky filter, make `with_logger` `attach` and `detach` the
    # loggers?
    #
    # replace_logger(logger)
end

# Prototypes

#=
struct MaxlogFilter{ParentLogger<:AbstractLogger} <: AbstractLogger
    parent::ParentLogger
    message_limits::Dict{Any,Int}
end

MaxlogFilter(parent<:AbstractLogger) = MaxlogFilter(parent, Dict{Any,Int}())

shouldlog(f::MaxlogFilter, level, _module, group, id) =
    get(f.message_limits, id, 1) > 0 && shouldlog(f.parent)

min_enabled_level(f::MaxlogFilter) = f.parent.min_level

function handle_message(f::MaxlogFilter, args...; maxlog=nothing, kwargs...)
    if maxlog !== nothing && maxlog isa Integer
        remaining = get!(logger.message_limits, id, maxlog)
        logger.message_limits[id] = remaining - 1
        remaining > 0 || return
    end

    handle_message(f.parent, args...; kwargs...)
end
=#

