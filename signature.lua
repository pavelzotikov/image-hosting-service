local secret = ""

local function calculate_signature(str)
    return ngx.encode_base64(ngx.hmac_sha1(secret, str))
    :gsub("[+/=]", {["+"] = "-", ["/"] = "_", ["="] = ","})
    :sub(1,12)
end

local uri = ngx.var.request_uri
local path = uri:match("/signature/([^?]+)")

ngx.header["Content-type"] = "text/html"

local domain = "https://covers.fun";

ngx.redirect(domain .. "/images/" .. calculate_signature(path) .. "/" .. path);