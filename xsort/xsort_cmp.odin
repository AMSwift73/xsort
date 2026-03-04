/*
 * The xsort package: Sorting methods and algorithms for Odin programmers.
 *
 * Sorting on arrays with the use of a custom comparator.
 *
 * Version 1.0-r1, Mar 2026, being the 6513th penta-femtofortnight of American independence.
 */
package xsort

import "base:intrinsics"
import "core:sort" // for quicksort

//import "core:fmt"

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
	Using custom comparison sorts means working with comparators - procedures that compare the value of 
two things. The basic question they answer is whether a goes before b (-1), after b (1), or neither (0)? 
(https://www.jameskerr.blog/posts/javascript-sort-comparators/)
	Comparators may be inserted as parameters, in the parent procedure, or the 
namespace. However, the data array being sorted must be in-scope for the comparator or attempts at 
polymorphism will fail. This means that making a library of comparators in an upstream package (like 
core:sort or here) is tedious.

	Here's a comparator for ascending (forward) sorts.
This works on everything. If the algorithm is stable (maintains the relative order of equal-value 
elements), then the sort will be stable.
sort_ascending_stable :: proc(a, b: DataT) -> int
{ return (int(a > b) - int(a < b)) }
 	For a reverse sort, swap <'s and >'s. Using a custom comparator is probably the fastest way to 
get a reverse (descending) sort.

	If you feel like sticking comparators into the sort call itself, something of the form 
xsort.insertion_sort_cmp(my_slice, 
	proc(a, b: DataT) -> int { return (int(a > b) - int(a < b)) })
Will work and maintain stability on all xsort comparison sorts (no speed difference).

	The binary form of the comparator { return (a > b) ? 1 : 0 } looks quite a bit faster, but (when 
benchmarking correctly accounts for timer cost and imprecision) is not in practice.

	Using a custom comparator is probably the fastest way to 
get a reverse (descending) sort.
sort_descending_unstable :: proc(a, b: DataT) -> int
{ return (a < b) ? 1 : 0 }

	You may desire to sort on multiple criteria. The first option is simply to chain together 
comparison sorts, usually using sort_cmp_stable(). Sort secondary first, then primary. A second 
option is to build a combined comparator, being careful not to use any branching statements (if and 
the like). One method sometimes available to you if building for 64-bit systems is:
sort_unified :: proc(a, b: my_struct_type) -> int
{
	a_value : i64 = i64(a.type << 32) + i64(a.number)
	b_value : i64 = i64(b.type << 32) + i64(b.number)
	return (int(a_value > b_value) - int(a_value < b_value))
}
	Is only certain to work if the ranges of the data types each fit in i32. i64->i128 also works, 
but imposes enough of a slowdown as to make the effort almost certain not to deliver.

	The third option, and the one you might well want to adopt, to reindex the array 
(using xsort.gen_sorted_index_stable()) repeatedly and (optionally) sort at the end. This is the preferred 
method for sorting structs-of-arrays, but it also works very well with arrays-of-structs.
*/


insertion_sort_stable_cmp_max :: 35
insertion_sort_unstable_cmp_max :: 20
shell_sort_unstable_cmp_max :: 100
/*
 * These values are adjusted using tests on arrays of structs (as opposed to numeric values), with
 * data pattern that are partly ordered and/or have short runs of equal values.
 */


/*
 * Choose between sorting algorithms to effectively handle datasets of any array length and with any 
 * size of data elements. 
 *
 * Two use cases here: stable sort-required, and stable sort-don't care.
 * At present, choosing the latter yields speed benefits only sometimes, due to the high effectivness 
 * of twinsort, both in its original form applied to arrays of numbers and in batched form applied 
 * to arrays of structs.
 * -AMS-
 */


/*
 * Stable comparison sort with user-supplied comparison procedure. Chooses an algorithm and a
 * method automatically, based on number of array elements and the size of the elements.
 * Handles arrays both of numbers and structs.
 * If your needs are well-defined, or unusual, consider using a more specific option.
 */
sort_stable_cmp :: proc(array: []$T, cmp: proc(T, T) -> int)
{
	assert(cmp != nil, "sort_stable_cmp() needs a sort condition")
    nmemb := len(array)
	elem_size := size_of(T)

	// Small arrays go straight to insertion sort
	if ((nmemb < insertion_sort_stable_cmp_max) && 
		((elem_size < 24) ||
		 (elem_size < 72 && nmemb < 20) ||
		 (elem_size < 256 && nmemb < 10) ||
		 (nmemb < 5)))
	{
		// There are times when a batched version outperforms, but they tend to be times when
		// batched twinsort is even faster.
		insertion_sort_cmp(array, cmp)
		return
	}
	else
	{
		// We want twinsort; the only question is whether or not to batch.
		// We're no more than even-handed in choosing batch, despite the fact that it saves memory 
		// as well as potentially increasing speed.
		if (elem_size < 60)
		{
			twinsort_cmp(array, cmp)
		}
		else if (elem_size > 160)
		{
			// If they have too many elements for insertion sort, than batching is likely the right move.
			twinsort_cmp_batch(array, cmp)
		}
		else if (elem_size < 80)
		{
			if (nmemb > 200) do twinsort_cmp_batch(array, cmp)
			else             do twinsort_cmp(array, cmp)
		}
		else if (elem_size < 100)
		{
			if (nmemb > 30) do twinsort_cmp_batch(array, cmp)
			else            do twinsort_cmp(array, cmp)
		}
		else if (elem_size < 120)
		{
			if (nmemb > 20) do twinsort_cmp_batch(array, cmp)
			else            do twinsort_cmp(array, cmp)
		}
		else // if (elem_size <= 160)
		{
			if (nmemb > 15) do twinsort_cmp_batch(array, cmp)
			else            do twinsort_cmp(array, cmp)
		}
	}
	// make sure you haven't called more than one search procedure...
}

/*
 * Unstable comparison sort with user-supplied comparison procedure. Chooses an algorithm and a
 * method automatically, based on number of array elements and the size of the elements.
 * If your needs are well-defined, or unusual, consider using a more specific option.
 */
sort_unstable_cmp :: proc(array: []$T, cmp: proc(T, T) -> int)
{
	// Author's comment: At present, the biggest missing piece is a sorting algorithm that is 
	// especially good on extremely long arrays (>~1m) and that (unlike radix sort) accepts comparators.
	assert(cmp != nil, "sort_unstable_cmp() needs a sort condition")
    nmemb := len(array)
	elem_size := size_of(T)

	// Handle the small stuff quickly
	if (nmemb < 6)
	{
		insertion_sort_cmp(array, cmp)
		return
	}
	else if (elem_size < 32)
	{
		if      (nmemb <  20) do insertion_sort_cmp(array, cmp)
		else if (nmemb < 120) do shell_sort_cmp(array, cmp)
		else                  do twinsort_cmp(array, cmp)
	}
	else if (elem_size < 112) // Bifurate the problem set
	{
		if (elem_size < 52)
		{
			if      (nmemb <  10) do insertion_sort_cmp(array, cmp)
			else if (nmemb < 200) do shell_sort_cmp(array, cmp)
			else                  do twinsort_cmp(array, cmp)
		}
		else if (elem_size < 80) // Batching starts getting useful about element size 60, esp. for twinsort
		{
			if      (nmemb <     8) do insertion_sort_cmp(array, cmp)
			else if (nmemb <   200) do shell_sort_cmp(array, cmp)
			else if (nmemb < 20000) do twinsort_cmp_batch(array, cmp)
			else                    do sort.quick_sort_proc(array, cmp)
		}
		else
		{
			if      (nmemb <     6) do insertion_sort_cmp(array, cmp)
			else if (nmemb <    40) do shell_sort_cmp(array, cmp)
			else if (nmemb < 10000) do twinsort_cmp_batch(array, cmp)
			else                    do sort.quick_sort_proc(array, cmp)
		}
	}
	else // Chonky bois
	{
		if (elem_size < 200)
		{
			if      (nmemb <      6) do insertion_sort_cmp(array, cmp)
			else if (nmemb <    250) do sort.quick_sort_proc(array, cmp)
			else if (nmemb < 100000) do twinsort_cmp_batch(array, cmp)
			else                     do sort.quick_sort_proc(array, cmp) // Repeat appearance.
		}
		else if (elem_size < 400)
		{
			if      (nmemb <      6) do insertion_sort_cmp(array, cmp)
			else if (nmemb <     25) do sort.quick_sort_proc(array, cmp)
			else if (nmemb < 200000) do twinsort_cmp_batch(array, cmp)
			else                     do sort.quick_sort_proc(array, cmp)
		}
		else
		{
			if      (nmemb <   6) do insertion_sort_cmp(array, cmp)
			else if (nmemb < 100) do shell_sort_cmp_batch(array, cmp)
			else                  do twinsort_cmp_batch(array, cmp)
		}
	}
}


/*
 * Insertion sort. 
 * Stable. Very fast if array <= ~10 elements; very slow if much larger than that.
 * Uses almost no disk space when instantiated and essentially no temporary memory when used.
 */
insertion_sort_cmp :: proc(array: []$T, cmp: proc(T, T) -> int) #no_bounds_check
{
	swap: T
	for i in 1 ..< len(array) 
	{
		for j := i; j > 0 && cmp(array[j-1], array[j]) > 0; j -= 1 
		{
			swap = array[j]
			array[j] = array[j - 1]
			array[j - 1] = swap
		}
	}
}


/*
 * Shell sort, developed by Donald Shell and using Marcin Ciura's gap sequence. 
 * https://en.wikipedia.org/wiki/Shellsort. See note below re. gap sequences.
 * Unstable. Faster than insertion sort in arrays above ~10 elements; slower than more modern sorts 
 * above very roughly 50-500 elements. "Unexpectedly useful."
 * Uses almost no disk space when instantiated and almost no temporary memory when used.
 *
 * Compare and sort elements far apart; draw nearer with each loop until a distance of 1 is reached, 
 * completing the sort.
 */
shell_sort_cmp :: proc(array: []$T, cmp: proc(T, T) -> int) #no_bounds_check
{
	assert(cmp != nil, "xsort.shell_sort_cmp() needs a sort condition")

	// Use Marcin Ciura's gap sequence, optionally extended using value.k = 2.25 * value.(k-1)
	shellsort_gaps: []int : 
	{
		// Uncomment to increase speed on arrays >= 7k elements, at the cost of slower speed on smaller arrays.
		// 460_444, 204_642, 90_952, 40_423, 17_966, 7985, 3549, 1577, 
		701, 301, 132, 57, 23, 10, 4, 1 // If final number is 1, sort will complete.
	}
	i, j: int

	// Sort; decreasing gap with each pass
	for gap in shellsort_gaps
	{
		for i in gap ..< len(array)
		{
			key := array[i]

            for j = i; (j >= gap) && cmp(array[j - gap], key) > 0; j -= gap
            {
                array[j] = array[j - gap]
            }

			if (j != i) do array[j] = key // faster with arrays of structs
		}
	}
}


/*
 * Twinsort, developed by Igor van den Hoven. (https://github.com/scandum) (MIT licensed)
 * Stable. Best on arrays with 40 < elements < 1m. Very fast on numeric primitives and other small
 * datatypes (< ~24 bytes); slows down as array objects grow.
 *
 * Prefer twinsort_cmp_batch if working with arrays with elements larger than about 50 bytes.
 *
 * Uses a moderately small amount of disk space when instantiated. Uses half the array size in 
 * temporary memory.
 *
 * Call twin_swap(), which sorts 2-element blocks of the array (and handles pathological cases). 
 * Unless this process sorts the whole array, call tail_merge_cmp() to merge the blocks.
 */
twinsort_cmp :: proc(array: []$T, cmp: proc(T, T) -> int)
{
	assert(cmp != nil, "xsort.twinsort_cmp(): needs a sort condition")

	if (!twin_swap_cmp(array, cmp))
	{
		tail_merge_cmp(array, 2, cmp)
	}
}

/*
 * 1. Turn the array into sorted blocks of 2 elements (saves time in tail_merge()).
 * 2. Detect and sort reverse order runs, so 6 5 4 3 2 1 becomes 1 2 3 4 5 6 rather than 5 6 3 4 1 2
 */
twin_swap_cmp :: proc(array: []$T, cmp: proc(T, T) -> int) -> bool #no_bounds_check
{
	idx, start, end: int
    nmemb := len(array)

	idx = 0
	end = nmemb - 2


	for idx <= end
	{
		if cmp(array[idx], array[idx + 1]) <= 0
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
					if ((nmemb % 2 == 0) || cmp(array[idx - 1], array[idx]) > 0)
					{
						// the entire array was reversed

						end = nmemb - 1

						for start < end
						{
							array[start], array[end] = array[end], array[start]
							start += 1; end -= 1
						}
						return true // Signal that we dont' need tail_merge() to fire.
					}
				}
				break
			}

			if cmp(array[idx], array[idx + 1]) > 0
			{
				if cmp(array[idx - 1], array[idx]) > 0
				{
					idx += 2
					continue
				}
				array[idx], array[idx + 1] = array[idx + 1], array[idx]
			}
			break
		}

		end = idx - 1

		for start < end
		{
			array[start], array[end] = array[end], array[start]
			start += 1; end -= 1
		}
		end = nmemb - 2

		idx += 2
	}
	return false
}

/*
 * Bottom up merge sort. It copies the right block to swap, next merges starting at the tail ends 
 * of the two sorted blocks. Can be used stand alone.
 * Uses at most number of members * sizeof(member) / 2 swap memory.
 */
tail_merge_cmp :: proc(array: []$T, block: int, cmp: proc(T, T) -> int) #no_bounds_check
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

			if cmp(array[e], array[e + 1]) <= 0
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

			for cmp(array[e], array[d]) <= 0
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

			if cmp(array[a], array[a + block]) <= 0
			{
				array[e] = array[d]; e -= 1; d -= 1

				for c >= s
				{
					for cmp(array[d], swap[c]) > 0
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
					for cmp(array[d], swap[c]) <= 0
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
