"""
    LogHandler(stream::IO, [interactive_style=isinteractive()])

Simplistic handler for logging to a text stream, with basic per-level color
support.
"""
type LogHandler
    stream::IO
    interactive_style::Bool
    prev_progress_key
    message_counts::Dict{Symbol,Int}
end

function LogHandler(stream::IO, interactive_style=isinteractive())
    LogHandler(stream, interactive_style, nothing, Dict{Symbol,Int}())
end

function levelstyle(level::LogLevel)
    level == Debug && return (:cyan,   false, "- DEBUG")
    level == Info  && return (:blue,   false, "-- INFO")
    level == Warn  && return (:yellow, true , "-- WARN")
    level == Error && return (:red,    true , "- ERROR")
end

function handlelog(handler::LogHandler, level, msg; context=nothing,
                   id=nothing, once=false, max_log=-1, location=("",0), progress=nothing, kwargs...)
    # Additional log filtering
    if once || max_log >= 0
        if once
            max_log = 1
        end
        count = get!(handler.message_counts, id, 0)
        count += 1
        handler.message_counts[id] = count
        if count > max_log
            return
        end
    end
    # Log printing
    filename = location[1] === nothing ? "REPL" : basename(location[1])
    if handler.interactive_style
        color, bold, levelstr = levelstyle(level)
        # Attempt at avoiding the problem of distracting metadata in info log
        # messages - print metadata to the right hand side.
        metastr = "[$(context):$(filename):$(location[2])] $levelstr"
        msg = rstrip(msg, '\n')
        if progress === nothing
            if handler.prev_progress_key !== nothing
                print(handler.stream, "\n")
            end
            handler.prev_progress_key = nothing
            for (i,msgline) in enumerate(split(msg, '\n'))
                # TODO: This API is inconsistent between 0.5 & 0.6 - fix the bold stuff if possible.
                print_with_color(color, handler.stream, msgline)
                if i == 2
                    metastr = "..."
                end
                nspace = max(1, displaysize(handler.stream)[2] - (length(msgline) + length(metastr)))
                print(handler.stream, " "^nspace)
                print_with_color(color, handler.stream, metastr)
                print(handler.stream, "\n")
            end
        else
            progress_key = msg
            if handler.prev_progress_key !== nothing && handler.prev_progress_key != progress_key
                print(handler.stream, "\n")
            end
            nbar = max(1, displaysize(handler.stream)[2] - (length(msg) + length(metastr)) - 4)
            nfilledbar = round(Int, clamp(progress, 0, 1)*nbar)
            fullmsg = string("\r", msg, " [", "-"^nfilledbar, " "^(nbar - nfilledbar), "] ", metastr)
            print_with_color(color, handler.stream, fullmsg)
            handler.prev_progress_key = progress_key
        end
    else
        print(handler.stream, "$level [$(context):$(filename):$(location[2])]: $msg")
        if !endswith(msg, '\n')
            print(handler.stream, '\n')
        end
    end
end


