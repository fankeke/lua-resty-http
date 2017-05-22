
local http = require "lib.resty.http"


local res, err
local http_c, err = http:new()
if not http_c then
    ngx.log("faild to create ins for http client: ", err)
    return
end

res, err = http_c:connect("127.0.0.1", 8888)
if not res then
    ngx.log("faild to connect: ", err)
    return
end

res, err = http_c:request({
            path = "/redis",
        })

if not res then
    ngx.log(ngx.ERR, "faild to request: ", err)
    return
end
        
ngx.say(res.body)
