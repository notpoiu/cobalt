local Codec = {}

-- Network CFrame specials use the same sparse rot_id bytes as rbx-dom/attributes
local CFRAME_SPECIALS: { [number]: { number } } = {
	[0x02] = { 1, 0, 0, 0, 1, 0, 0, 0, 1 },
	[0x03] = { 1, 0, 0, 0, 0, -1, 0, 1, 0 },
	[0x05] = { 1, 0, 0, 0, -1, 0, 0, 0, -1 },
	[0x06] = { 1, 0, 0, 0, 0, 1, 0, -1, 0 },
	[0x07] = { 0, 1, 0, 1, 0, 0, 0, 0, -1 },
	[0x09] = { 0, 0, 1, 1, 0, 0, 0, 1, 0 },
	[0x0A] = { 0, -1, 0, 1, 0, 0, 0, 0, 1 },
	[0x0C] = { 0, 0, -1, 1, 0, 0, 0, -1, 0 },
	[0x0D] = { 0, 1, 0, 0, 0, 1, 1, 0, 0 },
	[0x0E] = { 0, 0, -1, 0, 1, 0, 1, 0, 0 },
	[0x10] = { 0, -1, 0, 0, 0, -1, 1, 0, 0 },
	[0x11] = { 0, 0, 1, 0, -1, 0, 1, 0, 0 },
	[0x14] = { -1, 0, 0, 0, 1, 0, 0, 0, -1 },
	[0x15] = { -1, 0, 0, 0, 0, 1, 0, 1, 0 },
	[0x17] = { -1, 0, 0, 0, -1, 0, 0, 0, 1 },
	[0x18] = { -1, 0, 0, 0, 0, -1, 0, -1, 0 },
	[0x19] = { 0, 1, 0, -1, 0, 0, 0, 0, 1 },
	[0x1B] = { 0, 0, -1, -1, 0, 0, 0, 1, 0 },
	[0x1C] = { 0, -1, 0, -1, 0, 0, 0, 0, -1 },
	[0x1E] = { 0, 0, 1, -1, 0, 0, 0, -1, 0 },
	[0x1F] = { 0, 1, 0, 0, 0, -1, -1, 0, 0 },
	[0x20] = { 0, 0, 1, 0, 1, 0, -1, 0, 0 },
	[0x22] = { 0, -1, 0, 0, 0, 1, -1, 0, 0 },
	[0x23] = { 0, 0, -1, 0, -1, 0, -1, 0, 0 },
}

function Codec.LEB128(data: buffer, offset: number): (number, number)
	local result = 0
	local shift = 0
	for i = offset, offset + 8 do
		local byte = buffer.readu8(data, i)
		result = bit32.bor(result, bit32.lshift(bit32.band(byte, 0x7F), shift))
		shift += 7
		if bit32.band(byte, 0x80) == 0 then
			return result, i + 1
		end
	end
	return result, offset + 9
end

-- Unsigned LEB128 via number arithmetic (safe past 32-bit).
function Codec.LEB128U(data: buffer, offset: number): (number, number)
	local result = 0
	local mult = 1
	for i = offset, offset + 9 do
		local byte = buffer.readu8(data, i)
		result += (byte % 128) * mult
		if byte < 128 then
			return result, i + 1
		end
		mult *= 128
	end
	return result, offset + 10
end

-- Zigzag signed-int decode
function Codec.ZzDec(n: number): number
	if n % 2 == 1 then
		return -(n // 2) - 1
	else
		return n // 2
	end
end

type NullRef = { is_null: true }
type ValidRef = { is_null: false, peer_id: number, instance_id: number }
export type InstanceRef = NullRef | ValidRef

function Codec.ReadInstanceRef(data: buffer, offset: number): (InstanceRef, number)
	local peer_id, next_offset = Codec.LEB128(data, offset)
	if peer_id == 0 then
		return { is_null = true }, next_offset
	end
	local instance_id = buffer.readu32(data, next_offset)
	return {
		is_null = false,
		peer_id = peer_id,
		instance_id = instance_id,
	}, next_offset + 4
end

local function makeCFrame(x: number, y: number, z: number, rot: { number }): CFrame
	return CFrame.new(x, y, z, rot[1], rot[2], rot[3], rot[4], rot[5], rot[6], rot[7], rot[8], rot[9])
end

-- Custom network rotation: 48-bit smallest-three quaternion.
-- Layout: c0:15 | pad:1 | c1:15 | c2:15 | maxIndex:2
-- Components are scaled by 0x3FFF*√2 and packed in XZY order relative to the
-- ascending list of non-omitted axes. maxIndex is which of X,Y,Z,W was dropped.
local ROT_SCALE = 0x3FFF * math.sqrt(2)

local function readBits48(
	b0: number,
	b1: number,
	b2: number,
	b3: number,
	b4: number,
	b5: number,
	start: number,
	len: number
): number
	local bytes = { b0, b1, b2, b3, b4, b5 }
	local v = 0
	for i = 0, len - 1 do
		local bitIndex = start + i
		local byteIndex = bitIndex // 8 + 1
		local bitInByte = bitIndex % 8
		if bit32.band(bytes[byteIndex], bit32.lshift(1, bitInByte)) ~= 0 then
			v += 2 ^ i
		end
	end
	return v
end

local function signExtend15(v: number): number
	if v >= 0x4000 then
		return v - 0x8000
	end
	return v
end

function Codec.ReadCompressedRotation(data: buffer, offset: number): (number, number, number, number, number)
	local b0 = buffer.readu8(data, offset)
	local b1 = buffer.readu8(data, offset + 1)
	local b2 = buffer.readu8(data, offset + 2)
	local b3 = buffer.readu8(data, offset + 3)
	local b4 = buffer.readu8(data, offset + 4)
	local b5 = buffer.readu8(data, offset + 5)

	local c0 = signExtend15(readBits48(b0, b1, b2, b3, b4, b5, 0, 15))
	local c1 = signExtend15(readBits48(b0, b1, b2, b3, b4, b5, 16, 15))
	local c2 = signExtend15(readBits48(b0, b1, b2, b3, b4, b5, 31, 15))
	local maxIndex = readBits48(b0, b1, b2, b3, b4, b5, 46, 2)

	-- Wire order is XZY relative to ascending non-omitted axes → undo to XYZ-order fill
	local ordered = { c0 / ROT_SCALE, c2 / ROT_SCALE, c1 / ROT_SCALE }
	local q = table.create(4)
	local vi = 1
	for i = 0, 3 do
		if i == maxIndex then
			q[i + 1] = 0
		else
			q[i + 1] = ordered[vi]
			vi += 1
		end
	end

	local sumsq = 0
	for i = 1, 4 do
		if i ~= maxIndex + 1 then
			sumsq += q[i] * q[i]
		end
	end
	q[maxIndex + 1] = math.sqrt(math.max(0, 1 - sumsq))

	return q[1], q[2], q[3], q[4], offset + 6
end

-- 0x1A / 0x1B: pos(3×f32) + rot_id(1b) [+ optional 6-byte quat]
function Codec.ReadCFrameV1(data: buffer, offset: number): (CFrame, number)
	local x = buffer.readf32(data, offset)
	local y = buffer.readf32(data, offset + 4)
	local z = buffer.readf32(data, offset + 8)
	offset += 12

	local rid = buffer.readu8(data, offset)
	offset += 1

	if rid == 0 then
		local qx, qy, qz, qw
		qx, qy, qz, qw, offset = Codec.ReadCompressedRotation(data, offset)
		return CFrame.new(x, y, z, qx, qy, qz, qw), offset
	end

	local special = CFRAME_SPECIALS[rid]
	if special then
		return makeCFrame(x, y, z, special), offset
	end
	return CFrame.new(x, y, z), offset
end

-- 0x32 / 0x33: flags(1b); 0=nil; else rot (+ optional 6-byte quat) then pos(3×f32)
function Codec.ReadOptCFrame(data: buffer, offset: number): (CFrame?, number)
	local fb = buffer.readu8(data, offset)
	offset += 1
	if fb == 0 then
		return nil, offset
	end

	local rid = bit32.band(fb, 0x7F)
	local x: number, y: number, z: number
	if rid == 0 then
		local qx, qy, qz, qw
		qx, qy, qz, qw, offset = Codec.ReadCompressedRotation(data, offset)
		x = buffer.readf32(data, offset)
		y = buffer.readf32(data, offset + 4)
		z = buffer.readf32(data, offset + 8)
		return CFrame.new(x, y, z, qx, qy, qz, qw), offset + 12
	end

	local rot = CFRAME_SPECIALS[rid] or { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
	x = buffer.readf32(data, offset)
	y = buffer.readf32(data, offset + 4)
	z = buffer.readf32(data, offset + 8)
	return makeCFrame(x, y, z, rot), offset + 12
end

function Codec.ReadUInt64(data: buffer, offset: number): (number, number)
	local lo = buffer.readu32(data, offset)
	local hi = buffer.readu32(data, offset + 4)
	return lo + hi * 0x100000000, offset + 8
end

return Codec
