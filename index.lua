package.path = package.path .. ";" .. ngx.var.document_root .. "/?.lua"

local cjson = require "cjson"
local upload = require "classes.upload"
local template = require "resty.template"

local Upload = upload:new()
local params = Upload:parseMultipart()

-- index
if params == nil or tonumber(params.images) == 0 then
    template.render("views/layout.html", {})
    ngx.exit(0)
end

-- upload
local response = {}
response.images = Upload:upload(params)
ngx.say(cjson.encode(response))



