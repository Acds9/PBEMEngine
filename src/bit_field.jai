#import "Basic";
#import "Math";

Bit_Field :: struct (N: u32, T: Type = u64) {
    #assert T == u8 || T == u16 || T == u32 || T == u64;
    BITS :: #run type_info(T).runtime_size * 8;
    data: [(N + BITS - 1) / BITS] T;
}

make_bit_field :: ($N: u32, $T: Type = u64, bits: [..]u32) -> Bit_Field(N, T) {
	field: Bit_Field(N, T);
	for bits {
		bit_set(*field, it);
	}
	return field;
}

// Set a bit in the bitfield
bit_set :: inline (field: *Bit_Field($N, $T), bit: u32) {
    assert(bit < N);
    BITS :: size_of(T) * 8;
    word := bit / BITS;
    offset := bit % BITS;
    field.data[word] |= cast,no_check(T) 1 << offset;
}

// Clear a bit in the bitfield (set to 0)
bit_clear :: inline (field: *Bit_Field($N, $T), bit: u32) {
    assert(bit < N);
    BITS :: size_of(T) * 8;
    word := bit / BITS;
    offset := bit % BITS;
    field.data[word] &= ~(cast,no_check(T) 1 << offset);
}

// Returns true if bit == 1
bit_test :: inline (field: *Bit_Field($N, $T), bit: u32) -> bool {
    assert(bit < N);
    BITS :: size_of(T) * 8;
    word := bit / BITS;
    offset := bit % BITS;
    return (field.data[word] & (cast,no_check(T)1 << offset)) != 0;
}

// Check if all bits in 'required' are set in 'field'
bit_contains :: inline (field: *Bit_Field($N, $T), required: *Bit_Field(N, T)) -> bool {
    for i: 0..field.data.count-1 {
        if (field.data[i] & required.data[i]) != required.data[i] {
            return false;
        }
    }
    return true;
}

operator | :: (a: Bit_Field($N, $T), b: Bit_Field(N, T)) -> Bit_Field(N, T) {
    result: Bit_Field(N, T);
    for i: 0..a.data.count-1 {
        result.data[i] = a.data[i] | b.data[i];
    }
    return result;
}

operator & :: (a: Bit_Field($N, $T), b: Bit_Field(N, T)) -> Bit_Field(N, T) {
    result: Bit_Field(N, T);
    for i: 0..a.data.count-1 {
        result.data[i] = a.data[i] & b.data[i];
    }
    return result;
}

operator ~ :: (a: Bit_Field($N, $T)) -> Bit_Field(N, T) {
    result: Bit_Field(N, T);
    for i: 0..a.data.count-1 {
        result.data[i] = ~a.data[i];
    }
    return result;
}

// Check if bit is set with [] operator
operator [] :: inline (field: Bit_Field($N, $T), bit: u32) -> bool {
    return bit_test(field, bit);
}

bit_field_as_u64_array :: inline (field: Bit_Field($N, $T)) -> []u64 {
    return field.data;
}