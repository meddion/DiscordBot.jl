mutable struct EventHandler
    handlers::Dict{String,Function}
end
EventHandler() = EventHandler(Dict{String,Function}())
function set!(eh::EventHandler, event_name::String, handler::Function=DefaultHandler()) 
    eh.handlers[event_name] = handler
end

DefaultHandler(args...) = nothing
get_handler(eh::EventHandler, event_name::String) = get(eh.handlers, event_name, DefaultHandler)