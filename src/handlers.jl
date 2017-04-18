"""
    SimpleLogger(stream::IO, [interactive_style=isinteractive()])

Simplistic logger for logging to a terminal or noninteractive stream, with
basic per-level color support.
"""
type SimpleLogger
    stream::IO
    interactive_style::Bool
    prev_progress_key
    message_counts::Dict{Symbol,Int}
end

function SimpleLogger(stream::IO, interactive_style=isinteractive())
    SimpleLogger(stream, interactive_style, nothing, Dict{Symbol,Int}())
end

function logmsg(logger::SimpleLogger, level, msg; kwargs...)
    logmsg(logger, level, string(msg); kwargs...)
end

function logmsg(logger::SimpleLogger, level, msg::Markdown.MD; kwargs...)
    if logger.interactive_style
        # Hack: render markdown to temporary buffer, and munge it to remove
        # trailing newlines, even with confounding color codes.
        io = IOBuffer()
        Markdown.term(io, msg)
        msg = String(take!(io))
        msg = replace(msg, r"\n(\e\[[0-9]+m)$", s"\1")
        logmsg(logger, level, msg; kwargs...)
    else
        logmsg(logger, level, string(msg); kwargs...)
    end
end

function logmsg(logger::SimpleLogger, level, ex_msg::Exception; backtrace=nothing, kwargs...)
    bt = backtrace != nothing ? backtrace : catch_backtrace()
    io = IOBuffer()
    showerror(io, ex_msg, bt; backtrace=(bt!=nothing))
    logmsg(logger, level, String(take!(io)); kwargs...)
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


function logmsg(logger::SimpleLogger, level, msg::AbstractString; module_=nothing,
                id=nothing, once=false, max_log=-1, file_="", line_=0, progress=nothing, kwargs...)
    # Additional log filtering
    if once || max_log >= 0
        if once
            max_log = 1
        end
        count = get!(logger.message_counts, id, 0)
        count += 1
        logger.message_counts[id] = count
        if count > max_log
            return
        end
    end
    # Log printing
    filename = file_ === nothing ? "REPL" : basename(file_)
    if logger.interactive_style
        color, bold, levelstr = levelstyle(level)
        # Attempt at avoiding the problem of distracting metadata in info log
        # messages - print metadata to the right hand side.
        metastr = "[$module_:$filename:$line_] $levelstr"
        msg = rstrip(msg, '\n')
        if progress === nothing
            if logger.prev_progress_key !== nothing
                print(logger.stream, "\n")
            end
            logger.prev_progress_key = nothing
            for (i,msgline) in enumerate(split(msg, '\n'))
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
        print(logger.stream, "$level [$module_:$filename:$line_)]: $msg")
        if !endswith(msg, '\n')
            print(logger.stream, '\n')
        end
    end
end


