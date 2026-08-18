///|
test "descriptor packing transforms and signatures preserve bit counts" {
  let descriptor = Descriptor::new(1)
  descriptor.data[0] = (1 : Byte)
  assert_eq(descriptor_signature(descriptor).popcount, 1)
  assert_eq(descriptor_rotate_bits(descriptor, 1).data[0], (2 : Byte))
  assert_eq(descriptor_reverse_bits(descriptor).data[0], (128 : Byte))
  assert_eq(descriptor_prefix(descriptor, 1).data[0], (1 : Byte))
  assert_eq(descriptor_concat(descriptor, descriptor).data.length(), 2)
  let bits = descriptor_unpack_bits(
    descriptor_pack_bits([true, false, true]),
    3,
  )
  assert_true(bits[0] && bits[2] && bits[1] is false)
}

///|
test "descriptor batch search reports exact deterministic results" {
  let first = Descriptor::new(1)
  let second = Descriptor::new(1)
  second.data[0] = (255 : Byte)
  let index = DescriptorIndex::build([first, second])
  let rows = descriptor_index_batch_query(index, [first], 1)
  assert_eq(rows.length(), 1)
  assert_eq(rows[0][0].train_idx, 0)
  let report = descriptor_batch_search_report(index, [first], 1)
  assert_true(report.exact)
  assert_eq(report.comparisons, 2)
  assert_true(descriptor_hamming_similarity(first, second) < 0.01)
}
