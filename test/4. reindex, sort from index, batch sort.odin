/*
 * Date: Feb 2026, being the 6512th penta-femtofortnight of American independence.
 * Author: Alexander M. Swift
 *
 * Verify that the reindexing and sort-from-index code works. Demonstrate basic usage. Do some 
 * (very basic) benchmarking.
 */
package main

import "core:fmt"
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

// See the file test, array of structs for comments.
sort_stock_type_f :: proc(a, b: stock) -> int
{
	return (int(a.type > b.type) - int(a.type < b.type))
}
sort_stock_type_r :: proc(a, b: stock) -> int
{
	return (int(a.type < b.type) - int(a.type > b.type))
}
sort_stock_num_f :: proc(a, b: stock) -> int
{
	return (int(a.number > b.number) - int(a.number < b.number))
}
sort_stock_num_r :: proc(a, b: stock) -> int
{
	return (int(a.number < b.number) - int(a.number > b.number))
}

sort_stock_unified_f :: proc(a, b: stock) -> int
{
	a_value : i64 = i64(a.type << 32) + i64(a.number)
	b_value : i64 = i64(b.type << 32) + i64(b.number)
	return (int(a_value > b_value) - int(a_value < b_value))
}
sort_stock_unified_r :: proc(a, b: stock) -> int
{
	a_value : i64 = i64(a.type << 32) + i64(a.number)
	b_value : i64 = i64(b.type << 32) + i64(b.number)
	return (int(a_value < b_value) - int(a_value > b_value))
}

stock :: struct
{
	type: int,
	number: int,
	id: int,
	// data_to256: [232]u8, // uncomment this to test structs of 256 bytes
	// data_to4092: [3840]u8, // also uncomment this to test structs of 4092 bytes
}


/*
 * Verify that the reindexing and sort-from-index code works. Demonstrate basic usage. Do some 
 * (very basic) benchmarking.
 *
 * Useful parameters: elements in array, test repetitions. (random seed is usually unnecessary)
 * -AMS-
 */
main :: proc()
{
	nmemb := 10
	reps := 1

	// Demos are exclusive with each other and with benchmarking.
	demo_sort_indexed := true
	demo_sort_struct_of_arrays := true
	basic_bench_index_sorts := false

	// Set to a constant value for consistancy; set to zero to better catch subtle sorting errors.
	seed : u64 = 0

	ok: bool
	i: int

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
    slice_init := array_init[:]
    slice_work := array_work[:]
    

	// Consistent pseudo-random numbers
	if (seed == 0) do seed = u64(time.now()._nsec)
	rand.reset(seed)

	start : time.Time

	// Basic usage and verification of index-generation and of sorting from index
	if (demo_sort_indexed)
	{
		// Create index array
		array_index := make([dynamic]int, nmemb)
		defer delete(array_index)
		slice_index := array_index[:]

		// Set up the initialization array
		for i := 0; i < len(array_init); i += 1
		{
			array_init[i].id = i
			array_init[i].type = rand.int_range(1, 4) // 1, 2 or 3
			array_init[i].number = rand.int_range(1, 4) // same
		}

		// Initialize the working array
		copy_slice(slice_work, slice_init)

		// Demonstration: Reindex by stock type and then by name. Then resort using the index.
		fmt.println("Demonstration of reindexing and sort-from-index, using xsort.gen_sorted_index_stable() and xsort.sort_from_index().")
		fmt.println("Two condition sort: by type and secondly by number.")

		// Index supplied to gen_sorted* have to include indices for each position in the input slice
		// This should always start at zero regardless of slice position.
		// This can be done automatically on request.
		for i in 0 ..< nmemb do slice_index[i] = i

		// Reindex from array. Here, we do not ask for automatic reindexing (it might be that we 
		// already have a sort recorded in the index that we want to retain within equal values of 
		// the current sort).
		xsort.gen_sorted_index_stable(slice_work, slice_index, sort_stock_unified_f, .do_not_initialize_index)

		// Automatic verification: array treated as though it were sorted as per the index.
		check_stock_sort_reindex(slice_work, slice_index, "(indexing)", true, 4, false)

		// Given an index, sort the array.
		xsort.reorder_from_index(slice_work, slice_index)

		// Automatic verification: array now expected to be properly sorted.
		check_stock_sort(slice_work, "(reordering)", true, 4, true)
	}

	// Application of the above method to a structure of arrays (that is actually an SOA in memory)
	if (demo_sort_struct_of_arrays)
	{
		// Reset length
		nmemb_soa :: 6

		fruit :: struct
		{
			id : ^[dynamic]u16,
			num : ^[dynamic]u16,
			price : ^[dynamic]f16,
			deliciousness : ^[dynamic]u16,
		}

		delish :: enum u16
		{
			yuck = 0,
			ok,
			tasty,
			yummy,
			scrumptious,
			addictive,
		}

		fruit_names : [nmemb_soa]string = { "Apple", "Banana", "Kiwifruit", "Melon", "Peach", "Passionfruit" }
		delish_names : [len(delish)]string = { "yuck", "ok", "tasty", "yummy", "scrumptious", "addictive" }

		fruits := fruit {}

		array1 := make([dynamic]u16, nmemb_soa, context.temp_allocator)
		array2 := make([dynamic]u16, nmemb_soa, context.temp_allocator)
		array3 := make([dynamic]f16, nmemb_soa, context.temp_allocator)
		array4 := make([dynamic]u16, nmemb_soa, context.temp_allocator)

		fruits.id = &array1
		fruits.num = &array2
		fruits.price = &array3
		fruits.deliciousness = &array4

		fmt.println("\nReordering of a struct-of-arrays (SOA) using index sorts. Ordering by ID:")
		for i in 0 ..< nmemb_soa
		{
			fruits.id[i] = u16(i)
			fruits.num[i] = u16(rand.int_range(0, 1000))
			fruits.price[i] = f16(rand.float32_range(0, 1))
			fruits.deliciousness[i] = u16(rand.int_range(int(delish.yuck), len(delish)))

			fmt.printfln("%-13s: num = %d, price = %.2f, deliciousness = {}", 
				fruit_names[fruits.id[i]], fruits.num[i], fruits.price[i], delish_names[fruits.deliciousness[i]])
		}


		// Here's what we're a-gonna do.
		fmt.println("\nReorder all fruits by deliciousness:")

		fruit_sort_index := make([dynamic]int, nmemb_soa, context.temp_allocator)

		// Sort deliciousness (descending order). Initialize index first.
		xsort.gen_sorted_index_stable(fruits.deliciousness^[:], fruit_sort_index[:], 
			proc(a, b: u16) -> int { return (int(a < b) - int(a > b)) },
			.initialize_index)
		
		// Sort all arrays in the struct using the index
		xsort.reorder_from_index(fruits.id^[:], fruit_sort_index[:])
		xsort.reorder_from_index(fruits.num^[:], fruit_sort_index[:])
		xsort.reorder_from_index(fruits.price^[:], fruit_sort_index[:])
		xsort.reorder_from_index(fruits.deliciousness^[:], fruit_sort_index[:])

		// Print out
		for i in 0 ..< nmemb_soa
		{
			fmt.printfln("%-13s: num = %d, price = %.2f, deliciousness = {}", 
				fruit_names[fruits.id[i]], fruits.num[i], fruits.price[i], delish_names[fruits.deliciousness[i]])
		}


		// And now for our next trick...
		fmt.println("\nReset the arrays. Generate an index, this time sorting by number (ascending).\nDo not sort. Print out fruits using the index as a sorter.")

		// Sort by id (ascending order). Initialize (reset) index first.
		xsort.gen_sorted_index_stable(fruits.id^[:], fruit_sort_index[:], 
			proc(a, b: u16) -> int { return (int(a > b) - int(a < b)) },
			.initialize_index)

		// Sort by number. Do not overwrite previous sort (retain id order for a given number).
		xsort.gen_sorted_index_stable(fruits.num^[:], fruit_sort_index[:], 
			proc(a, b: u16) -> int { return (int(a > b) - int(a < b)) },
			.do_not_initialize_index)

		// Print out, in sorted order without array reordering.
		for i in 0 ..< nmemb_soa
		{
			idx := fruit_sort_index[i]
			fmt.printfln("%-13s: num = %d, price = %.2f, deliciousness = {}", 
				fruit_names[fruits.id[idx]], fruits.num[idx], fruits.price[idx], delish_names[fruits.deliciousness[idx]])
		}
	}

	if (basic_bench_index_sorts)
	{
		// Do some (very basic) speed testing

		// Introduce ourselves
		// Copies - usually - don't take much time by comparison.
		fmt.printfln("%d reps: For each sorting method, each rep initializes and sorts an array[%d] of %d-byte structs.", 
			reps, nmemb, size_of(stock))
		fmt.printfln("One sort per rep per method. Sorting on (%d-bit) int. All sorts are stable and sort by stock type only.", 
			size_of(array_init[0].type) * 8)
		fmt.printfln("Disclaimer: Figures below should not be treated as applicable to any real-world application.")
		
		// Set up the initialization array. This time we use a bit more of the data range.
		for i := 0; i < len(array_init); i += 1
		{
			array_init[i].id = i
			array_init[i].type = rand.int_range(-1_000_000_000, 1_000_000_000)
			array_init[i].number = rand.int_range(-1_000_000_000, 1_000_000_000)
		}

		// Warm-up ("We're using THIS data a bunch, memory-manager."). Without a warm-up, the first test 
		// is often slower than the rest.
		for r in 0 ..< 1 + reps / 10
		{
			copy_slice(slice_work, slice_init)
			xsort.twinsort_cmp(slice_work, sort_stock_type_f) // doesn't seem to affect this procedure's timings.
		}

		// Insertion sort (standard sort)
		if (nmemb <= 200)
		{
			start = time.now()
			for r in 0 ..< reps
			{
				copy_slice(slice_work, slice_init)
				xsort.insertion_sort_cmp(slice_work, sort_stock_type_f)

				check_stock_sort(slice_work, "Insertion sort: standard sort", true, 2, false)
			}
			if (reps > 1)
			{
				fmt.printfln("    Insertion sort: normal sort, : %.0f msec.", 
					time.duration_milliseconds(time.since(start)))
			}


			// Insertion sort (batched re-sort)
			start = time.now()
			for r in 0 ..< reps
			{
				copy_slice(slice_work, slice_init)
				xsort.insertion_sort_cmp_batch(slice_work, sort_stock_type_f)

				check_stock_sort(slice_work, "Insertion sort: batched sort", true, 2, false)
			}
			if (reps > 1)
			{
				fmt.printfln("    Insertion sort: batched re-sort after reindex: %.0f msec.", 
					time.duration_milliseconds(time.since(start)))
			}
		}

		// Twin sort (standard sort)
		start = time.now()
		for r in 0 ..< reps
		{
			copy_slice(slice_work, slice_init)
			xsort.twinsort_cmp(slice_work, sort_stock_type_f)

			check_stock_sort(slice_work, "Twinsort: standard sort", true, 2, false)
		}
		if (reps > 1)
		{
			fmt.printfln("    Twinsort: normal sort: %.0f msec.", 
				time.duration_milliseconds(time.since(start)))
		}


		// Twin sort (batched re-sort)
		start = time.now()
		for r in 0 ..< reps
		{
			copy_slice(slice_work, slice_init)
			xsort.twinsort_cmp_batch(slice_work, sort_stock_type_f)

			check_stock_sort(slice_work, "Twinsort: batched sort", true, 2, false)
		}
		if (reps > 1)
		{
			fmt.printfln("    Twinsort: batched re-sort after reindex: %.0f msec.", 
				time.duration_milliseconds(time.since(start)))
		}


		// Twin sort (reindex, then sort separately)
		start = time.now()
		for r in 0 ..< reps
		{
			// The time taken to allocate the index is included (but it's almost nothing).
			array_index := make([dynamic]int, nmemb)
			defer delete(array_index)

			copy_slice(slice_work, slice_init)

			// Reindex from array (specifically using twinsort). Ask for index initialization.
			xsort.gen_sorted_index_twinsort(slice_work, array_index[:], sort_stock_type_f, .initialize_index)
	
			// check_stock_sort_reindex(slice_work, array_index[:], "Twinsort: (separate indexing)", true, 2, false)

			// Reorder from index. Default options: Allow this procedure to perform manual bounds-checking. 
			// Slight slow-down, but far safer.
			// Given that we're using strictly automatic methods (slice from array operator, array initialization)
			// We might be able to consider turning off bound-checks.
			xsort.reorder_from_index(slice_work, array_index[:])

			check_stock_sort(slice_work, "Twinsort: (separate reordering)", true, 2, false)
		}
		if (reps > 1)
		{
			fmt.printfln("    Twinsort: as separate calls, generate a sort index then sort on it: %.0f msec.", 
				time.duration_milliseconds(time.since(start)))
		}

		// sort.quick_sort_proc (unstable)
		start = time.now()
		for i in 0 ..< reps
		{
			copy_slice(slice_work, slice_init)
			sort.quick_sort_proc(slice_work, sort_stock_type_f)

			check_stock_sort(slice_work, "sort.quick_sort_proc", true, 1, false)
		}
		if (reps > 1)
		{
			fmt.printfln("    sort.quick_sort_proc: %.0f msec.", 
				time.duration_milliseconds(time.since(start)))
		}

		// Shell sort (batched re-sort) 
		if (nmemb <= 8000) // (see shell_sort_cmp for comments on this)
		{
			start = time.now()
			for r in 0 ..< reps
			{
				copy_slice(slice_work, slice_init)
				xsort.shell_sort_cmp(slice_work, sort_stock_type_f)

				check_stock_sort(slice_work, "Shell sort:", true, 1, false)
			}
			if (reps > 1)
			{
				fmt.printfln("    Shell sort (unstable): standard sort: %.0f msec.", 
					time.duration_milliseconds(time.since(start)))
			}
		}

		// Shell sort (batched re-sort) 
		if (nmemb <= 8000) // (see shell_sort_cmp for comments on this)
		{
			start = time.now()
			for r in 0 ..< reps
			{
				copy_slice(slice_work, slice_init)
				xsort.shell_sort_cmp_batch(slice_work, sort_stock_type_f)

				check_stock_sort(slice_work, "Shell sort: batched sort", true, 1, false)
			}
			if (reps > 1)
			{
				fmt.printfln("    Shell sort (unstable): batched re-sort after reindex: %.0f msec.", 
					time.duration_milliseconds(time.since(start)))
			}
		}
	}
}


/* 
 * Verify that reindexing is operating exactly as specified. 
 * Test forward and backward sorts, stable and unstable sorts, single and combined sorts. Allow the 
 * introduction of an error to test this code.
 */
check_stock_sort_reindex :: proc(stock: []$T, index: []$IT, label: string, forward: bool = true, 
	sort_level: int = 1, printout: bool = false, error_idx: int = -1)
{
	if (len(stock) < 2) do return

	errors := 0

	fmt.printfln("{}:", label)

	// Optional: make an error
	if (error_idx >= 0)
	{
		if (error_idx >= len(stock))
		{
			fmt.printfln("Error requested outside of array. Refusing in disgust!")
			return
		}
		temp := index[error_idx]
		index[error_idx] = index[error_idx-1]
		index[error_idx-1] = temp
	}

	if (forward)
	{
		init_val := -(1 << (size_of(stock[0].type) * 8 - 1))

		// Expectation: Types to be in order. Quantities to be in order by type. ids to be in order
		// by type-quantity pair.
		prev_type := init_val
		prev_number := init_val
		prev_id := init_val

		for j in 0 ..< len(stock)
		{
			if (sort_level < 1) do break // Case of no sort being tested

			if (stock[index[j]].type < prev_type)
			{
				fmt.printfln("Error in index {}: types not in order", j)
				errors += 1
			}
			else if (stock[index[j]].type > prev_type)
			{
				prev_type = stock[index[j]].type
				prev_number = init_val
				prev_id = init_val
			}
			if (sort_level == 1) do continue // Case of sort only on type

			if (sort_level >= 3) // dual-criteria sorts
			{
				if (stock[index[j]].number < prev_number)
				{
					fmt.printfln("Error in index {}: number not in order by type", j)
					errors += 1
				}
				else if (stock[index[j]].number > prev_number)
				{
					prev_id = init_val
				}
			}

			if ((sort_level == 2) || (sort_level == 4)) // Stable sorts
			{
				if (stock[index[j]].id <= prev_id)
				{
					fmt.printfln("Error in index {}: ids not in order by type and number", j)
					errors += 1
				}
			}
			prev_type = stock[index[j]].type
			prev_number = stock[index[j]].number
			prev_id = stock[index[j]].id
		}
	}
	else // reverse
	{
		init_val := (1 << (size_of(stock[0].type) * 8 - 1)) - 1
		
		prev_type := init_val
		prev_number := init_val
		prev_id := -(1 << (size_of(stock[0].type) * 8 - 1))
		
		for j in 0 ..< len(stock)
		{
			if (sort_level < 1) do break // Case of no sort being tested

			if (stock[index[j]].type > prev_type)
			{
				fmt.printfln("Error in index {}: types not in order", j)
				errors += 1
			}
			else if (stock[index[j]].type < prev_type)
			{
				prev_type = stock[index[j]].type
				prev_number = init_val
				prev_id = init_val
			}
			if (sort_level == 1) do continue // Case of sort only on type

			if (sort_level >= 3) // dual-criteria sorts
			{
				if (stock[index[j]].number > prev_number)
				{
					fmt.printfln("Error in index {}: number not in order by type", j)
					errors += 1
				}
				else if (stock[index[j]].number < prev_number)
				{
					prev_id = init_val
				}
			}

			if ((sort_level == 2) || (sort_level == 4)) // Stable sorts
			{
				if (stock[index[j]].id <= prev_id)
				{
					fmt.printfln("Error in index {}: ids not in order by type and number", j)
					errors += 1
				}
			}
			prev_type = stock[index[j]].type
			prev_number = stock[index[j]].number
			prev_id = stock[index[j]].id
		}
	}

	if (errors == 0) 
	{
		if (sort_level == 1) do fmt.printfln("No errors found (checked unstable sort).")
		if (sort_level == 2) do fmt.printfln("No errors found (checked stable sort).")
		if (sort_level == 3) do fmt.printfln("No errors found (checked unstable dual-criteria sort).")
		if (sort_level == 4) do fmt.printfln("No errors found (checked stable dual-criteria sort).")
	}

	if (printout)
	{
		for i in 0 ..< len(stock)
		{
			fmt.printfln("  %2d: {}", i, stock[index[i]])
		}
	}

	fmt.println("")
}


/* 
 * Verify that arrays are reordered from indexes exactly as specified. 
 * Test forward and backward sorts, stable and unstable sorts, single and combined sorts. Allow the 
 * introduction of an error to test this code.
 */
check_stock_sort :: proc(stock: []$T, label: string, forward: bool = true, sort_level: int = 1, printout: bool = false, error_idx: int = -1)
{
	if (len(stock) < 2) do return

	errors := 0

	fmt.printfln("{}:", label)

	// Optional: make an error
	if (error_idx >= 0)
	{
		if (error_idx >= len(stock))
		{
			fmt.printfln("Error requested outside of array. Refusing in disgust!")
			return
		}
		temp := stock[error_idx]
		stock[error_idx] = stock[error_idx-1]
		stock[error_idx-1] = temp
	}

	if (forward)
	{
		init_val := -(1 << (size_of(int) * 8 - 1))

		// Expectation: Types to be in order. Quantities to be in order by type. ids to be in order
		// by type-quantity pair.
		prev_type := init_val
		prev_number := init_val
		prev_id := -1

		for j in 0 ..< len(stock)
		{
			if (sort_level < 1) do break // Case of no sort being tested

			if (stock[j].type < prev_type)
			{
				fmt.printfln("Error in index {}: types not in order", j)
				errors += 1
			}
			else if (stock[j].type > prev_type)
			{
				prev_type = stock[j].type
				prev_number = init_val
				prev_id = init_val
			}
			if (sort_level == 1) do continue // Case of sort only on type

			if (sort_level >= 3) // dual-criteria sorts
			{
				if (stock[j].number < prev_number)
				{
					fmt.printfln("Error in index {}: number not in order by type", j)
					errors += 1
				}
				else if (stock[j].number > prev_number)
				{
					prev_id = init_val
				}
			}

			if ((sort_level == 2) || (sort_level == 4)) // Stable sorts
			{
				if (stock[j].id <= prev_id)
				{
					fmt.printfln("Error in index {}: ids not in order by type and number", j)
					errors += 1
				}
			}
			prev_type = stock[j].type
			prev_number = stock[j].number
			prev_id = stock[j].id
		}
	}
	else // reverse
	{
		init_val := (1 << (size_of(stock[0].type) * 8 - 1)) - 1
		
		prev_type := init_val
		prev_number := init_val
		prev_id := -(1 << (size_of(stock[0].type) * 8 - 1))
		
		for j in 0 ..< len(stock)
		{
			if (sort_level < 1) do break // Case of no sort being tested

			if (stock[j].type > prev_type)
			{
				fmt.printfln("Error in index {}: types not in order", j)
				errors += 1
			}
			else if (stock[j].type < prev_type)
			{
				prev_type = stock[j].type
				prev_number = init_val
				prev_id = init_val
			}
			if (sort_level == 1) do continue // Case of sort only on type

			if (sort_level >= 3) // dual-criteria sorts
			{
				if (stock[j].number > prev_number)
				{
					fmt.printfln("Error in index {}: number not in order by type", j)
					errors += 1
				}
				else if (stock[j].number < prev_number)
				{
					prev_id = init_val
				}
			}

			if ((sort_level == 2) || (sort_level == 4)) // Stable sorts
			{
				if (stock[j].id <= prev_id)
				{
					fmt.printfln("Error in index {}: ids not in order by type and number", j)
					errors += 1
				}
			}
			prev_type = stock[j].type
			prev_number = stock[j].number
			prev_id = stock[j].id
		}
	}

	if (errors == 0) 
	{
		if (sort_level == 1) do fmt.printfln("No errors found (checked unstable sort).")
		if (sort_level == 2) do fmt.printfln("No errors found (checked stable sort).")
		if (sort_level == 3) do fmt.printfln("No errors found (checked unstable dual-criteria sort).")
		if (sort_level == 4) do fmt.printfln("No errors found (checked stable dual-criteria sort).")
	}

	if (printout)
	{
		for i in 0 ..< len(stock)
		{
			fmt.printfln("  %2d: {}", i, stock[i])
		}
	}

	fmt.println("")
}
