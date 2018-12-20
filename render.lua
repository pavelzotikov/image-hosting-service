local sig, size, path, ext = ngx.var.sig, ngx.var.size, ngx.var.path, ngx.var.ext

local secret = "" -- signature secret key
local images_dir = ngx.var.document_root .. "/images/" -- where images come from
local cache_dir = ngx.var.document_root .. "/cache/" -- where images are cached

local function return_not_found(msg)
    ngx.status = ngx.HTTP_NOT_FOUND
    ngx.header["Content-type"] = "text/html"
    ngx.say(msg or "404 Not found")
    ngx.exit(0)
end

local function calculate_signature(str)
    return ngx.encode_base64(ngx.hmac_sha1(secret, str))
    :gsub("[+/=]", {["+"] = "-", ["/"] = "_", ["="] = ","})
    :sub(1,12)
end

if calculate_signature(size .. "/" .. path) ~= sig then
    return_not_found("Invalid signature")
end

local source_fname = images_dir .. path

-- make sure the file exists
local file = io.open(source_fname)

if not file then
    return_not_found()
end

file:close()

-- resize the image
local magick = require("magick")

local img = assert(magick.load_image(source_fname))

--
local function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end
local img_formats = {'jpeg', 'jpg', 'gif', 'png'}
--

if has_value(img_formats, img:get_format()) == false then
    ngx.say('Wrong format')
    ngx.exit(0)
end

t = {}
size:gsub("[0-9]+",function(c) table.insert(t,c) end)

img:resize_and_crop(tonumber(t[1]), tonumber(t[2]))
-- img:sharpen(100)
img:set_quality(100)

local dest_fname = cache_dir .. ngx.md5(sig .. "/" .. size .. "/" .. path) .. "." .. ext
img:write(dest_fname)

ngx.exec(ngx.var.request_uri)