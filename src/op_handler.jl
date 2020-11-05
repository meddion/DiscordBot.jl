@enum GOPCODES begin
    DISPATCH = 0
    HEARTBEAT
    IDENTIFY
    PRES_UPD
    VOICE_STATE_UPD
    RESUME = 6
    RECONNECT
    REQ_GUILD_MEMB
    INVALID_SES
    HELLO
    HEARTBEAT_ACK
end

const CONN_PROPS = Dict{String,String}(
    "\$os"      => string(Sys.KERNEL),
    "\$browser" => "discord-bot.jl",
    "\$device"  => "discord-bot.jl",
)

# TODO: CHANGE IT COMPLETLY
function dispatch!(c::Client, data::Dict{Symbol,Any})
    return try 
        c.seq_num = data[:s]
        handler = get_handler(c.event_h, data[:t])
        handler  === DefaultHandler() && error("no handler found")
        handler(c, data[:d])
        nothing
    catch err
        err_msg = if err isa ErrorException
            err.msg
        else 
            sprint(show, err)
        end
        ErrorException("on handling $(data[:t]): $err_msg")
    end
end

function heartbeat(c::Client, args...)
    _, err = write_json(c.conn.io, Dict{Symbol,Any}(
            :op => Int(HEARTBEAT),
            :d => iszero(c.seq_num) ? "null" : c.seq_num
        )
    )
    err
end

function hello(c::Client, args...)
    _, err = write_json(c.conn.io, Dict{Symbol,Any}(
            :op => Int(IDENTIFY),
            :d => Dict{Symbol,Any}(
                :token => c.token,
                :intents => c.intents, # TODO: SET MEANINGFUL VALUE 
                :properties => CONN_PROPS
            )
        )
    )
    err
end

heartbeat_ack!(c::Client, args...) = (set_ack!(c.hb); nothing)

function resume_conn(c::Client, args...)
    _, err = write_json(c.conn.io, Dict{Symbol,Any}(
            :op => Int(RESUME),
            :d => Dict{Symbol,Any}(
                :token => c.token,
                :session_id => c.session_id,
                :seq => c.seq_num, 
            )
        )
    )
    isnothing(err) || return err
    data, err = read_json(c.conn.io)
    isnothing(err) || return err
    GOPCODES(data[:op]) == INVALID_SES ? ErrorException("on getting invalid session opcode") : nothing
end

function reconnect!(c::Client, args...)
    close!(c) # Do we need to do that?
    return open!(c; resume=true, reconn=true)
end

function invalid_ses!(c::Client, args...)
    c.session_id = ""
    c.seq_num = 0
    ErrorException("on receiving an invalid session signal") 
end

# The map of opcodes Client may recieve & corresponding handlers
const HANDLERS = Dict{GOPCODES,Function}(
    DISPATCH => dispatch!,
    HEARTBEAT => heartbeat,
    RECONNECT => reconnect!,
    HELLO => hello,
    HEARTBEAT_ACK => heartbeat_ack!,
    INVALID_SES => invalid_ses!,
)

handle(op::Int) = HANDLERS[GOPCODES(op)]
    