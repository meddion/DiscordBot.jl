mutable struct Heartbeat
    interval::Int # Heartbeat interval (in sec)
    last_sent::Float64
    last_ack::Float64
end

Heartbeat() = Heartbeat(0, 0.0, 0.0)
set_interval!(h::Heartbeat, msec::Int) = (h.interval = round(Int, msec / 1000))
update!(h::Heartbeat) = (h.last_sent = time())
set_ack!(h::Heartbeat) = (h.last_ack = time())
is_zombie(h::Heartbeat) = h.last_sent > h.last_ack