/*
 * Date: Mar 2026, being the 6513th penta-femtofortnight of American independence.
 * Author: Alexander M. Swift
 *
 * Benchmark all of xsort's specific options for sorting arrays of structs using comparators, 
 * alongside some of what the standard library offers.
 * Compare the speed of xsort's comparison sort, using auto-selected options, with calls to specific 
 * algorithms, demonstrating both the flexibility - and sometimes the speed penalties - of the former.
 *
 * (n.b.: While benchmark results will not be representative of results on any real-world dataset, they 
 * may perhaps be suggestive.)
 */
package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:os"
import "core:sort"
import "core:strconv"
import "core:time"

import "xsort"


/*
 * The contents of this file are Copyright (C) The xsort package author(s). They are released under 
 * the terms of the MIT license, or to the public domain, your choice.
 */

// If there's a faster stable-sort comparator (that also is always correct), I haven't found it.
sort_stock_type_f :: proc(a, b: stock) -> int
{
	return (int(a.type > b.type) - int(a.type < b.type))
}
sort_stock_type_r :: proc(a, b: stock) -> int
{
	return (int(a.type < b.type) - int(a.type > b.type))
}

/*
All of these yield the same benchmark times (within margin of error) time as sort_stock_type_f. Apparently, both 
conditionals always get evaluated.
	sort_stock_type_f2_assume_out_of_order :: proc(a, b: stock) -> int
	{
		return ((a.type > b.type) ? 1 : -int(a.type < b.type))
	}
	sort_stock_type_f2_assume_in_order :: proc(a, b: stock) -> int
	{
		return ((a.type < b.type) ? -1 : int(a.type > b.type))
	}
	sort_stock_type_f2_assume_equal :: proc(a, b: stock) -> int
	{
		return ((a.type == b.type) ? 0 : ((a.type > b.type) ? 1 : -1))
	}
	sort_stock_type_f3 :: proc(a, b: stock) -> int {
		switch {
		case a.type < b.type: return -1
		case a.type > b.type: return +1
		}
		return 0
	}
*/

stock :: struct
{
	type: int, // This is the only element that needs to be present.
	data_to16: int,
	data_to24: int,
	// data_to32: int,
	// data_to40: int,
	// data_to256: [232]u8, // uncomment this to test structs of 256 bytes
	// data_to4092: [3840 - 2048 - 1024]u8, // also uncomment this to test structs of 4092 bytes
}


/*
 * Test the performance of xsort's comparison sorts with custom comparators, including batched 
 * versions, but not including reindex and sort-from-index. Include the highly competitive Odin 
 * quicksort.
 * Duplicate sorts (and array resets) within runs; see test #1 for comments here.
 * Use random numbers, with runs of equal values that increase (slowly) as array length increases.
 *
 * Repeat tests with a wide enough variety of array lengths and element sizes to set the rules for 
 * most of the auto-algorithm sort procedures in xsort.
 * -AMS-
 */
main :: proc()
{
	nmemb := 20
	reps := 1

	// Consistent pseudo-randomness reduces test timing dispersion, but - if arrays are small - 
	// makes the data less representative of its general pattern and sometimes allows subtle sorting 
	// errors to go undetected.
	seed : u64 = 0

	ok: bool

    // Accept command-line arguments to modify test parameters
    for i in 1 ..< len(os.args)
    {
        switch i 
        {
            case 1:
                nmemb, ok = strconv.parse_int(os.args[1]); assert(ok)
            case 2:
                reps, ok = strconv.parse_int(os.args[2]); assert(ok)
            case 3:
                seed, ok = strconv.parse_u64(os.args[3]); assert(ok)
        }
    }

    // Create initialization and working arrays
    array_init := make([dynamic]stock, nmemb)
    array_work := make([dynamic]stock, nmemb)
    defer delete(array_init)
    defer delete(array_work)

    // Slice: ptr to and length of these arrays
    slice_init : []stock = array_init[:]
    slice_work : []stock = array_work[:]

	// Consistent pseudo-random numbers for a given seed
	if (seed == 0) do seed = u64(time.now()._nsec)
	rand.reset(seed)


	// Set up the initialization array. Use length-adjusted runs of random numbers.
	run_max := 1 + int(math.pow_f32(f32(nmemb), 0.25))
	for i := 0; i < len(array_init); i += 1
	{
		array_init[i].type = rand.int_range(-1_000_000_000, 1_000_000_000)

		// Allow runs of identical data; cut run short at end of array
		run := rand.int_range(1, run_max)
		for j in 1 ..< run
		{
			if (i >= nmemb - 1) do break
			array_init[i + 1] = array_init[i]
			i += 1
		}
	}
	// for i in 0 ..< len(array_init) do fmt.printfln("{}", array_init[i])

	// Set up timers
	start : time.Time
	duration_insertion : time.Duration = 0
	duration_insertion_batch : time.Duration = 0
	duration_twin : time.Duration = 0
	duration_twin_batch : time.Duration = 0
	duration_merge : time.Duration = 0
	duration_shell : time.Duration = 0
	duration_shell_batch : time.Duration = 0
	duration_quicksort_proc : time.Duration = 0
	duration_slice_sort_by : time.Duration = 0
 
	// Introduce ourselves
	fmt.printfln("%d reps: For each sorting method, each rep sorts an array[%d] of %d-byte structs.", 
		reps, nmemb, size_of(stock))

	// Warm-up ("We're using THIS data a bunch, memory-manager."). Without a warm-up, the first test 
	// is often slower than the rest.
	for r in 0 ..< 1 + reps / 10
	{
		copy_slice(slice_work, slice_init)
		xsort.shell_sort_cmp(slice_work, sort_stock_type_f) // doesn't seem to affect this procedure's timings.
	}

	loop_start := time.now()

	for r in 0 ..< reps
	{
		if (nmemb <= 100) // Only for small arrays
		{
			start = time.now()
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp(slice_work, sort_stock_type_f)
			duration_insertion += time.since(start)

			start = time.now()
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			duration_insertion_batch += time.since(start)
		}

		start = time.now()
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp(slice_work, sort_stock_type_f)
		duration_twin += time.since(start)

		start = time.now()
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp_batch(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp_batch(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp_batch(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp_batch(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp_batch(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp_batch(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp_batch(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp_batch(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp_batch(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp_batch(slice_work, sort_stock_type_f)
		duration_twin_batch += time.since(start)

		// if (nmemb <= 1000) // scales very poorly
		// {
		// 	start = time.now()
		// 	copy_slice(slice_work, slice_init)
		// 	sort.merge_sort_proc(slice_work, sort_stock_type_f)
		// 	duration_merge += time.since(start)
		// }

		if (nmemb <= 1000) // see shell_sort_cmp() for details
		{
			start = time.now()
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp(slice_work, sort_stock_type_f)
			duration_shell += time.since(start)

			start = time.now()
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp_batch(slice_work, sort_stock_type_f)
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp_batch(slice_work, sort_stock_type_f)
			duration_shell_batch += time.since(start)
		}

		start = time.now()
		copy_slice(slice_work, slice_init)
		sort.quick_sort_proc(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		sort.quick_sort_proc(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		sort.quick_sort_proc(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		sort.quick_sort_proc(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		sort.quick_sort_proc(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		sort.quick_sort_proc(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		sort.quick_sort_proc(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		sort.quick_sort_proc(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		sort.quick_sort_proc(slice_work, sort_stock_type_f)
		copy_slice(slice_work, slice_init)
		sort.quick_sort_proc(slice_work, sort_stock_type_f)
		duration_quicksort_proc += time.since(start)

		// Smoothsort. Not competative with quicksort.
		// copy_slice(slice_work, slice_init)
		// start = time.now()
		// slice.sort_by(slice_work, 
		// 	proc(a, b: stock) -> bool { 
		// 		return a.type < b.type 
		// 	})
		// duration_slice_sort_by += time.since(start)

		// "I'm working, I swear!"
		loop_time_elapsed := time.duration_seconds(time.since(loop_start))
		if (loop_time_elapsed >= 5)
		{
			fmt.printfln("rep %d of %d", r, reps)
			loop_start = time.now()
		}
	}

	// Results
	fmt.printfln("Stable sorts:")
	if (duration_insertion > 0)
	{
		fmt.printfln("  xsort.insertion_sort_cmp: %.0f msec.", 
		time.duration_milliseconds(duration_insertion))
	}
	if (duration_insertion_batch > 0)
	{
		fmt.printfln("  xsort.insertion_sort_cmp_batch: %.0f msec.", 
			time.duration_milliseconds(duration_insertion_batch))
	}
	if (duration_twin > 0)
	{
		fmt.printfln("  xsort.twinsort_cmp: %.0f msec.", 
			time.duration_milliseconds(duration_twin))
	}
	if (duration_twin_batch > 0)
	{
		fmt.printfln("  xsort.twinsort_cmp_batch: %.0f msec.", 
			time.duration_milliseconds(duration_twin_batch))
	}
	if (duration_merge > 0)
	{
		fmt.printfln("  sort.merge_sort_proc: %.0f msec.", 
			time.duration_milliseconds(duration_merge))
	}

	fmt.printfln("Unstable sorts:")
	if (duration_shell > 0)
	{
		fmt.printfln("  xsort.shell_sort_cmp: %.0f msec.", 
			time.duration_milliseconds(duration_shell))
		fmt.printfln("  xsort.shell_sort_cmp_batch: %.0f msec.", 
			time.duration_milliseconds(duration_shell_batch))
	}
	if (duration_quicksort_proc > 0)
	{
		fmt.printfln("  sort.quick_sort_proc: %.0f msec.", 
			time.duration_milliseconds(duration_quicksort_proc))
	}
	if (duration_slice_sort_by > 0)
	{
		fmt.printfln("  slice.sort_by (smoothsort): %.0f msec.", 
			time.duration_milliseconds(duration_slice_sort_by))
	}
}
