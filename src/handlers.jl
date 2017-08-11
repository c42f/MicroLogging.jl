"""
    SimpleLogger(stream::IO; min_level=Info, interactive_style=isinteractive())

Simplistic logger for logging to a terminal or noninteractive stream, with
basic per-level color support.
"""
mutable struct SimpleLogger
    stream::IO
    min_level::LogLevel
    interactive_style::Bool
    prev_progress_key
    message_counts::Dict{Symbol,Int}
end

function SimpleLogger(stream::IO; min_level=Info, interactive_style=isinteractive())
    SimpleLogger(stream, min_level, interactive_style, nothing, Dict{Symbol,Int}())
end

function enable_logging(logger::SimpleLogger, level)
    logger.min_level = level
end

function shouldlog(logger::SimpleLogger, level, module_, filepath, line, id, max_log, progress)
    if !(logger.min_level <= level)
        return false
    end
    if max_log !== nothing
        count = get!(logger.message_counts, id, 0)
        count += 1
        logger.message_counts[id] = count
        if count > max_log
            return false
        end
    end
    if progress !== nothing
        # TODO: progress throttling?
    end
    return true
end

function formatmsg(logger::SimpleLogger, io, msg)
    print(io, msg)
end

function formatmsg(logger::SimpleLogger, io, msg::Markdown.MD)
    if logger.interactive_style
        # Hack: render markdown to temporary buffer, and munge it to remove
        # trailing newlines, even with confounding color codes.
        io2 = IOBuffer()
        Markdown.term(io2, msg)
        msg = String(take!(io2))
        msg = replace(msg, r"\n(\e\[[0-9]+m)$", s"\1")
        print(io, msg)
    else
        print(io, msg)
    end
end

function formatmsg(logger::SimpleLogger, io, ex_msg::Exception)
    bt = catch_backtrace()
    showerror(io, ex_msg, bt; backtrace=!isempty(bt))
end

function formatmsg(logger::SimpleLogger, io, msg::Tuple)
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
    level == Debug && return (:cyan,   false, "- DEBUG")
    level == Info  && return (:blue,   false, "-- INFO")
    level == Warn  && return (:yellow, true , "-- WARN")
    level == Error && return (:red,    true , "- ERROR")
end

function print_with_col(color, io, str; bold=false)
    if VERSION < v"0.6.0-pre"
        print_with_color(color, io, str)
    else
        print_with_color(color, io, str, bold=bold)
    end
end

function logmsg(logger::SimpleLogger, level, msg, module_, filepath, line, id; kwargs...)
    io = IOBuffer()
    formatmsg(logger, io, msg)
    logmsg(logger, level, String(take!(io)), module_, filepath, line, id; kwargs...)
end

function logmsg(logger::SimpleLogger, level, msg::AbstractString, module_, filepath, line, id;
                progress=nothing, kwargs...)
    # Log printing
    filename = filepath === nothing ? "REPL" : basename(filepath)
    if logger.interactive_style
        color, bold, levelstr = levelstyle(level)
        # Attempt at avoiding the problem of distracting metadata in info log
        # messages - print metadata to the right hand side.
        metastr = "[$module_:$filename:$line] $levelstr"
        msg = rstrip(msg, '\n')
        if progress === nothing
            if logger.prev_progress_key !== nothing
                print(logger.stream, "\n")
            end
            logger.prev_progress_key = nothing
            msglines = split(msg, '\n')
            for (k,v) in kwargs
                push!(msglines, string("  ", k, " = ", v))
            end
            for (i,msgline) in enumerate(msglines)
                # TODO: This API is inconsistent between 0.5 & 0.6 - fix the bold stuff if possible.
                print(logger.stream, msgline)
                if i == 2
                    metastr = "..."
                end
                nspace = max(1, displaysize(logger.stream)[2] - (termlength(msgline) + length(metastr)))
                print(logger.stream, " "^nspace)
                print_with_col(color, logger.stream, metastr, bold=bold)
                print(logger.stream, "\n")
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
            print_with_col(color, logger.stream, metastr, bold=bold)
            logger.prev_progress_key = progress_key
        end
    else
        print(logger.stream, "$level [$module_:$filename:$line]: $msg")
        if !endswith(msg, '\n')
            print(logger.stream, '\n')
        end
    end
end


