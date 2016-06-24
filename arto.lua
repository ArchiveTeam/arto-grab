dofile("urlcode.lua")
dofile("table_show.lua")

local url_count = 0
local tries = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')
local item_dir = os.getenv('item_dir')

local downloaded = {}
local addedtolist = {}
local pictures = {}

local bad_artodata = 0

for ignore in io.open("ignore-list", "r"):lines() do
  downloaded[ignore] = true
end

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

picture = function(url)
  for picid in string.gmatch(url, "([0-9]+)") do
    if pictures[picid] == true then
      return true
    end
  end
  return false
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]

  if (downloaded[url] ~= true and addedtolist[url] ~= true) and ((string.match(url, "[^0-9]"..item_value.."[0-9]") and not string.match(url, "[^0-9]"..item_value.."[0-9][0-9]")) or html == 0 or picture(url) == true) then
    addedtolist[url] = true
    return true
  else
    return false
  end
end

wget.callbacks.lookup_host = function(host)
  if host == 'arto.com' or host == 'www.arto.com' then
    return "80.160.88.50"
  end
end

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil

  downloaded[url] = true
  
  local function check(urla)
    local url = string.match(urla, "^([^#]+)")
    if (downloaded[url] ~= true and addedtolist[url] ~= true) and ((string.match(url, "[^0-9]"..item_value.."[0-9]") and not string.match(url, "[^0-9]"..item_value.."[0-9][0-9]")) or picture(url) == true or string.match(url, "^https?://[^/]*arto%.com.+[^a-z]js") or string.match(url, "^https?://[^/]*arto%.com.*/includes/") or string.match(url, "^https?://[^/]*arto%.com.+[^a-z]axd") or string.match(url, "^https?://[^/]*artodata%.com") or string.match(url, "^https?://[^/]*arto%.com/section/user/profile/gallery/viewentry/")) and not (string.match(url, "^https?://[^/]*arto%.com/section/user/login/") or string.match(url, "^https?://[^/]*arto%.com/section/linkshare/") or string.match(url, "^https?://[^/]*arto%.com/section/user/createprofile/") or string.match(url, "^https?://[^/]*arto%.com/section/user/profile/settings/changesettings") or string.match(url, "^https?://[^/]*facebook%.com/")) then
      if string.match(url, "&amp;") then
        table.insert(urls, { url=string.gsub(url, "&amp;", "&") })
        addedtolist[url] = true
        addedtolist[string.gsub(url, "&amp;", "&")] = true
      else
        table.insert(urls, { url=url })
        addedtolist[url] = true
      end
    end
  end

  local function checknewurl(newurl)
    if string.match(newurl, "^https?://") then
      check(newurl)
    elseif string.match(newurl, "^//") then
      check("http:"..newurl)
    elseif string.match(newurl, "^/") then
      check(string.match(url, "^(https?://[^/]+)")..newurl)
    end
  end

  local function checknewshorturl(newurl)
    if string.match(newurl, "^%?") then
      check(string.match(url, "^(https?://[^%?]+)")..newurl)
    elseif not (string.match(newurl, "^https?://") or string.match(newurl, "^/") or string.match(newurl, "^[jJ]ava[sS]cript:") or string.match(newurl, "^[mM]ail[tT]o:") or string.match(newurl, "^%${")) then
      check(string.match(url, "^(https?://.+/)")..newurl)
    end
  end
  
  if (string.match(url, "[^0-9]"..item_value.."[0-9]") and not string.match(url, "[^0-9]"..item_value.."[0-9][0-9]")) or picture(url) == true then
    html = read_file(file)
    for newurl in string.gmatch(html, '([^"]+)') do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "([^']+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, ">([^<]+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "PopWin%('([^']+)") do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, 'PopWin%("([^"]+)') do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, "href='([^']+)'") do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, 'href="([^"]+)"') do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, "[sS]how[gG]allery[iI]mage%(([0-9]+)%)") do
      pictures[newurl] = true
      check("http://arto.com/section/user/profile/gallery/viewentry/?id="..newurl)
    end
    for newurl in string.gmatch(html, "javascript:zoom%(([0-9]+,%s+'[^']+',%s+'[^']+',%s+'[^']+',%s+'[^']+',%s+'[^']+',%s+[0-9]+,%s+[0-9]+)%);") do
      local id = string.match(newurl, "([0-9]+),%s+'[^']+',%s+'[^']+',%s+'[^']+',%s+'[^']+',%s+'[^']+',%s+[0-9]+,%s+[0-9]+")
      local fileid = string.match(newurl, "[0-9]+,%s+'([^']+)',%s+'[^']+',%s+'[^']+',%s+'[^']+',%s+'[^']+',%s+[0-9]+,%s+[0-9]+")
      local newstructure = nil
      if string.match(newurl, "[0-9]+,%s+'[^']+',%s+'([^']+)',%s+'[^']+',%s+'[^']+',%s+'[^']+',%s+[0-9]+,%s+[0-9]+") == "True" then
        newstructure = "1"
      else
        newstructure = "0"
      end
      local copyprotection = nil
      if string.match(newurl, "[0-9]+,%s+'[^']+',%s+'[^']+',%s+'([^']+)',%s+'[^']+',%s+'[^']+',%s+[0-9]+,%s+[0-9]+") == "True" then
        copyprotection = "1"
      else
        copyprotection = "0"
      end
      local updated = string.gsub(string.gsub(string.match(newurl, "[0-9]+,%s+'[^']+',%s+'[^']+',%s+'[^']+',%s+'([^']+)',%s+'[^']+',%s+[0-9]+,%s+[0-9]+"), "%s", "%%20"), ":", "%%3A")
      local deleted = nil
      if string.match(newurl, "[0-9]+,%s+'[^']+',%s+'[^']+',%s+'[^']+',%s+'[^']+',%s+'([^']+)',%s+[0-9]+,%s+[0-9]+") == "True" then
        deleted = "1"
      else
        deleted = "0"
      end
      check(string.match(url, "^(https?://[^/]+)").."/section/user/profile/gallery/picture.aspx?id="..id.."&code="..fileid.."&newStructure="..newstructure.."&copyProtection="..copyprotection.."&deleted="..deleted.."&updated="..updated)
    end
  end

  return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()

  if downloaded[url["url"]] == true then
    return wget.actions.EXIT
  end

  if (status_code >= 200 and status_code <= 399) then
    if string.match(url.url, "https://") then
      local newurl = string.gsub(url.url, "https://", "http://")
      downloaded[newurl] = true
    else
      downloaded[url.url] = true
    end
  end
  
  if status_code >= 500 or
    (status_code >= 401 and status_code ~= 404) or
    status_code == 0 then
    io.stdout:write("Server returned "..http_stat.statcode.." ("..err.."). Sleeping.\n")
    io.stdout:flush()
    os.execute("sleep 1")
    tries = tries + 1
    if tries >= 5 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      if string.match(url["url"], "^https?://[^/]*arto%.com") or bad_artodata >= 5 then
        return wget.actions.ABORT
      elseif string.match(url["url"], "^https?://[^/]*artodata%.com") then
        bad_artodata = bad_artodata + 1
        print(bad_artodata)
        return wget.actions.EXIT
      else
        return wget.actions.EXIT
      end
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end