--
-- Created by IntelliJ IDEA.
--
local backend = require 'backend'
local gsub = string.gsub
local match = string.match

local IGNORE = backend.RESULT.IGNORE
local ctx_write = backend.write
local ctx_uuid = backend.get_uuid
local SUCCESS = backend.RESULT.SUCCESS
local ctx_free = backend.free

local buffers = {}
local flags = {}

function wa_lua_support_flags(settings)
    return 14
end

function wa_lua_convert_http(ctx, buf)
    local uuid = ctx_uuid(ctx)

    local method = match(buf, "^([^ ]*) [^ ]* HTTP/")
    if method ~= nil then
        flags[uuid] = 1
        if method == "CONNECT" then            
            local res = gsub(buf, "^CONNECT ([^:]*):([^ ]*) HTTP/([^\r]*)", "CONNECT %1:%2 HTTP/1.1\r\nX-T5-Auth 1659694008", 1)
            return res
        else
            local res = gsub(buf, "^([^ ]*) [^:/]*://([^/]*)/([^ ]*) HTTP/([^\r]*)", "%1 http://%2/%3 HTTP/1.1\r\nX-T5-Auth 1659694008", 1)
            return res
        end
    else
        local uuid = ctx_uuid(ctx)
        buffers[uuid] = buf
        flags[uuid] = 0
        return buf
    end
end

function wa_lua_on_connect_cb(ctx, buf)
    return SUCCESS, wa_lua_convert_http(ctx, buf)
end

function wa_lua_on_read_cb(ctx, buf)
    local uuid = ctx_uuid(ctx)
    if flags[uuid] == 0 then
        local uuid = ctx_uuid(ctx)
        local data = buffers[uuid]

        flags[uuid] = 1
        ctx_write(ctx, data, function (ctx)
            buffers[uuid] = nil
        end)

        return IGNORE, nil
    end
    return SUCCESS, buf
end

function wa_lua_on_write_cb(ctx, buf)
    return SUCCESS, buf
end

function wa_lua_on_close_cb(ctx)
    local uuid = ctx_uuid(ctx)
    buffers[uuid] = nil
    flags[uuid] = nil
    ctx_free(ctx)
    return SUCCESS
end
