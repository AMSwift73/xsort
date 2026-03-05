 /*
 * The xsort package: Sorting methods and algorithms for Odin programmers.
 *
 * 1. Batched reorder to internal index and sort from index.
 * 2. Separation of sorting of arrays into two parts: 
 *     a) indexing in sorted order and 
 *     b) reordering of arrays by index.
 *
 * Version 1.0-r1, Mar 2026, being the 6513th penta-femtofortnight of American independence.
 * Author: Alexander Swift
 */
package xsort

import "base:intrinsics"
import "core:fmt"


/*
 * This work is made available under the terms of the MIT license.
 *     Copyright (C) 2026 Alexander Munroe Swift <amswift73@gmail.com>
 * It makes use of the work of Igor van den Hoven; his twinsort code is
 *     Copyright (C) 2014-2022 Igor van den Hoven <ivdhoven@gmail.com>
 *     and made available under the terms of the MIT license.
 *
 * See the file "MIT license" locally, or consult https://opensource.org/license/mit.
 */

/*
 * Batched sorting: use a sorting algorithm to reorder an index, and then use the index to reorder 
 * the array.
 * Is always slower on arrays of simple numbers, but starts to deliver when array elements are > ~
 * 52 bytes, starting with longer arrays.
 *
 * Batch sorting, especially when chosen automatically by basic auto-selection sorts, helps to
 * keep large arrays and heavyweight elements from bogging down applications.
 * But batched sorting is only a gateway drug! For more powerful and flexible techniques you will 
 * want to master indexed sorting.
 * -AMS-
 */


/*
 * Batched reindex and sort using insertion sort.
 * Given an array and a comparator, index the array internally, then sort it all at once. Not a 
 * preferred choice unless your array has very few elements, your elements are very large, and your
 * target platform is extremely memory-constrained.
 */
insertion_sort_cmp_batch :: proc(array: []$T, cmp: proc(T, T) -> int) #no_bounds_check 
{
	assert(cmp != nil, "xsort.insertion_sort_cmp_batch(): needs a sort condition")
	nmemb := len(array)

	// Save the desired position of each element. Start at the current position.
	index := make([dynamic]int, nmemb); assert(len(index) == nmemb)
	defer delete(index)
	for i in 0 ..< nmemb do index[i] = i

	// Sort, saving new array positions to indexing array
	for i := 0; i < nmemb; i += 1
	{
		key := index[i]
		j := i

		for (j > 0) && (cmp(array[index[j-1]], array[key]) > 0)
		{
			index[j] = index[j - 1]
			j -= 1
		}
		index[j] = key
	}

	// Using the desired sort indices, reorder the array
	batch_sort_aux(array, index[:])
}


/*
 * Batched reindex and sort using shellsort (unstable: reorders equal values).
 * Given an array and a comparator, index the array internally, then sort it all at once. Suitable 
 * if your array elements are >~ 300 bytes and your array is ~5-200 elements (very roughly).
 */
shell_sort_cmp_batch :: proc(array: []$T, cmp: proc(T, T) -> int) #no_bounds_check
{
	assert(cmp != nil, "xsort.shell_sort_cmp_batch(): needs a sort condition")

	// Use Marcin Ciura's gap sequence, optionally extended using value.k = 2.25 * value.(k-1)
	shellsort_gaps: []int : 
	{
		// 460_444, 204_642, 90_952, 40_423, 17_966, 7985, 3549, 1577, 
		701, 301, 132, 57, 23, 10, 4, 1
	}

	nmemb := len(array)
	i, j, g_idx: int

	// Save the desired position of each element. Start at the current position.
	index := make([dynamic]int, nmemb); assert(len(index) == nmemb)
	defer delete(index)
	for i in 0 ..< nmemb do index[i] = i

	// Sort; decreasing gap with each pass
	for gap in shellsort_gaps
	{
		for i in gap ..< len(index)
		{
			key := index[i]

            for j = i; (j >= gap) && cmp(array[index[j - gap]], array[key]) > 0; j -= gap
            {
                index[j] = index[j - gap]
            }

			if (j != i) do index[j] = key // faster with arrays of structs
		}
	}

	// Using the desired sort indices, reorder the array
	batch_sort_aux(array, index[:])
}

/*
 * Batched reindex and sort using twinsort (stable).
 * Given an array and a comparator, index the array internally, then sort it all at once. Suitable 
 * if your array elements are >~ 50 bytes.
 * Original algorithm developed by Igor van den Hoven. (https://github.com/scandum) (MIT licensed)
 * See twinsort_cmp() for details.
 */
twinsort_cmp_batch :: proc(array: []$T, cmp: proc(T, T) -> int)
{
	// This version of twinsort removes a major limitation of the original code: it slows down 
	// disproportionately on arrays of structs (and also is memory-intensive on them).
	assert(cmp != nil, "xsort.twin_sort_cmp_batch(): needs a sort condition")

	// Make and initialize a reindexing array
	index := make([dynamic]int, len(array))
	defer delete(index)
	for i in 0 ..< len(array) do index[i] = i

	// Reindex
	if (!gen_sorted_index_twinsort_aux_swap(array, index[:], cmp))
	{
		gen_sorted_index_twinsort_aux_tail_merge(array, index[:], 2, cmp)
	}

	// Using the desired sort indices, reorder the array
	batch_sort_aux(array, index[:])
}





/*
 * Reindexing may be used as the input to a later sort-in-place, or to handle items in sorted order 
 * in a variety of ways without paying the cost of actually moving elements in memory.
 *
 * On arrays with small elements of <~50 bytes, this doesn't save much time (or even costs time). 
 * However, go above ~100 bytes/element and relative speed starts to snowball. Feed in an array of 
 * 100 4096-byte structs and you spend on the order of 1/20th of the time of a full sort. Memory 
 * consumption of some sorting algorthms, inclusing twinsort, also gets reset: it is now relative to 
 * the size of index, not data, elements.
 *
 * Uses only stable sort algorthims with custom comparators; it is assumed that a dataset 
 * heavy enough to warrant indexing is also complex enough that explicit sort instructions are 
 * required and that the reordering of equal-value elements is undesired.
 *
 * it would be delicious to generalize the sorting algorithms to optionally handle reindexing, but 
 * this at present only seems possible at a significant cost in code clarity (and also performance).
 * So we essentially duplicate xsort.sort_stable_cmp() and the algorithms it selects from (or at 
 * least the essential ones).
 * -AMS
 */


 /*
  * Reindexer: Given a slice of a data array, a slice of an index array, and a comparator, reorder 
  * the index slice. Always use a stable sort.
  * Optionally, ask to have the index initialized automatically.
  *
  * CRITICAL: Every element position of the data slice should be present in the index. 
  * In the case of an initial index (no previous sorts), the index will be { 0, 1, 2 ... }. In other 
  * words, the set of unique integers [0 .. len(data slice)).
  * This is true regardless of the position of the array slice in the original array. Indices are 
  * relative to the beginning of the data slice, not the array.
  * -AMS-
  */
gen_sorted_index_stable :: proc(array: []$T, index: []$IT, cmp: proc(T, T) -> int, 
	init_index: init_index = .do_not_initialize_index) #no_bounds_check
{
	assert(cmp != nil, "xsort.gen_sorted_index_stable(): needs a sort condition")
	assert(len(index) == len(array), "xsort.gen_sorted_index_stable(): Index slice needs to be the same length as the slice being reindexed.")

	nmemb := len(array)
	elem_size := size_of(T)

	// Auto-initialize the index on request (and never otherwise)
	if (init_index == .initialize_index)
	{
		for i in 0 ..< nmemb do index[i] = i
	}

	// Use a reasonable algorithm. Must be a stable comparison sort.
	if (elem_size < 24)
	{
		if (nmemb < insertion_sort_stable_cmp_max)
		{
			insertion_sort_cmp(array, cmp)
		}
		else
		{
			twinsort_cmp(array, cmp)
		}
	}
	else if ((elem_size < 72 && nmemb < 20) ||
		     (elem_size < 256 && nmemb < 10) ||
		     (nmemb < 5))
	{
		insertion_sort_cmp(array, cmp)
		return
	}
	else
	{
		twinsort_cmp(array, cmp)
	}
}

init_index :: enum
{
	do_not_initialize_index,
	initialize_index
}


/*
 * Reindex using insertion sort. 
 * CRITICAL: Every element position of the data slice should be present in the index. 
 * See gen_sorted_index_stable(), and also insertion_sort_cmp() for details.
 */
gen_sorted_index_insertion_sort :: proc(array: []$T, index: []$IT, cmp: proc(T, T) -> int, 
	init_index: init_index = .do_not_initialize_index) #no_bounds_check
{
	assert(cmp != nil, "xsort.gen_sorted_index_insertion_sort(): needs a sort condition")
	assert(len(index) == len(array), 
		"xsort.gen_sorted_index_insertion_sort(): Index slice needs to be the same length as the slice being reindexed.")

	nmemb := len(array)

	if (init_index)
	{
		for i in 0 ..< nmemb do index[i] = i
	}

	for i := 0; i < nmemb; i += 1
	{
		key := index[i]
		j := i

		for (j > 0) && (cmp(array[index[j-1]], array[key]) > 0)
		{
			index[j] = index[j - 1]
			j -= 1
		}
		index[j] = key
	}
}

/*
 * Reindex using twinsort.
 * CRITICAL: Every element position of the data slice should be present in the index. 
 * Original algorithm developed by Igor van den Hoven. (https://github.com/scandum) (MIT licensed)
 * See gen_sorted_index_stable(), and also twinsort_cmp() for details.
 */
gen_sorted_index_twinsort :: proc(array: []$T, index: []$IT, cmp: proc(T, T) -> int, 
	init_index: init_index = .do_not_initialize_index) #no_bounds_check
{
	assert(cmp != nil, "gen_sorted_index_twinsort(): needs a sort condition")
	assert(len(index) == len(array), 
		"gen_sorted_index_twinsort(): Index slice needs to be the same length as the slice being reindexed.")

	if (init_index == .initialize_index)
	{
		for i in 0 ..< len(array) do index[i] = i
	}

	if (!gen_sorted_index_twinsort_aux_swap(array, index, cmp))
	{
		gen_sorted_index_twinsort_aux_tail_merge(array, index, 2, cmp)
	}
}


/*
 * See xsort.twin_swap().
 * - by Igor van den Hoven -
 */
@(private="package")
gen_sorted_index_twinsort_aux_swap :: proc(array: []$T, index: []$IT, cmp: proc(T, T) -> int) -> bool #no_bounds_check
{
	idx, start, end: int
    nmemb := len(array)

	idx = 0
	end = nmemb - 2

	// Sort the (already partially sorted) array
	for idx <= end
	{
		if cmp(array[index[idx]], array[index[idx + 1]]) <= 0
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
					// Check the last member of the run, if we missed it while advancing two at a time.
					if ((nmemb % 2 == 0) || cmp(array[index[idx - 1]], array[index[idx]]) > 0)
					{
						// the entire array was reversed

						end = nmemb - 1

						for start < end
						{
							index[start], index[end] = index[end], index[start]
							start += 1; end -= 1
						}
						return true // Signal that we dont' need tail_merge() to fire.
					}
				}
				break
			}

			if (cmp(array[index[idx]], array[index[idx + 1]]) > 0)
			{
				if (cmp(array[index[idx - 1]], array[index[idx]]) > 0)
				{
					idx += 2
					continue
				}
				index[idx], index[idx + 1] = index[idx + 1], index[idx]
			}
			break
		}

		end = idx - 1

		for start < end
		{
			index[start], index[end] = index[end], index[start]

			start += 1; end -= 1
		}
		end = nmemb - 2

		idx += 2
	}
	return false
}

/*
 * See xsort.tail_merge().
 * - by Igor van den Hoven -
 */
@(private="package")
gen_sorted_index_twinsort_aux_tail_merge :: proc(array: []$T, index: []$IT, block: int, cmp: proc(T, T) -> int) #no_bounds_check
{
	block := block // allow modification
	offset: int
	a, s, c, c_max, d, d_max, e: int
    nmemb := len(array)

	swap := make([dynamic]IT, nmemb / 2)
	defer delete(swap)

	s = 0

	for block < nmemb
	{
		for offset = 0; offset + block < nmemb; offset += block * 2
		{
			a = offset
			e = a + block - 1

			if (cmp(array[index[e]], array[index[e + 1]]) <= 0)
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

			for cmp(array[index[e]], array[index[d]]) <= 0
			{
				d_max -= 1
				d -= 1
				c_max -= 1
			}

			c = s
			d = a + block

			for c < c_max
			{
				swap[c] = index[d]
				c += 1; d += 1
			}
			c -= 1

			d = a + block - 1
			e = d_max - 1

			if (cmp(array[index[a]], array[index[a + block]]) <= 0)
			{
				index[e] = index[d]
				e -= 1; d -= 1

				for c >= s
				{
					for cmp(array[index[d]], array[swap[c]]) > 0
					{
						index[e] = index[d]
						e -= 1; d -= 1
					}
					index[e] = swap[c]
					e -= 1; c -= 1
				}
			}
			else
			{
				index[e] = index[d]
				e -= 1; d -= 1

				for d >= a
				{
					for cmp(array[index[d]], array[swap[c]]) <= 0
					{
						index[e] = swap[c]
						e -= 1; c -= 1
					}
					index[e] = index[d]
					e -= 1; d -= 1
				}
				for c >= s
				{
					index[e] = swap[c]
					e -= 1; c -= 1
				}
			}
		}
		block *= 2
	}
}


/* 
 * Resorter. Given a data array slice and an index slice, move array elements until their positions 
 * match index values. Paired with gen_sorted_index_stable().
 *
 * Options:
 *     Bounds checks: recommended unless upstream code has exclusive access to the index array. 
 *     Slight decrease in speed.
 *     Method: Default is auto; 
 *
 * The index is never altered, enabling it to be used repeatedly.
 * CRITICAL: Every element position of the data slice should be present in the index.
 * -AMS-
 */
reorder_from_index :: proc(data: []$T, sidx: []$IT, options: bounds_check_options = .bounds_check, 
	method: reorder_options = .choose_for_me) -> (ok: bool) #no_bounds_check // See below.
{
	method := method
	nmemb := len(data)
	nindx := len(sidx)

	// We're being handed an index from Murphy-knows where. Unless explicitly asked to be unsafe, be safe.
	if (options != .no_bounds_check)
    {
        err, msg := bounds_check(sidx, data, "xsort.reorder_from_index()")
        if (err != 0)
        {
            fmt.eprintfln("%s. Sort cancelled.", msg)
            return false
        }
    }

	// Make a copy of the index. Work off the copy, preserve the original.
	index := make([dynamic]IT, nmemb)
	defer delete(index)
	copy(index[:], sidx)

	// Choose a method. If no (legal) choice is made by the user, then we assume method 1 is superior 
	// on arrays with small elements (if said arrays are not enormous) and method 2 superior otherwise.
	if ((method == .choose_for_me))
	{
		method = .standard
		if ((size_of(T) < 32) && (size_of(T) * nmemb < 1024 * 1024 * 128))
		{
			method = .numeric_high_mem
		}
	}

	#partial switch method {
	// Loop along the data array; sort by completing loops as they appear.
	// Slower on arrays with small elements, faster otherwise. Far less memory-intensive.
	case .standard:
	{
		// We need to keep track of which elements are now sorted.
		index_check := make([dynamic]int, nmemb)
		defer delete(index_check)
		for i in 0 ..< nmemb do index_check[i] = index[i]

		// Scan the data
		for i in 0 ..< nmemb
		{
			// Symmetric. Perfect.
			if (index_check[i] == i) do continue

			swap_data  := data[i]
			swap_index := index[i]

			idx := index[i]
			data[i] = data[idx]
			index[i] = index[idx]
			index_check[i] = i // mark this as done

			// Seek along this loop of index references
			for true
			{
				here := idx
				idx = index[here]

				// Every data element in the loop is overwritten by the next ...
 				if (idx != i)
				{
					data[here] = data[idx]
					index[here] = index[idx]
					index_check[here] = here
				}
				else // ... except the last, which is overwritten by the first.
				{
					data[here]  = swap_data
					index[here] = swap_index
					index_check[here] = here
					break
				}
			}
		}
	}

	// Throw memory at the problem. Create a new blank array equal to the input, paste elements by 
	// index, and copy back. Very fast on arays with small elements, very memory-intensive.
	case .numeric_high_mem:
	{
		array_copy := make([dynamic]T, nmemb)
		defer delete(array_copy)
		slice_copy := array_copy[:]

		for i in 0 ..< nmemb
		{
			slice_copy[i] = data[index[i]]
		}
		copy(data, slice_copy)
	}}

	return true
}

reorder_options :: enum
{
	choose_for_me = 0,
	standard = 1, // faster on arrays with elements >= ~32 bytes; uses almost no memory
	numeric_high_mem = 2, // faster on numeric arrays; uses elements * size_of(element) memory
}



/*
 * Bounds- (and some other things-) unsafe version of reorder_from_index(), intended only for use 
 * by batched sorts, where inputs are already checked. Does not preserve index. Gains a (small 
 * amount of) speed.
 */
@(private = "file")
batch_sort_aux :: proc(data: []$T, index: []$IT, method: reorder_options = .choose_for_me) -> (ok: bool) #no_bounds_check
{
	method := method
	nmemb := len(data)
	nindx := len(index)

	// Choose a method. If no (legal) choice is made by the user, then we assume method 1 is superior 
	// on arrays with small elements (if said arrays are not enormous) and method 2 superior otherwise.
	if ((method == .choose_for_me))
	{
		method = .standard
		if ((size_of(T) < 32) && (size_of(T) * nmemb < 1024 * 1024 * 128))
		{
			method = .numeric_high_mem
		}
	}

	#partial switch method {
	// Loop along the data array; sort by completing loops as they appear.
	case .standard:
	{
		// We need to keep track of which elements are now sorted.
		index_check := make([dynamic]IT, nmemb)
		defer delete(index_check)
		for i in 0 ..< nmemb do index_check[i] = index[i]

		// Scan the data
		for i in 0 ..< nmemb
		{
			// Symmetric. Perfect.
			if (index_check[i] == i) do continue

			swap_data  := data[i]
			swap_index := index[i]

			idx := index[i]
			data[i] = data[idx]
			index[i] = index[idx]
			index_check[i] = i // mark this as done

			// Seek along this loop of index references
			for true
			{
				here := idx
				idx = index[here]

				// Every data element in the loop is overwritten by the next ...
 				if (idx != i)
				{
					data[here] = data[idx]
					index[here] = index[idx]
					index_check[here] = here
				}
				else // ... except the last, which is overwritten by the first.
				{
					data[here]  = swap_data
					index[here] = swap_index
					index_check[here] = here
					break
				}
			}
		}
	}

	// Throw memory at the problem. Create a new blank array equal to the input, paste elements by 
	// index, and copy back. Very fast on arays with small elements, very memory-intensive.
	case .numeric_high_mem:
	{
		array_copy := make([dynamic]T, nmemb)
		defer delete(array_copy)
		slice_copy := array_copy[:]

		for i in 0 ..< nmemb
		{
			slice_copy[i] = data[index[i]]
		}
		copy(data, slice_copy)
	}}

	return true
}

