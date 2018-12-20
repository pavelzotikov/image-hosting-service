local class = require 'middleclass'

local Upload = class('Upload')

function Upload:initialize()
    self.lpeg = require "lpeg"
    self.magick = require "magick"

    self.url = require "socket.url"
    self.uuid = require "resty.uuid"
    self.upl = require "resty.upload"
end

function Upload:injectTuples(tbl)
    for _index_0 = 1, #tbl do
        local tuple = tbl[_index_0]
        tbl[tuple[1]] = tuple[2] or true
    end
end

function Upload:unescape(str)
    local u = self.url.unescape
    return (u(str))
end

function Upload:patt()
    local C, R, P, S, Ct, Cg
    do
        local _obj_0 = self.lpeg
        C, R, P, S, Ct, Cg = _obj_0.C, _obj_0.R, _obj_0.P, _obj_0.S, _obj_0.Ct, _obj_0.Cg
    end

    local white = S(" \t") ^ 0
    local token = C((R("az", "AZ", "09") + S("._-")) ^ 1)
    local value = (token + P('"') * C((1 - S('"')) ^ 0) * P('"')) / self.url.unescape
    local param = Ct(white * token * white * P("=") * white * value)
    local patt = (Ct(Cg(token, "type") * (white * P(";") * param) ^ 0))

    return patt
end

function Upload:parseContentDisposition(val)
    local patt = self:patt()

    do
        local out = patt:match(val)
        if out then
            self:injectTuples(out)
        end

        return out
    end
end

function Upload:parseMultipart()

    local out = {}
    local input, err = self.upl:new(8192)

    if not (input) then
        return nil, err
    end

    input:set_timeout(1000)
    local current = {
        content = { }
    }

    while true do
        local t, res
        t, res, err = input:read()
        local _exp_0 = t
        if "body" == _exp_0 then
            table.insert(current.content, res)
        elseif "header" == _exp_0 then
            local name, value = unpack(res)
            if name == "Content-Disposition" then
                do
                    local params = self:parseContentDisposition(value)
                    if params then
                        for _index_0 = 1, #params do
                            local tuple = params[_index_0]
                            current[tuple[1]] = tuple[2]
                        end
                    end
                end
            else
                current[name:lower()] = value
            end
        elseif "part_end" == _exp_0 then
            current.content = table.concat(current.content)
            if current.name then
                if current["content-type"] then
                    out[current.name] = current
                else
                    out[current.name] = current.content
                end
            end
            current = {
                content = { }
            }
        elseif "eof" == _exp_0 then
            break
        else
            return nil, err or "failed to read upload"
        end
    end

    return out
end

function Upload:calculateSicnature(str)
    local secret = ""
    return ngx.encode_base64(ngx.hmac_sha1(secret, str)):gsub("[+/=]", {["+"] = "-", ["/"] = "_", ["="] = ","}):sub(1,12)
end

function Upload:isEmpty(str)
    return str == nil or str == ''
end

function Upload:upload(params)
    local result = {}

    local domain = ngx.var.scheme .. "://" .. ngx.var.host
    local dirPath = ngx.var.document_root

    for index = 0, tonumber(params.images) - 1 do
        local img = assert(self.magick.load_image_from_blob(params["image" .. tostring(index)].content))
        local fileName = self.uuid:generate() .. "." .. img:get_format()
        local filePath = "/images/" .. fileName

        img:write(dirPath .. filePath)

        local data = {}
        data.original = domain .. filePath
        data.thumbnail = domain .. "/images/" .. self:calculateSicnature("128x85" .. "/" .. fileName) .. "/128x85/" .. fileName

        data.size = {}
        data.size['width'] = img:get_width()
        data.size['height'] = img:get_height()

        result[index] = data
    end

    return result
end

return Upload