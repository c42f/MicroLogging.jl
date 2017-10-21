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


formatmsg(msg) = string(msg)

function formatmsg(ex_msg::Exception)
    io = IOBuffer()
    bt = catch_backtrace()
    showerror(io, ex_msg, bt; backtrace=!isempty(bt))
    String(take!(io))
end

formatmsg(msg::Tuple) = join(map(formatmsg, msg), "\n")


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
    if     level < Info  return (:cyan,   false, ' ')
    elseif level < Warn  return (:blue,   false, ' ')
    elseif level < Error return (:yellow, true, '~')
    else                 return (:red,    true, '!')
    end
end

function handle_message(logger::InteractiveLogger, level, msg, _module, group,
                        id, file, line; kwargs...)
    handle_message(logger, level, formatmsg(msg), _module, group, id,
                   file, line; kwargs...)
end

function print_log_line(stream, lhs, message, rhs,
                        width, hascolor, padchar, color, emphasize)
    if !isempty(lhs)
        print_with_color(color, stream, lhs, bold=emphasize)
    end
    if emphasize && !hascolor
        print_with_color(color, stream, message, bold=false)
    else
        print(stream, message)
    end
    print(stream, " ")
    padwidth = max(0, width - (termlength(message) + 1 +
                               length(lhs) + length(rhs)))
    # Workaround for ^(::Char, ::Int) bugs in 0.6
    padstr = padwidth == 0 ? "" : padwidth == 1 ? padchar : padchar^padwidth
    if emphasize
        print_with_color(color, stream, padstr, bold=false)
    else
        print(stream, padstr)
    end
    if !isempty(rhs)
        print_with_color(color, stream, rhs, bold=emphasize)
    end
    print(stream, "\n")
end

function handle_message(logger::InteractiveLogger, level, msg::AbstractString,
                        _module, group, id, filepath, line;
                        progress=nothing, once=nothing,
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
    color, bold, padchar = levelstyle(convert(LogLevel, level))
    # Attempt at avoiding the problem of distracting metadata in info log
    # messages - print metadata to the right hand side.
    metastr = " $level $filename:$line"
    emphasize = level >= Warn
    # lhsmeta = level >= Warn ? "$level: " : ""
    msg = rstrip(msg, '\n')
    hascolor = '\e' in msg
    if progress === nothing
        if logger.prev_progress_key !== nothing
            print(logger.stream, "\n")
        end
        logger.prev_progress_key = nothing

        width = displaysize(logger.stream)[2]

        msglines = split(msg, '\n')
        if emphasize
            if length(msglines) <= 1
                print_log_line(logger.stream, "$level: ", msglines[1], metastr,
                               width, hascolor, padchar, color, bold)
                shift!(msglines)
            else
                print_log_line(logger.stream, "$level: ", "", metastr,
                               width, hascolor, padchar, color, bold)
            end
            metastr = " ."
        end
        for line in msglines
            print_log_line(logger.stream, "", line, metastr,
                           width, hascolor, ' ', color, bold)
            metastr = " ."
        end

        for (k,v) in kwargs
            kvmsg = formatmsg(v)
            hascolor = '\e' in kvmsg
            kvlines = split(kvmsg, '\n')
            print_log_line(logger.stream, " ", string(k, " = ", kvlines[1]),
                           metastr, width, hascolor, ' ', color, false)
            for i in 2:length(kvlines)
                print_log_line(logger.stream, "  ", kvlines[i],
                               metastr, width, hascolor, ' ', color, false)
            end
        end
    else
        progress_key = msg
        if logger.prev_progress_key !== nothing && logger.prev_progress_key != progress_key
            print(logger.stream, "\n")
        end
        nbar = max(1, displaysize(logger.stream)[2] - (termlength(msg) + length(metastr)) - 4)
        nfilledbar = round(Int, clamp(progress, 0, 1)*nbar)
        msgbar = string("\r", msg, " [", "-"^nfilledbar, " "^(nbar - nfilledbar), "]")
        print(logger.stream, msgbar)
        print_with_color(color, logger.stream, metastr, bold=bold)
        logger.prev_progress_key = progress_key
    end
end


