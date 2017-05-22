
local tcp   =ngx.socket.tcp

local upper     = string.upper
local lower     = string.lower
local gmatch    = string.gmatch
local sfind     = string.find
local sub       = string.sub
local concat    = table.concat
local insert    = table.insert

local ddtab     = require "utils.ddlog".ddtab
local dd        = require "utils.ddlog".dd


local _M = {
    _VERSION = "0.01"
}

local mt = {
    __index = _M
}

local HTTP_1_1 = " HTTP/1.1\r\n"


_M.new = function(self)
    local sock, err = tcp()
    if not sock then
        return nil, err
    end

    return setmetatable({sock = sock}, mt)
end    


_M.close = function(self)
    local sock = self.sock
    if not sock then
        return nil, "not initalized"
    end

    self.conf = nil
    return sock:close()
end


_M.set_keepalive = function(self, ...)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:setkeepalive(...)
end


_M.connect = function(self, host, port, conf)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    conf = conf or {}
    conf.host = host
    conf.port = tonumber(port) or 80

    if not conf.scheme then
        if conf.port == 443 then
            conf.scheme = "https"
        else
            conf.scheme = "http"
        end
    end

    self.conf = conf
    return sock:connect(conf.host, conf.port)
end


local parse_headers = function(sock)
    local headers = {}

    repeat
        local line = sock:receive()
        for key, value in gmatch(line, "([%w%-]+)%s*:%s*(.+)") do
            key = lower(key)
            if headers[key] then
                headers[key] = headers[key] .. ", " .. tostring(value)
            else
                headers[key] = tostring(value)
            end
        end

    until sfind(line, "^%s*$")

    return headers, nil
end


local receive_chunked = function(sock)
    local chunks = {}
    repeat 
        local str, err = sock:receive()
        if not str then
            return nil, err
        end

        local length = tonumber(str, 16)
        if not length or length < 1 then
            break
        end

        local str, err = sock:receive(length + 2)
        if not str then
            return nil, err
        end

        insert(chunks, str)
    until false

    sock:receive(2)

    return concat(chunks), nil
end


local receive = function(self, sock)
    local line, err = sock:receive()
    if not line then
        return nil, err 
    end

    local status = tonumber(sub(line, 10, 12))
    local headers, err = parse_headers(sock)
    if not headers then
        return nil, err
    end

    local length = tonumber(headers["content-length"])
    local body

    if length then
        return nil, "not support now"
    elseif headers["transfer-encoding"] == "chunked" then
        local str, err = receive_chunked(sock)
        if not str then
            return nil, err
        end
        body = str
    else
        local str, err = sock:receive()
        if not str then
            return nil, err
        end
        body = str
    end

    if lower(headers["connection"]) == "closed" then
        self:close()
    elseif lower(headers["connection"]) == "keep-alive" then
        self:set_keepalive()
    end

    return {
        status = status,
        headers = headers,
        body = body
    }

end    


local req_gen_header = function(conf, opts)
    opts = opts or {}
    local req = {
        upper(opts.method or "GET"),
        " "
    }

    local path = opts.path or conf.path
    if type(path) ~= "string" then
        path = "/"
    elseif sub(path, 1, 1) ~= "/" then
        path = "/" .. path
    end

    insert(req, path)
    insert(req, HTTP_1_1)

    opts.headers = opts.headers or {}
    if opts.body then
        opts.headers['content-length'] = #opts.body
    end

    if not opts.headers['host'] then
        opts.headers['host'] = conf.host
    end

    if not opts.headers['accept'] then
        opts.headers['accept'] = "*/*"
    end

    for key, values in pairs(opts.headers) do
        if type(values) ~= "table" then
            values = {values}
        end

        key = tostring(key)
        for _, value in pairs(values) do
            insert(req, key .. ": " .. tostring(value) .. "\r\n")
        end

    end

    insert(req, "\r\n")

    local res = concat(req)
    return res

end


_M.request = function(self, opts)
    local sock =self.sock
    if not sock then
        return nil, "not initialized"
    end

    local conf = self.conf
    if not conf then
        return nil, "not connected"
    end

    local header = req_gen_header(conf, opts)
    --ngx.log(ngx.ERR,header)
    local bytes, err = sock:send(header)
    if not bytes then   
        return nil, err
    end
    
    return receive(self, sock)
end
        

return _M




    










