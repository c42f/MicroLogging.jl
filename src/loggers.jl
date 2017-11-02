"""
    InteractiveLogger(stream::IO; min_level=Info))

Logger for logging to an interactive terminal, formatting logs in a readable
way.
"""
mutable struct InteractiveLogger <: AbstractLogger
    stream::IO
    default_min_level::LogLevel
    catch_exceptions::Bool
    prev_progress_key
    message_counts::Dict{Any,Int}
    module_limits::Dict{Module,LogLevel}
    blacklisted_ids::Set{Any}
end

function InteractiveLogger(stream::IO; min_level=Info, catch_exceptions=true)
    InteractiveLogger(stream, min_level, catch_exceptions, nothing,
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

catch_exceptions(logger::InteractiveLogger) = logger.catch_exceptions

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
    if     level < Info  return (:blue,   false, ' ', 'D')
    elseif level < Warn  return (:cyan,   false, ' ', 'I')
    elseif level < Error return (:yellow, true,  '~', 'W')
    else                 return (:red,    true,  '*', 'E')
    end
end

function handle_message(logger::InteractiveLogger, level, msg, _module, group,
                        id, file, line; kwargs...)
    # TODO: filter max_log here...
    handle_message(logger, level, formatmsg(msg), _module, group, id,
                   file, line; kwargs...)
end

function handle_message(logger::InteractiveLogger, level, msg::AbstractString,
                        _module, group, id, filepath, line;
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
    display_message(logger, level, msg, _module, group, id, filepath, line; kwargs...)
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
    if !isempty(rhs) || padchar != ' '
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
    end
    print(stream, "\n")
end

function display_message(logger::InteractiveLogger, level, msg::AbstractString,
                         _module, group, id, filepath, line;
                         progress=nothing, once=nothing, kwargs...)
    # TODO: progress throttling?
    # Log printing
    filename = basename(String(filepath))
    color, emphasize, padchar, prefixchar = levelstyle(convert(LogLevel, level))
    # Attempt at avoiding the problem of distracting metadata in info log
    # messages - print metadata to the right hand side.
    metastr = " $level $filename:$line"
    msg = rstrip(msg, '\n')

    # Hack: render markdown to temporary buffer, and munge it to remove
    # trailing newlines, even with confounding color codes.
    buf = IOBuffer()
    dsize = displaysize(logger.stream)
    width = dsize[2]
    Markdown.term(IOContext(buf, :displaysize=>(dsize[1],width-2)), Markdown.parse(msg))
    msg = String(take!(buf))
    msg = replace(msg, r"\n(\e\[[0-9]+m)$", s"\1")
    msg = rstrip(msg)

    hascolor = '\e' in msg
    if progress === nothing
        if logger.prev_progress_key !== nothing
            print(logger.stream, "\n")
        end
        logger.prev_progress_key = nothing

        msglines = split(msg, '\n')
        print_log_line(logger.stream, prefixchar, msglines[1], metastr,
                       width, hascolor, padchar, color, emphasize)
        shift!(msglines)
        metastr = ""
        for line in msglines
            print_log_line(logger.stream, "|", line, metastr,
                           width, hascolor, ' ', color, emphasize)
        end

        for (k,v) in kwargs
            kvmsg = formatmsg(v)
            hascolor = '\e' in kvmsg
            kvlines = split(kvmsg, '\n')
            if length(kvlines) == 1
                print_log_line(logger.stream, "|   ", string(k, " = ", kvlines[1]),
                               metastr, width, hascolor, ' ', color, emphasize)
            else
                print_log_line(logger.stream, "|   ", string(k, " ="),
                               metastr, width, hascolor, ' ', color, emphasize)
                for i in 1:length(kvlines)
                    print_log_line(logger.stream, "|    ", kvlines[i],
                                   metastr, width, hascolor, ' ', color, emphasize)
                end
            end
        end
    else
        progress_key = msg
        if logger.prev_progress_key !== nothing && logger.prev_progress_key != progress_key
            print(logger.stream, "\n")
        end
        nbar = max(1, width - (termlength(msg) + length(prefixchar) + length(metastr)) - 3)
        nfilledbar = round(Int, clamp(progress, 0, 1)*nbar)
        print(logger.stream, "\r")
        print_with_color(color, logger.stream, prefixchar, bold=emphasize)
        msgbar = string(msg, " [", "-"^nfilledbar, " "^(nbar - nfilledbar), "]")
        print(logger.stream, msgbar)
        print_with_color(color, logger.stream, metastr, bold=emphasize)
        logger.prev_progress_key = progress_key
    end
end


