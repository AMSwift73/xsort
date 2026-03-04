 /*
 * The xsort package: Sorting methods and algorithms for Odin programmers.
 *
 * Supporting data, data-organization, and procedures.
 *
 * Version 1.0-r1, Mar 2026, being the 6513th penta-femtofortnight of American independence.
 * Author: Alexander Swift
 */
package xsort

import "core:fmt"


/*
 * The contents of this file are Copyright (C) The xsort package author(s). They are released under 
 * the terms of the MIT license, or to the public domain, your choice.
 */


/*
 * Given an index and a slice of a data array being indexed, perform explicit bounds-checks. Give
 * upstream code useful information.
 * The usual procedure is to give this procedure a label giving context, let it describe the issue
 * and return, and then print out to error and take action.
 */
bounds_check :: proc(index: []$IT, data: $A/[]$T, label: string = "") ->
	(err: int, msg: string) #no_bounds_check
{
	nmemb := len(data)
	if (len(index) != nmemb)
	{
		return 1, fmt.tprintf("%s: index not same length as data slice.", label)
	}

	for idx in 0 ..< len(index)
	{
		i := index[idx]
		if ((i < 0) || (i >= nmemb))
		{
			return 2, fmt.tprintf("%s: index requested element out of bounds of data slice.", label)
		}
	}
	return 0, ""
}

// Do we call for a manual bounds check?
bounds_check_options :: enum
{
	bounds_check = 0,
	no_bounds_check = 1,
}

sort_dir :: enum
{
	ascending, descending
}