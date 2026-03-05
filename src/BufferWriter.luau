--!strict

--// Types
export type BufferWriter = typeof(setmetatable(
	{} :: {
		_buffer: buffer,
		_cursor: number,
		_capacity: number,
	},
	{} :: BufferWriterMeta
))

type BufferWriterMeta = {
	__index: BufferWriterMeta,
	new: (initialCapacity: number?) -> BufferWriter,
	writeInt32: (self: BufferWriter, val: number) -> (),
	writeUInt32: (self: BufferWriter, val: number) -> (),
	writeUInt64: (self: BufferWriter, val: number) -> (),
	writeUInt16: (self: BufferWriter, val: number) -> (),
	writeByte: (self: BufferWriter, val: number) -> (),
	writeBoolean: (self: BufferWriter, val: boolean) -> (),
	writeSingle: (self: BufferWriter, val: number) -> (),
	writeBytes: (self: BufferWriter, buf: buffer) -> (),
	writeString: (self: BufferWriter, str: string) -> (),
	getBuffer: (self: BufferWriter) -> buffer,
}

--// Constructor
local BufferWriter = {} :: BufferWriterMeta
BufferWriter.__index = BufferWriter

function BufferWriter.new(initialCapacity: number?): BufferWriter
	local capacity = initialCapacity or 1024
	return setmetatable({
		_buffer = buffer.create(capacity),
		_cursor = 0,
		_capacity = capacity,
	}, BufferWriter)
end

--// Private Methods
local function ensureCapacity(writer: any, additionalBytes: number)
	local required = writer._cursor + additionalBytes
	if required > writer._capacity then
		local newCapacity = writer._capacity * 2
		while newCapacity < required do
			newCapacity *= 2
		end

		local newBuffer = buffer.create(newCapacity)
		buffer.copy(newBuffer, 0, writer._buffer, 0, writer._cursor)
		writer._buffer = newBuffer
		writer._capacity = newCapacity
	end
end

--// Public Methods
function BufferWriter:writeInt32(val: number)
	ensureCapacity(self, 4)
	buffer.writei32(self._buffer, self._cursor, val)
	self._cursor += 4
end

function BufferWriter:writeUInt32(val: number)
	ensureCapacity(self, 4)
	buffer.writeu32(self._buffer, self._cursor, val)
	self._cursor += 4
end

function BufferWriter:writeUInt16(val: number)
	ensureCapacity(self, 2)
	buffer.writeu16(self._buffer, self._cursor, val)
	self._cursor += 2
end

function BufferWriter:writeUInt64(val: number)
	ensureCapacity(self, 8)

	buffer.writeu32(self._buffer, self._cursor, val)
	buffer.writeu32(self._buffer, self._cursor + 4, 0)
	self._cursor += 8
end

function BufferWriter:writeByte(val: number)
	ensureCapacity(self, 1)
	buffer.writeu8(self._buffer, self._cursor, val)
	self._cursor += 1
end

function BufferWriter:writeBoolean(val: boolean)
	ensureCapacity(self, 1)
	buffer.writeu8(self._buffer, self._cursor, val and 1 or 0)
	self._cursor += 1
end

function BufferWriter:writeSingle(val: number)
	ensureCapacity(self, 4)
	buffer.writef32(self._buffer, self._cursor, val)
	self._cursor += 4
end

function BufferWriter:writeBytes(buf: buffer)
	local len = buffer.len(buf)
	ensureCapacity(self, len)
	buffer.copy(self._buffer, self._cursor, buf, 0, len)
	self._cursor += len
end

function BufferWriter:writeString(str: string)
	local len = #str
	ensureCapacity(self, 2 + len)
	self:writeUInt16(len)
	buffer.writestring(self._buffer, self._cursor, str)
	self._cursor += len
end

function BufferWriter:getBuffer(): buffer
	local finalBuf = buffer.create(self._cursor)
	buffer.copy(finalBuf, 0, self._buffer, 0, self._cursor)
	return finalBuf
end

return BufferWriter
