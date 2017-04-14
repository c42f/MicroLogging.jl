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

function levelstyle(level::LogLevel)
    level == Debug && return (:cyan,   false, "- DEBUG")
    level == Info  && return (:blue,   false, "-- INFO")
    level == Warn  && return (:yellow, true , "-- WARN")
    level == Error && return (:red,    true , "- ERROR")
end

function logmsg(logger::SimpleLogger, level, msg; module_=nothing,
                id=nothing, once=false, max_log=-1, location=("",0), progress=nothing, kwargs...)
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
    filename = location[1] === nothing ? "REPL" : basename(location[1])
    if logger.interactive_style
        color, bold, levelstr = levelstyle(level)
        # Attempt at avoiding the problem of distracting metadata in info log
        # messages - print metadata to the right hand side.
        metastr = "[$(module_):$(filename):$(location[2])] $levelstr"
        msg = rstrip(msg, '\n')
        if progress === nothing
            if logger.prev_progress_key !== nothing
                print(logger.stream, "\n")
            end
            logger.prev_progress_key = nothing
            for (i,msgline) in enumerate(split(msg, '\n'))
                # TODO: This API is inconsistent between 0.5 & 0.6 - fix the bold stuff if possible.
                print_with_color(color, logger.stream, msgline)
                if i == 2
                    metastr = "..."
                end
                nspace = max(1, displaysize(logger.stream)[2] - (length(msgline) + length(metastr)))
                print(logger.stream, " "^nspace)
                print_with_color(color, logger.stream, metastr)
                print(logger.stream, "\n")
            end
        else
            progress_key = msg
            if logger.prev_progress_key !== nothing && logger.prev_progress_key != progress_key
                print(logger.stream, "\n")
            end
            nbar = max(1, displaysize(logger.stream)[2] - (length(msg) + length(metastr)) - 4)
            nfilledbar = round(Int, clamp(progress, 0, 1)*nbar)
            fullmsg = string("\r", msg, " [", "-"^nfilledbar, " "^(nbar - nfilledbar), "] ", metastr)
            print_with_color(color, logger.stream, fullmsg)
            logger.prev_progress_key = progress_key
        end
    else
        print(logger.stream, "$level [$(module_):$(filename):$(location[2])]: $msg")
        if !endswith(msg, '\n')
            print(logger.stream, '\n')
        end
    end
end


