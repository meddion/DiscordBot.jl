module Discord

using OpenTrick
using HTTP 
using JSON

const URL = "https://discord.com/api"
const API_VERSION = 8 # Gateway & API version

include("helpers.jl")
include("websocket.jl")
include("heartbeat.jl")
include("event_handler.jl")
include("client.jl")
include("op_handler.jl")

end