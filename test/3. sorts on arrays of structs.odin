/*
 * Date: Mar 2026, being the 6513th penta-femtofortnight of American independence.
 * Author: Alexander M. Swift
 *
 * Supply a set of sorting procedures accepting a custom comparator, then combine them into stable 
 * and unstable options enabling efficient use with arrays-of-structures (as well as simple 
 * numerics). Structures-of-Arrays are considered in test suite #3.
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

// For discussion of single-condition comparators, see test suit #1, testing of comparators.

// We also want to perform a dual sort. This is a naive effort: the if-statement makes it 
// very slow.
sort_stock_dual_if_f :: proc(a, b: stock) -> int
{
	// Primary sort: type. Secondary sort: number. Sort ascending.
	if (a.type != b.type)
	{
		return (int(a.type > b.type) - int(a.type < b.type))
	}
	return (int(a.number > b.number) - int(a.number < b.number))
}

// Doing the sorts in succession is actually noticeably faster - but we can, sometimes, do better.
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

// We-unify and use the ol' "shift and add" trick. This roughly doubles overall sort speed over the naive method.
// (Is only certain to work if data ranges (as actually expressed in the data) each fit in <= i32.)
sort_stock_unified_f :: proc(a, b: stock) -> int
{
	a_value : i64 = i64(a.type << 32) + i64(a.number)
	b_value : i64 = i64(b.type << 32) + i64(b.number)
	//return (a_value < b_value) ? 0 : 1
	return (int(a_value > b_value) - int(a_value < b_value))
}
sort_stock_unified_r :: proc(a, b: stock) -> int
{
	a_value : i64 = i64(a.type << 32) + i64(a.number)
	b_value : i64 = i64(b.type << 32) + i64(b.number)
	//return (a_value > b_value) ? 0 : 1
	return (int(a_value < b_value) - int(a_value > b_value))
}


stock :: struct
{
	type: int,
	number: int,
	id: int,
}


/*
 *     Check that insertion sort and twinsort are, as implemented in the Odin xsort library, stable 
 * sorts that maintain the relative order of equal-value inputs. (Confirm that shell sort and some 
 * other algorithms are unstable.)
 *
 *     Demonstrate the utility of a stable sort by performing a primary and secondary sort in a 
 * single pass on an array-of-structs without reordering equal elements.
 *
 * Useful parameters: usually, none (the length of the array may be specified)
 * -AMS-
 */
main :: proc()
{
	single := true
	dual := true
	nmemb := 20
	reps := 1 // Always 1. See test #4.

	seed : u64 = 0 // randomize to better catch errors

	ok: bool
	i: int

    // Accept command-line arguments to modify test parameters
    for i in 1 ..< len(os.args)
    {
        switch i 
        {
            case 1:
                nmemb, ok = strconv.parse_int(os.args[1]); assert(ok)
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

	// Consistent pseudo-random numbers
	if (seed == 0) do seed = u64(time.now()._nsec)
	rand.reset(seed)

	// Set up the initialization array
	for i := 0; i < len(array_init); i += 1
	{
		array_init[i].id = i
		array_init[i].type = rand.int_range(1, 4) // 1, 2 or 3
		array_init[i].number = rand.int_range(1, 4) // same
	}

    // Initialize the working array (paranoia)
    copy_slice(slice_work, slice_init)

	// Verify
	// fmt.println("Initial:")
	// for i in 0 ..< len(array_work) do fmt.printfln("  %2d: {}", i, array_work[i])
	// fmt.println("")

	start : time.Time

	// Introduce ourselves
	fmt.printfln("For each sorting method, initialize, sort, and check the correctness of an array[%d] of %d-byte structs.", 
		nmemb, size_of(stock))

	if (single)
	{
		// Single-criterion sorts
		fmt.printfln("Phase 1: Single-criterion sorts on stock type")

		// Stable sorts
		fmt.printfln("  Stable sorts:")

		// Insertion sort (stable) - only if array is small
		if (nmemb <= 500)
		{
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp(slice_work, sort_stock_type_f)
			// Note: we're only checking the ordering of type at this stage.
			check_stock_sort(slice_work, "xsort.insertion_sort_cmp", true, 2, false)
		}

		// // Twin sort (stable)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp(slice_work, sort_stock_type_f)
		check_stock_sort(slice_work, "xsort.twinsort_cmp", true, 2, false)

		// sort.merge_sort_proc (stable) on slice - only if array is reasonably small
		if (nmemb <= 1000)
		{
			copy_slice(slice_work, slice_init)
			sort.merge_sort_proc(slice_work, sort_stock_type_f)
			check_stock_sort(slice_work, "sort.merge_sort_proc", true, 2, false)
		}


		// Unstable sorts
		fmt.printfln("  Unstable sorts:")

		// Shell sort (unstable)
		// Shell sort can absolutely handle arrays with many more elements, but enabling it to do so 
		// has trade-offs. See xsort.shell_sort_cmp()
		if (nmemb <= 8000)
		{
			copy_slice(slice_work, slice_init)
			xsort.shell_sort_cmp(slice_work, sort_stock_type_f)
			check_stock_sort(slice_work, "xsort.shell_sort_cmp", true, 1, false)
		}

		// sort.quick_sort_proc (unstable) on slice
		copy_slice(slice_work, slice_init)
		sort.quick_sort_proc(slice_work, sort_stock_type_f)
		check_stock_sort(slice_work, "sort.quick_sort_proc", true, 1, false)

		// slice.sort_by(), using the smoothsort algorithm (unstable) is simply not competitive with 
		// quicksort.
		// Same comment applies also to every other algorithm in the standard library, as far as I 
		// can tell at any rate, with the vital exception of insertion sort on small arrays, and the 
		// dubious case of mergesort (stable).
	}

	if (dual)
	{
		// Dual-criteria sorts
		fmt.printfln("\nPhase 2: Dual-criteria sorts on stock type, then number. If the sort is stable, we also expect ids to be in order for each type-number pair.")

		// Stable sorts
		fmt.printfln("  Stable sorts:")

		// Insertion sort (stable) - only if array is small
		if (nmemb <= 500)
		{
			copy_slice(slice_work, slice_init)
			xsort.insertion_sort_cmp(slice_work, sort_stock_unified_f)

			// We are now checking everything. We expect type to be in order, number to be in order
			// by type, and ids to be in order by type and number.
			check_stock_sort(slice_work, "xsort.insertion_sort_cmp", true, 4, false)
		}

		// Twin sort (stable)
		copy_slice(slice_work, slice_init)
		xsort.twinsort_cmp(slice_work, sort_stock_unified_f)
		check_stock_sort(slice_work, "xsort.twinsort_cmp", true, 4, false)

		// sort.merge_sort_proc (stable) on slice - only if array is reasonably small
		if (nmemb <= 1000)
		{
			copy_slice(slice_work, slice_init)
			sort.merge_sort_proc(slice_work, sort_stock_unified_f)
			check_stock_sort(slice_work, "sort.merge_sort_proc", true, 4, false)
		}


		// Unstable sorts
		fmt.printfln("  Unstable sorts:")

		// Shell sort
		copy_slice(slice_work, slice_init)
		xsort.shell_sort_cmp(slice_work, sort_stock_unified_f)

		// We expect types to be in order, number to be in order by type (because the comparator 
		// gives them a distinct value), but ids need not be in order by type and number.
		check_stock_sort(slice_work, "xsort.shell_sort_cmp", true, 3, false)
		
		// sort.quick_sort_proc (unstable) on slice
		copy_slice(slice_work, slice_init)
		sort.quick_sort_proc(slice_work, sort_stock_unified_f)
		check_stock_sort(slice_work, "sort.quick_sort_proc", true, 3, false)
	}
}


/* 
 * Verify that we are sorting exactly as specified. Test forward and backward sorts, stable and 
 * unstable sorts. Allow the introduction of an error to test this code.
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
		init_val := -(1 << (size_of(stock[0].type) * 8 - 1))

		// Expectation: Types to be in order. Quantities to be in order by type. ids to be in order
		// by type-quantity pair.
		prev_type := init_val
		prev_number := init_val
		prev_id := init_val

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
