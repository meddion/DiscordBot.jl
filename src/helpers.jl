function create_request_func(url::String, headers::Dict{String,String})
    return function (method::Symbol, dest::String; body="")
        HTTP.request(method, url * dest; headers=headers, body=body) 
    end 
end

function get_gateway_url()
    return try 
        resp = HTTP.get("$URL/v$API_VERSION/gateway")
        url = get(JSON.parse(String(resp.body)), "url", "")
        isempty(url) && error("failed to decode the message")
        "$url?v=$API_VERSION&encoding=json", nothing
    catch e
        err_msg = "on getting a geteway-url from Discord"
        e isa ErrorException && (err_msg *= ": $(e.msg)")
        nothing, ErrorException(err_msg)
    end
end

throw_on_err(err::Union{Nothing,Any}) = (isnothing(err) || throw(err))

function read_json(io)
    return try
        data = readavailable(io)
        JSON.parse(String(data); dicttype=Dict{Symbol,Any}), nothing
    catch e
        nothing, e
    end
end

function write_json(io, data)
    return try
        write(io, json(data)), nothing
    catch e
        nothing, e
    end 
end