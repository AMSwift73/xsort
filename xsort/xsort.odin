/*
 * The xsort package: Sorting methods and algorithms for Odin programmers.
 *
 * Forward (and reverse) sorting on arrays without the use of a custom comparator.
 *
 * Version 1.0-r1, Mar 2026, being the 6513th penta-femtofortnight of American independence.
 */
package xsort

import "base:intrinsics"

// import "core:fmt"
import "core:slice"
import "core:sort"

/*
 * This work is made available under the terms of the MIT license.
 *     Copyright (C) 2026 Alexander Munroe Swift <amswift73@gmail.com>
 * It makes use of the work of Igor van den Hoven; his twinsort code is
 *     Copyright (C) 2014-2022 Igor van den Hoven <ivdhoven@gmail.com>
 *     and made available under the terms of the MIT license.
 *
 * See the file "MIT license" locally, or consult https://opensource.org/license/mit.
 */


insertion_sort_max :: 26
shell_sort_max :: 60 // A minor player, but a player nonetheless
/*
 * These values are adjusted using tests on numeric data (as opposed to arrays of structs), with 
 * data patterns that are partly ordered and/or have short runs of equal values.
 */


/*
 * "I want this numeric array sorted. Pick the algorithm for me." 
 * Given a slice and (optionally) a sort direction, sort that porion of the array included in the 
 * slice. All sort options are considered, stable and unstable.
 * If the ordering of equal elements is important, consider "sort_stable_cmp()" or "gen_sorted_index_stable()".
 * Roughly: Call insertion or shell sort on small datasets. Otherwise, usually call twinsort.
 */
sort :: proc(array: []$T, sort_dir: sort_dir = .ascending)
	where intrinsics.type_is_comparable(T) #no_bounds_check
{
    nmemb := len(array)

	// "Choose insertion sort and do it quickly."
	if (nmemb < insertion_sort_max)
	{
		insertion_sort(array, sort_dir); return
	}
	else if (nmemb < shell_sort_max) // Or shell sort.
	{
		shell_sort(array, sort_dir); return
	}

	// We're too small for radix sort to be an option, or we're not something it can (likely) handle
	if (nmemb < radix_weights[0].min_nmemb) || (size_of(T) > 4) || ((!intrinsics.type_is_integer(T)))
	{
		if ((sort_dir != .ascending) || (nmemb < 16 * 1024 * 1024))
		{
			// Twinsort's the answer most of the time
			twinsort(array, sort_dir); return
		}
		else
		{
			// Quicksort outcompetes on very large arrays, if they are unsuitable for radix sort.
			sort.quick_sort(array); return
		}
	}
	else
	{
		radix_cutoff := -1
		for i in 0 ..< len(radix_weights)
		{
			if (radix_weights[i].type_id == T)
			{
				radix_cutoff = radix_weights[i].min_nmemb
				break
			}
		}
		if ((radix_cutoff > -1) && (nmemb >= radix_cutoff))
		{
			radix_sort_lsd(array, sort_dir); return
		}
		else
		{
			if ((sort_dir != .ascending) || (nmemb < 16 * 1024 * 1024))
			{
				twinsort(array, sort_dir); return
			}
			else
			{
				sort.quick_sort(array); return
			}
		}
	}
}


/*
 * Insertion sort. 
 * Stable. Very fast if array <= ~10-20 elements; very slow if much larger than that.
 * Best on data already partially ordered.
 * Uses almost no disk space when instantiated and essentially no temporary memory when used.
 */
insertion_sort :: proc (array: []$T, sort_dir: sort_dir = .ascending)
	where intrinsics.type_is_comparable(T) #no_bounds_check
{
	swap: T
	for i in 1 ..< len(array) 
	{
		for j := i; j > 0 && array[j-1] > array[j]; j -= 1 
		{
			swap = array[j]
			array[j] = array[j - 1]
			array[j - 1] = swap
		}
	}

	if (sort_dir == .descending)
	{
		slice.reverse(array)
	}
}

/*
 * Shell sort, developed by Donald Shell and using Marcin Ciura's gap sequence.
 *
 * Unstable. Faster than insertion sort in arrays above ~20 elements; slower than more modern 
 * sorts above very roughly 50-500 elements. Relatively strong on highly disordered data.
 * Uses almost no disk space when instantiated and almost no temporary memory when used.
 *
 * Compare and sort elements far apart; draw nearer with each loop until a distance of 1 is reached, 
 * completing the sort.
 */
shell_sort :: proc(array: []$T, sort_dir: sort_dir = .ascending)
	where intrinsics.type_is_comparable(T) #no_bounds_check
{
	/* https://en.wikipedia.org/wiki/Shellsort. See note below re. gap sequences. */
	// Use Marcin Ciura's gap sequence, optionally extended using value.k = 2.25 * value.(k-1)
	shellsort_gaps: []int : 
	{
		// Restore these to increase shell sort speed on large arrays, but decrease it on small ones.
		// 460_444, 204_642, 90_952, 40_423, 17_966, 7985, 3549, 1577,
		701, 301, 132, 57, 23, 10, 4, 1 // If final number is 1, sort will complete.
	}
	i, j: int

	for gap in shellsort_gaps
	{
		for i in gap ..< len(array)
		{
			key := array[i]

			for j = i; (j >= gap) && (array[j - gap] > key); j -= gap
			{
				array[j] = array[j - gap]
			}

			array[j] = key // "if (j != i) do array[j] = key" is slower with numeric primitives
		}
	}

	if (sort_dir == .descending)
	{
		slice.reverse(array)
	}
}


/*
 * Twinsort is a stable, bottom-up merge sort that has some ability to adapt to different data
 * patterns. It was developed and implemented in C by Igor van den Hoven
 * (https://github.com/scandum/twinsort/blob/main/twinsort.h). It was originally ported to Odin, 
 * extended to 8- to 128-bit numeric types and to arrays of structs, and provided with custom 
 * comparator and indexing capabilities by Alexander Swift (-AMS-).
 *
 *   Advantages:
 * Twinsort is moderately fast - faster than C++ std::sort and indeed any quicksort this reviewer 
 * knows of on most (but not all) data patterns in numeric arrays, especially those with >40 and <1m 
 * elements. It is favored by a common pattern: data that is already partly sorted or that has runs 
 * of equal values. For a stable sort of its performance, it is also unusually straightforward to 
 * understand, port, and generalize. Provided with a batched option (index, then sort all at once), 
 *, it holds its own on arrays with elements of any size. When indexed, it is a magnificent choice 
 * for structs of arrays.
 *   Disadvantages:
 * Compared to to the sorting state-of-the-art (inc. evolved timsort, quadsort, modern radix sorts, 
 * etc.) twinsort does least well on extremely large datasets (>~1m elements, where algorithms 
 * written to be particularly adaptive, scalable, and multi-threaded really shine), with near-
 * maximally disordered data, with complex data in large objects, and in memory-constrained 
 * environments (indexing helps a lot with these last two).
 *   Take it all in all, for a wide variety of use-cases, van den Hoven's twinsort is
 *            "Fast enough to respect; plain enough to adopt - and it's stable too."
*/


/*
 * Twinsort, developed by Igor van den Hoven. (https://github.com/scandum)
 * Stable. Competitive with or beats quicksort on numeric data unless array members are in the 
 * millions. Favors relatively small datatypes and partly-sorted data, but remains a decent option 
 * under exactly the opposite conditions.
 *
 * Uses a moderately small amount of disk space when instantiated. Uses half the array size in temp.
 * memory. If large datatypes are a concern, or memory is an issue, see "twinsort_cmp_batch()" (for 
 * arrays of large structs) or gen_sorted_index_twinsort() (for maximum fl)
 */
twinsort :: proc(array: []$T, sort_dir: sort_dir = .ascending)
	where intrinsics.type_is_comparable(T)
{
	// Call twin_swap(), which sorts 2-element blocks of the array (and handles pathological cases). 
 	// Unless this process sorts the whole array, call tail_merge_cmp() to merge the blocks.
    nmemb := len(array)

	if (twin_swap(array) == 0)
	{
		tail_merge(array, 2)
	}

	if (sort_dir == .descending) 
	{
		slice.reverse(array)
	}
}


/*
 * 1. Turn the array into sorted blocks of 2 elements (saves time in tail_merge()).
 * 2. Detect and sort reverse order runs, so 6 5 4 3 2 1 becomes 1 2 3 4 5 6 rather than 5 6 3 4 1 2
 * - Igor van den Hoven -
 */
twin_swap :: proc(array: []$T) -> int #no_bounds_check // #no_bounds_check saves very roughly 15% time
{
    swap: T
	idx, start, end: int
    nmemb := len(array)

	idx = 0
	end = nmemb - 2


	for idx <= end
	{
		if (array[idx] <= array[idx + 1])
		{
			idx += 2
			continue
		}
		start = idx

		idx += 2

		for true
		{
			if (idx > end)
			{
				if (start == 0)
				{
					// Check the last member of the run, if we missed it while advancing two at a time
					if ((nmemb % 2 == 0) || (array[idx - 1] > array[idx]))
					{
						// the entire array was reversed

						end = nmemb - 1

						for start < end
						{
							swap = array[start]
							array[start] = array[end]; 
							array[end] = swap
							start += 1; end -= 1
						}
						return 1
					}
				}
				break
			}

			if (array[idx] > array[idx + 1])
			{
				if (array[idx - 1] > array[idx])
				{
					idx += 2
					continue
				}
				swap = array[idx]
				array[idx] = array[idx + 1]
				array[idx + 1] = swap
			}
			break
		}

		end = idx - 1

		for start < end
		{
			swap = array[start]
			array[start] = array[end]
			array[end] = swap
			start += 1; end -= 1
		}
		end = nmemb - 2

		idx += 2
	}
	return 0
}

/*
 * Bottom up merge sort. It copies the right block to swap, next merges starting at the tail ends 
 * of the two sorted blocks. Can be used stand-alone as a "tailsort".
 * Uses at most number of members * sizeof(member) / 2 swap memory.
 * - Igor van den Hoven -
 */
tail_merge :: proc(array: []$T, block: int) #no_bounds_check
{
    block := block // allow modification
	offset: int
	a, s, c, c_max, d, d_max, e: int
    nmemb := len(array)

	swap, err := make([dynamic]T, nmemb / 2); assert(err == nil)
	defer delete(swap)

	s = 0

	for block < nmemb
	{
		for offset = 0; offset + block < nmemb; offset += block * 2
		{
			a = offset
			e = a + block - 1

			if (array[e] <= array[e + 1])
			{
				continue
			}

			if (offset + block * 2 <= nmemb)
			{
				c_max = s + block
				d_max = a + block * 2
			}
			else
			{
				c_max = s + nmemb - (offset + block)
				d_max = 0 + nmemb
			}

			d = d_max - 1

			for array[e] <= array[d]
			{
				d_max -= 1
				d -= 1
				c_max -= 1
			}

			c = s
			d = a + block

			for c < c_max
			{
				swap[c] = array[d]; c += 1; d += 1
			}
			c -= 1

			d = a + block - 1
			e = d_max - 1

			if (array[a] <= array[a + block])
			{
				array[e] = array[d]; e -= 1; d -= 1

				for c >= s
				{
					for array[d] > swap[c]
					{
						array[e] = array[d]; e -= 1; d -= 1
					}
					array[e] = swap[c]; e -= 1; c -= 1
				}
			}
			else
			{
				array[e] = array[d]; e -= 1; d -= 1

				for d >= a
				{
					for array[d] <= swap[c]
					{
						array[e] = swap[c]; e -= 1; c -= 1
					}
					array[e] = array[d]; e -= 1; d -= 1
				}
				for c >= s
				{
					array[e] = swap[c]; e -= 1; c -= 1
				}
			}
		}
		block *= 2
	}
}




// The number of elements an array needs before it can make effective use of radix sort is extremely 
// dependant both on array data type and data pattern. We expect partially ordered inputs (runs of 
// equal values, sections already sorted), and also are wary of using so heavy an option on a 
// small dataset, and so seldom automatically select radix sort.
type_weight :: struct
{
	type_id: typeid,
	min_nmemb: int
}
radix_weights : []type_weight = 
{
	{ i8, 5000 }, { u8, 5000 }, { byte, 5000 }, { i16, 20000 }, { u16, 50000 }, { i32, -1 }, { u32, -1 },
	{ i64, -1 }, { u64, -1 }, { int, -1 }
}

/*
 * Bottom-to-top (LSD) Radix sort, written by Alexander Swift based primarily on a C++ 
 * implementation by Travis Downs.
 *
 * Suitable for arrays of 8- to 64-bit integers. Relatively fast on large arrays; slows down 
 * dramatically if array datatype is wide (and the additional bits are used by many large numbers), 
 * and is generally outperformed by comparison sorts at small to medium array sizes.
 * Very much better off vs. comparison sorts if data is nearly maximally disordered. When data are 
 * highly ordered (long runs of equal values or many values already in sorted order), radix sort 
 * is worse off, relatively and sometimes even absolutely.
 *
 * Heavyweight. Uses some disk space for each instantiation, and the array size, plus ~6-16 kbyte, 
 * in temporary memory.
 *
 * Speeds (highest to lowest), if data has high variance: i8 > u8 >> i16 > u16 >> i32 >> u32 >> 
 * u64 > i64 (some odd regressions here, esp. u32 vs. i32, and I'm not sure why).
 * 
 * Source material of original at https://github.com/travisdowns/sort-bench, discussed at 
 * https://travisdowns.github.io/blog/2019/05/22/sorting.html.
 * -AMS-
 */
radix_sort_lsd :: proc(array: []$T, sort_dir: sort_dir = .ascending)
	where intrinsics.type_is_integer(T) && intrinsics.type_is_endian_little(T) && (size_of(T) <= 8) #no_bounds_check
{
	array := array
	nmemb := len(array)

	chunk_bits :: 8
	chunks :: int(size_of(T) * 8 / chunk_bits)
	chunk_range : u64 : 1 << chunk_bits // How many numbers can this chunk represent?
	chunk_mask : u64 : chunk_range - 1

	// It is important to avoid excessive type conversions, but we always need enough space.
	when (size_of(T) >= 4) do ArrT :: T
	else                   do ArrT :: i32

	scratch_array_ := make([dynamic]T, nmemb, context.temp_allocator)
	scratch_array := scratch_array_[:]

	// Frequencies (saved for all chunks at once to avoid additional reads of the array)
	freqs := make([dynamic][dynamic]ArrT, chunks, context.temp_allocator)
	for i in 0 ..< chunks
	{
		freqs[i] = make([dynamic]ArrT, chunk_range, context.temp_allocator)
	}

	// Quick-access array of queue locations, digit by digit for a chunk
	offsets := make([dynamic]ArrT, chunk_range, context.temp_allocator)

	// For each chunk and digit within that chunk, sum up frequencies.
	for i in 0 ..< nmemb
	{
		// Usually, we just store the digit. However, signed values need special handling: negative 
		// values go in front, positiive ones after them.
		value := array[i]
		for chunk in 0 ..< chunks
		{
			chunk_freqs := freqs[chunk][:]

			digit := u64(value) & chunk_mask
			when (intrinsics.type_is_unsigned(T))
			{
				chunk_freqs[digit] += 1
			}
			else when (intrinsics.type_is_integer(T))
			{
				if (chunk != chunks - 1)
				{
					chunk_freqs[digit] += 1
				}
				else
				{
					unsigned_digit := (digit + 128) % 256
					chunk_freqs[unsigned_digit] += 1
				}
			}
			value >>= chunk_bits // prepare to consider the next place value
		}
	}

	// For a given chunk, if all the digits in the array are of the same value, then sorting on this 
	// digit is unneeded.
	chunk_all_same_value :: proc(freqs: []ArrT, chunk_range: u64, nmemb: int) -> bool
	{
		for i in 0 ..< chunk_range
		{
			if (freqs[i] != 0) do return (freqs[i] == ArrT(nmemb))
		}
		return true
	}

	// Set up swappable slice pointers
	array_ptrs :: struct
	{
		input:  ^[]T,
		output: ^[]T
	}
	arrays : array_ptrs = { &array, &scratch_array }
	swapped := false

	// For each chunk of the values in the array
	for chunk in 0 ..< chunks
	{
		freqs_chunk := freqs[chunk][:]

		// If all the digits are the same, than we need not sort on them.
		if chunk_all_same_value(freqs_chunk[:], chunk_range, nmemb)
		{
			continue
		}

		shift := u64(chunk) * chunk_bits // Consider the number one place value at a time.

		// Using the frequencies for each digit of this chunk, determine where in the output array 
		// each run will begin.
		
		offset : ArrT = 0
		for digit in 0 ..< chunk_range
		{
			offsets[digit] = offset
			offset += freqs_chunk[digit]
		}

		// Point to the current input and output arrays
		input_array := arrays.input^
		output_array := arrays.output^

		/*
		 * Write values to the ouput array, sorting by this digit using offsets.
		 * (hopefully) Instantiate only the relevant code.
		 * When unsigned, sort normally.
		 * When signed integer, sort normally except on the most significant digit. There, flip the 
		 *   most significant bit (the sign) for the purposes of assigning a sorting offset.
		 */
		when (intrinsics.type_is_unsigned(T))
		{
			for i in 0 ..< nmemb
			{
				value := input_array[i]
				index := (u64(value) >> shift) & chunk_mask
				output_array[offsets[index]] = value
				offsets[index] += 1
			}
		}
		else when (intrinsics.type_is_integer(T))
		{
			if (chunk != chunks - 1)
			{
				for i in 0 ..< nmemb
				{
					value := input_array[i]
					index := (u64(value) >> shift) & chunk_mask
					output_array[offsets[index]] = value
					offsets[index] += 1
				}
			}
			else
			{
				sign_bit_flip_mask :: u64(1) << (size_of(T) * 8 - 1)
				for i in 0 ..< nmemb
				{
					value := input_array[i]
					unsigned_value := u64(value)
					unsigned_value ~= sign_bit_flip_mask
					index := (unsigned_value >> shift) & chunk_mask
					output_array[offsets[index]] = value
					offsets[index] += 1
				}
			}
		}

		// Swap pointers to slices
		if (!swapped) do arrays = { &scratch_array, &array }
		else          do arrays = { &array, &scratch_array }
		swapped = !swapped
	}

	// We have an unpaired write; collect results from the final sort.
	if (swapped)
	{
		copy(array, arrays.input^)
	}

	// Optionally, reverse the output
	if (sort_dir == .descending)
	{
		slice.reverse(array)
	}

	free_all(context.temp_allocator)
}
