include(joinpath("..", "src", "Discord.jl"))
using .Discord
using DotEnv

module CamillaBot
using ..Discord
export INTENTS, role_managing    

const INTENTS = 1 << 7 # GUILD_VOICE_STATES
const VC_CHAT_ID = "770724169498230835"
const SERVER_ID = "758975684911300608"
const ROLE_ID_FOR_VC = "773589861683691561"

function role_managing(c::Client, data::Dict{Symbol,Any})
    channel_id = data[:channel_id]
    user_id = data[:member][:user][:id]
    uri = "guilds/$SERVER_ID/members/$user_id/roles/$ROLE_ID_FOR_VC"
    has_role = ROLE_ID_FOR_VC in data[:member][:roles] 
    err = nothing
    if channel_id != VC_CHAT_ID && has_role
        _, err = request(c, :DELETE, uri)
    elseif channel_id == VC_CHAT_ID && !has_role
        _, err = request(c, :PUT, uri)
    end
    isnothing(err) || throw(err)
end
end

using .CamillaBot: INTENTS, role_managing
function main()
    DotEnv.config()

    client = Client(ENV["BOT_ID"], ENV["BOT_TOKEN"], INTENTS)
    set_event_handler!(client, "VOICE_STATE_UPDATE", role_managing)
    exit_session_on_err(client, open!(client))
    wait(client)
end

main()