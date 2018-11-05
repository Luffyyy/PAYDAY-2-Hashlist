local lines = {}
local hashlist = io.open("hashlist", "r+")

if hashlist then
    local hashlist_filter = io.open("hashlist_filtered", "w+")
    for line in hashlist:lines() do
        lines[line] = true
    end
    for line, _ in pairs(lines) do
        hashlist_filter:write(line, "\n")
    end
    hashlist:close()
    hashlist_filter:close()
end