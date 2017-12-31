local endpoint_url    = os.getenv("APILITYIO_URL") .. "/badip/"
local cache_ttl     = tonumber(os.getenv("APILITYIO_LOCAL_CACHE_TTL"))
local x_auth_token = os.getenv("APILITYIO_API_KEY")
local all_headers = {}

if x_auth_token then
    all_headers = { ["X-Auth-Token"] = x_auth_token }
end

local ip = ngx.var.remote_addr
local ip_cache = ngx.shared.ip_cache

-- check first the local blacklist
ngx.log(ngx.DEBUG, "ip_cache: Look up in local cache "..ip)
local cache_result = ip_cache:get(ip)
if cache_result then
  ngx.log(ngx.DEBUG, "ip_cache: found result in local cache for "..ip.." -> "..cache_result)
  if cache_result == 200 then
    ngx.log(ngx.DEBUG, "ip_cache: (local cache) "..ip.." is blacklisted")
    return ngx.exit(ngx.HTTP_FORBIDDEN)
  else
    ngx.log(ngx.DEBUG, "ip_cache: (local cache) "..ip.." is whitelisted")
    return
  end
else
  ngx.log(ngx.DEBUG, "ip_cache: not found in local cache "..ip)
end

-- Nothing in local cache, go and do a roundtrip to apility.io API
local http = require "resty.http"
local httpc = http.new()
      local res, err = httpc:request_uri(endpoint_url .. ip,  {
        method = "GET",
        ssl_verify = false,
        headers = all_headers
      })

-- Something went wrong...
if not res then
  ngx.say("failed to request: ", err)
  return
end

local status = res.status

ip_cache:set(ip, status, cache_ttl)

if res.status == 404 then
  ngx.log(ngx.DEBUG, "blacklist: lookup returns nothing "..ip..":"..res.status)
  return
end

if res.status == 200 then
  ngx.log(ngx.DEBUG, "whitelist: lookup returns something "..ip..":"..res.status)
  return ngx.exit(ngx.HTTP_FORBIDDEN)
end

if res.status == 409 then
  ngx.log(ngx.DEBUG, "whitelist: lookup run out of quota "..ip..":"..res.status)
  return ngx.exit(ngx.HTTP_FORBIDDEN)
end

-- You should never be here...
ngx.log(ngx.ERR, "ip_cache: "..ip.." something went wrong...")
return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
