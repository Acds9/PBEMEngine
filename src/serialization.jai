serialize_to_buffer_string :: (buffer: *[..]u8, s: string) {
	len := cast(s32) s.count;
    serialize_to_buffer(buffer, *len, size_of(s32)); 
    serialize_to_buffer(buffer, s.data, s.count);
}

serialize_to_buffer :: (buffer: *[..] u8, data: *void, count: s64) {
    offset := buffer.count;
    array_resize(buffer, offset + count);
    memcpy(buffer.data + offset, data, count);
}

serialize_to_buffer :: (buffer: *[..] u8, value: *$T) {
    offset := buffer.count;
    array_resize(buffer, offset + size_of(T));
    memcpy(buffer.data + offset, value, size_of(T));
}

serialize_to_buffer :: (buffer: *[..] u8, offset: *s64, data: *void, count: s64) {
    if buffer.count <= <<offset + count {
		array_resize(buffer, <<offset + count);
	}
    memcpy(buffer.data + <<offset, data, count);
}

deserialize_from_buffer :: (buffer: *u8, dest: *void, offset: *s64, size: s64) {
	memcpy(dest, buffer + <<offset, size);
    <<offset += size;
}

deserialize_from_buffer :: (buffer: *u8, dest: *void, offset: *s64, $T: Type) {
    deserialize_from_buffer(buffer, dest, offset, size_of(T));
}

deserialize_from_buffer_string :: (buffer: *u8, offset: *s64) -> string {
    len : s32;
	deserialize_from_buffer(buffer, *len, offset, s32);
    result : string;
    result.count = len;
    result.data = alloc(len);
    memcpy(result.data, buffer + <<offset, len);
    <<offset += len;
    return result;
}