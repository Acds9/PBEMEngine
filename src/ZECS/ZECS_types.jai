#import "Basic";
#import "Math";

Bit_Field :: struct (N: u32) {
	data: [(N + 63) / 64] u64;
}

make_bit_field :: ($N: u32, bits: [..]u32) -> Bit_Field(N) {
	field: Bit_Field(N);
	for bits {
		bit_set(*field, it);
	}
	return field;
}

// Set a bit in the bitfield
bit_set :: inline (field: *Bit_Field($N), bit: u32) {
    assert(bit >= 0 && bit < N);
    word := bit / 64;
    offset := bit % 64;
    field.data[word] |= cast,no_check(u64)(1 << offset);
}

// Clear a bit in the bitfield (set to 0)
bit_clear :: inline (field: *Bit_Field($N), bit: u32) {
    assert(bit >= 0 && bit < N);
    word := bit / 64;
    offset := bit % 64;
    field.data[word] &= cast,no_check(u64)~(1 << offset);
}

// Returns true if bit == 1
bit_test :: inline (field: Bit_Field($N), bit: u32) -> bool {
    assert(bit >= 0 && bit < N);
    word := bit / 64;
    offset := bit % 64;
    return (field.data[word] & cast(u64)((1 << offset))) != 0;
}

// Check if all bits in 'required' are set in 'field'
bit_contains :: inline (field: Bit_Field($N), required: Bit_Field(N)) -> bool {
    for i: 0..field.data.count-1 {
        if (field.data[i] & required.data[i]) != required.data[i] {
            return false;
        }
    }
    return true;
}

operator | :: (a: Bit_Field($N), b: Bit_Field(N)) -> Bit_Field(N) {
    result: Bit_Field(N);
    for i: 0..a.data.count-1 {
        result.data[i] = a.data[i] | b.data[i];
    }
    return result;
}

operator & :: (a: Bit_Field($N), b: Bit_Field(N)) -> Bit_Field(N) {
    result: Bit_Field(N);
    for i: 0..a.data.count-1 {
        result.data[i] = a.data[i] & b.data[i];
    }
    return result;
}

operator ~ :: (a: Bit_Field($N)) -> Bit_Field(N) {
    result: Bit_Field(N);
    for i: 0..a.data.count-1 {
        result.data[i] = ~a.data[i];
    }
    return result;
}

// Check if bit is set with [] operator
operator [] :: inline (field: Bit_Field($N), bit: u32) -> bool {
    return bit_test(field, bit);
}

bit_field_as_u64_array :: inline (field: Bit_Field($N)) -> []u64 {
    return field.data;
}


for_expansion :: (field: Bit_Field($N), body: Code, flags: For_Flags) #expand {
    #assert(flags == 0);
    
    for bit: 0..N-1 {

		`it_index := bit;
        `it := bit;
        
		if bit_test(field, it) {
            #insert body;
        }
    }
}
// Usage:
/*
	for_bits(component_mask, (bit) {
		print("Component % is present\n", bit);
	});
*/