export Client, open!, wait, exit_session_on_err, request, set_event_handler!

mutable struct Client
    id::String
    token::String # Authorization
    intents::Int # https://discord.com/developers/docs/topics/gateway#list-of-intents
    conn::VersionedWebSocket
    geteway_url::String
    request_func::Function
    ready::Bool # True after connectiong to geteway
    hb::Heartbeat
    session_id::String # got from Ready
    seq_num::Int # sequence number of the last event received
    event_h::EventHandler

    function Client(id::String, token::String, intents::Int)
        token_field = "Bot $token"
        request_func = create_request_func("$URL/v$API_VERSION/", Dict(
                "Content-Type" => "application/json",
                "Authorization" => token_field,
            )
        )
        event_h = EventHandler()
        set!(event_h, "READY", (client, data) -> client.session_id = data[:session_id]) 
        new(
            id, 
            token_field,
            intents,
            VersionedWebSocket(0, nothing), 
            "", 
            request_func,
            false, 
            Heartbeat(), 
            "", 
            0,
            event_h
         ) 
    end
end

function request(c::Client, method::Symbol, dest::String; payload="", json::Bool=true) 
    return try 
        !isempty(payload) && json && (payload = JSON.json(payload))
        c.request_func(method, dest; body=payload), nothing
    catch e
        nothing, e
    end
end

Base.isopen(c::Client) = c.ready && isopen(c.conn) 
set_event_handler!(c::Client, event_name::String, handler::Function) = set!(c.event_h, event_name, handler)

function open!(c::Client; resume::Bool=false, reconn::Bool=false)
    c.ready || ErrorException("connection with the gateway has already been established")
    if isempty(c.geteway_url)
        c.geteway_url, err = get_gateway_url()
        isnothing(err) || return err
        @info "Received the geteway url."
    end

    if reconn || !isopen(c.conn) 
        @info "Establishing a WebSocket connection..." geteway = c.geteway_url

        err = open!(c.conn, c.geteway_url)
        isnothing(err) || return err
        reconn && version_update!(c.conn)

        data, err = read_json(c.conn.io) 
        isnothing(err) || return err
        GOPCODES(data[:op]) == HELLO || return ErrorException("on getting unexpected opcode: $(data[:op])")
        @info "HELLO opcode was received."
        set_interval!(c.hb, data[:d][:heartbeat_interval])
    end

    err = if resume && !isempty(c.session_id)
        @info "Attempting to resume the lost session..."
        err = resume_conn(c)
        isnothing(err) && @info begin 
            session_id = c.session_id
            seq_num = c.seq_num
            "Connection was resumed successfully."
        end
        err
    else
        @info "Attempting to authorize with a token..." 
        hello(c)
    end
    isnothing(err) || return err
    c.ready = true
    @async event_listener!(c)
    @async heartbeat_loop!(c)        
    nothing
end

function close!(c::Client) 
    c.ready = false
    isopen(c.conn) && close!(c.conn)
end

const RECONNECT_WAIT_TIME = 30
function Base.wait(c::Client)
    @info "Started waiting on socket connection..."
    while isopen(c)
        wait(c.conn) 
        sleep(RECONNECT_WAIT_TIME)
    end 
    @info "Stopped waiting." client = c
end

function exit_session_on_err(c::Client, err) 
    isnothing(err) && return
    close!(c)
    @error err client = c
    # exit(1)
end

function event_listener!(c::Client)
    socket_v = c.conn.v
    @info "Started listening for new events..."
    try 
        while isopen(c) && socket_v == c.conn.v
            data, err = read_json(c.conn.io) 
            throw_on_err(err)
            err = handle(data[:op])(c, data)
            isnothing(err) || @error err
        end
    catch e
        @error "Error has occured while listening for events." err = e
        @info "Trying to reconnect..."
        exit_session_on_err(c, reconnect!(c))
        @info "Reconnected successfully." socket_version = c.conn.v
    end
    @info "Stopped listening for events..." socket_version = socket_v
end

function heartbeat_loop!(c::Client)
    socket_v = c.conn.v
    @info "Started sending the heartbeat signals every $(c.hb.interval)s..." socket_version = socket_v
    sleep(rand(1:c.hb.interval)) 
    try 
        while isopen(c) && socket_v == c.conn.v
            # Handle a zombie connection
            if is_zombie(c.hb) 
                # TODO: RECONNECT FALLBACK
                throw(ErrorException("on missing a heartbeat-ack message from the geteway"))
            end
            throw_on_err(heartbeat(c))
            update!(c.hb)
            sleep(c.hb.interval)
        end 
    catch e
        @error "Error has occured while sending a heartbeat." err = e
    end
end
