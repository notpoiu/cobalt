--[[
    SafePack
    Author: centerepic
]]

local TableProxy = {}

local UNPACK_CHUNK = 7997
local SAFE_LIMIT = 12000

function TableProxy.Pack(...)
    return { n = select("#", ...), ... }
end

function TableProxy.Unpack(Tbl, I, J)
    I = I or 1
    J = J or Tbl.n or #Tbl

    if J - I + 1 > SAFE_LIMIT then
        J = I + SAFE_LIMIT - 1
    end

    if J < I then
        return
    end

    if J - I + 1 <= UNPACK_CHUNK then
        return table.unpack(Tbl, I, J)
    end

    return Tbl[I], TableProxy.Unpack(Tbl, I + 1, J)
end

return TableProxy
