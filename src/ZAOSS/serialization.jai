serialize_to_buffer_string :: (dest: *[..]u8, src: string) {
	len := cast(s32) src.count;
    serialize_to_buffer(dest, *len, size_of(s32)); 
    serialize_to_buffer(dest, src.data, src.count);
}

serialize_to_buffer :: (dest: *[..]u8, src: *void, count: s64) {
    offset := dest.count;
    array_resize(dest, offset + count);
    memcpy(dest.data + offset, src, count);
}

serialize_to_buffer :: (dest: *[..]u8, src: *$T) {
    offset := dest.count;
    array_resize(dest, offset + size_of(T));
    memcpy(dest.data + offset, src, size_of(T));
}

serialize_to_buffer :: (dest: *[..]u8, src: *void, offset: *s64, count: s64) {
    if dest.count <= <<offset + count {
		array_resize(dest, <<offset + count);
	}
    memcpy(dest.data + <<offset, src, count);
}

deserialize_from_buffer :: (dest: *void, src: []u8, offset: *s64, count: s64) {
	memcpy(dest, src.data + <<offset, count);
    <<offset += count;
}

deserialize_from_buffer_string :: (src: []u8, offset: *s64) -> string {
    len : s32;
	deserialize_from_buffer(*len, src, offset, size_of(s32));
    result : string;
    result.count = len;
    result.data = alloc(len);
    memcpy(result.data, src.data + <<offset, len);
    <<offset += len;
    return result;
}