"""
    InteractiveLogger(stream::IO; min_level=Info))

Logger for logging to an interactive terminal, formatting logs in a readable
way.
"""
mutable struct InteractiveLogger <: AbstractLogger
    stream::IO
    default_min_level::LogLevel
    prev_progress_key
    message_counts::Dict{Any,Int}
    module_limits::Dict{Module,LogLevel}
    blacklisted_ids::Set{Any}
end

function InteractiveLogger(stream::IO; min_level=Info)
    InteractiveLogger(stream, min_level, nothing,
             Dict{Any,Int}(), Dict{Module,LogLevel}(), Set{Any}())
end

function configure_logging(logger::InteractiveLogger, _module=nothing;
                           min_level=Info)
    min_level = parse_level(min_level)
    if _module == nothing
        empty!(logger.module_limits)
        logger.default_min_level = min_level
    else
        # Per-module log limiting
        logger.module_limits[_module] = min_level
    end
    logger
end

function shouldlog(logger::InteractiveLogger, level, _module, group, id)
    if level < get(logger.module_limits, _module, logger.default_min_level)
        return false
    end
    if id in logger.blacklisted_ids
        return false
    end
    return true
end

function min_enabled_level(logger::InteractiveLogger)
    min_level = logger.default_min_level
    for (_,level) ∈ logger.module_limits
        if level < min_level
            min_level = level
        end
    end
    return min_level
end


function formatmsg(logger::InteractiveLogger, io, msg)
    print(io, msg)
end

function formatmsg(logger::InteractiveLogger, io, ex_msg::Exception)
    bt = catch_backtrace()
    showerror(io, ex_msg, bt; backtrace=!isempty(bt))
end

function formatmsg(logger::InteractiveLogger, io, msg::Tuple)
    foreach(msg) do m
        formatmsg(logger, io, m)
        write(io, '\n')
    end
end


# Length of a string as it will appear in the terminal (after ANSI color codes
# are removed)
function termlength(str)
    N = 0
    in_esc = false
    for c in str
        if in_esc
            if c == 'm'
                in_esc = false
            end
        else
            if c == '\e'
                in_esc = true
            else
                N += 1
            end
        end
    end
    return N
end

function levelstyle(level::LogLevel)
    if     level < Info  return (:white,  :cyan,   false)
    elseif level < Warn  return (:white,  :blue,   false)
    elseif level < Error return (:yellow, :yellow, true)
    else                 return (:red,    :red,    true)
    end
end

levelstring(level) = string(level)
function levelstring(level::LogLevel)
    if     level == Debug  return "- DEBUG"
    elseif level == Info   return "-- INFO"
    elseif level == Warn   return "-- WARN"
    elseif level == Error  return "- ERROR"
    else                   return string(level)
    end
end

function handle_message(logger::InteractiveLogger, level, msg, _module, group,
                        id, file, line; kwargs...)
    io = IOBuffer()
    formatmsg(logger, io, msg)
    handle_message(logger, level, String(take!(io)), _module, group, id,
                   file, line; kwargs...)
end

function handle_message(logger::InteractiveLogger, level, msg::AbstractString,
                        _module, group, id, filepath, line;
                        progress=nothing, banner=false, once=nothing,
                        max_log=nothing, kwargs...)
    if max_log !== nothing
        count = get!(logger.message_counts, id, 0)
        count += 1
        logger.message_counts[id] = count
        if count > max_log
            push!(logger.blacklisted_ids, id)
            return
        end
    end
    # TODO: progress throttling?
    # Log printing
    filename = basename(String(filepath))
    msgcolor, metacolor, bold = levelstyle(convert(LogLevel, level))
    levelstr = levelstring(level)
    # Attempt at avoiding the problem of distracting metadata in info log
    # messages - print metadata to the right hand side.
    metastr = "$filename:$line $levelstr"
    lhsmeta = level >= Warn ? "$level: " : ""
    msg = rstrip(msg, '\n')
    if progress === nothing
        if logger.prev_progress_key !== nothing
            print(logger.stream, "\n")
        end
        logger.prev_progress_key = nothing
        msglines = split(msg, '\n')
        color_lines = 1:length(msglines)
        for (k,v) in kwargs
            vallines = split(string(v), '\n')
            push!(msglines, string("  ", k, " = ", vallines[1]))
            for i in 2:length(vallines)
                push!(msglines, "    "*vallines[i])
            end
        end
        ncols = displaysize(logger.stream)[2]
        if banner
            unshift!(msglines, "-"^(ncols - length(metastr) - 1))
            color_lines = color_lines .+ 1
        end
        for (i,msgline) in enumerate(msglines)
            # TODO: This API is inconsistent between 0.5 & 0.6 - fix the bold stuff if possible.
            clearlhsmeta = false
            if i in color_lines
                if !isempty(lhsmeta)
                    print_with_color(msgcolor, logger.stream, lhsmeta, bold=true)
                    clearlhsmeta = true
                end
                print_with_color(msgcolor, logger.stream, msgline, bold=false)
            else
                print(logger.stream, msgline)
            end
            if i == 2
                metastr = "..."
            end
            nspace = max(1, ncols - (termlength(msgline) + length(metastr) + length(lhsmeta)))
            print(logger.stream, " "^nspace)
            print_with_color(metacolor, logger.stream, metastr, bold=bold)
            print(logger.stream, "\n")
            if clearlhsmeta
                lhsmeta = ""
            end
        end
    else
        progress_key = msg
        if logger.prev_progress_key !== nothing && logger.prev_progress_key != progress_key
            print(logger.stream, "\n")
        end
        nbar = max(1, displaysize(logger.stream)[2] - (termlength(msg) + length(metastr)) - 4)
        nfilledbar = round(Int, clamp(progress, 0, 1)*nbar)
        msgbar = string("\r", msg, " [", "-"^nfilledbar, " "^(nbar - nfilledbar), "] ")
        print(logger.stream, msgbar)
        print_with_color(metacolor, logger.stream, metastr, bold=bold)
        logger.prev_progress_key = progress_key
    end
end


