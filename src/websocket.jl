mutable struct VersionedWebSocket 
    v::Int
    io::Union{Nothing,OpenTrick.IOWrapper}
end

version_update!(ws::VersionedWebSocket) = (ws.v += 1)
Base.isopen(ws::VersionedWebSocket) = !isnothing(ws.io) && isopen(ws.io)
Base.wait(ws::VersionedWebSocket) = wait(ws.io.cond) 
function open!(ws::VersionedWebSocket, url::String)
    return try 
        ws.io = opentrick(HTTP.WebSockets.open, url) 
        nothing
    catch e
        return e
    end
end
function close!(ws::VersionedWebSocket)
    close(ws.io)
    ws.io = nothing
end
