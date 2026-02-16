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
    array_resize(dest, offset + size_of(T)); // TODO: we resize the array a lot this way, maybe should have a version that assumes the array already has room?
    memcpy(dest.data + offset, src, size_of(T));
}

serialize_to_buffer :: (dest: *[..]u8, src: *void, offset: *s64, count: s64) {
    if dest.count <= <<offset + count {
		array_resize(dest, <<offset + count);
	}
    memcpy(dest.data + <<offset, src, count);
    <<offset += count;
}

deserialize_from_buffer :: (dest: *void, src: []u8, offset: *s64, count: s64) {
	memcpy(dest, src.data + <<offset, count);
    <<offset += count;
}

deserialize_from_buffer :: (dest: *$T, src: []u8, offset: *s64) {
	memcpy(dest, src.data + <<offset, size_of(T));
    <<offset += size_of(T);
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