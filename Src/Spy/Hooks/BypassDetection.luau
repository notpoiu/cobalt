local pcall, table_pack, unpack, error
    = pcall, table.pack, unpack, error

--[[
    A simple, effective, and generic detection bypass that should be work on any AC that uses metamethod hooks with sus line info detection.

    Such as the anti-metamethod hook impls in games like **Ink Game** and **Combat Warriors**.

    @param Target The old ref returned by hook functions or the function that can throw an error with line info
    @param ... Variable params
]]
local function BypassDetection(Target: (...any) -> any, ...: any)
    local Response = table_pack(pcall(Target, ...))
    if Response[1] then
        return unpack(Response, 2, Response.n)
    end

    -- This is the key bypass step
    return error(Response[2], 19998)
end

return BypassDetection
