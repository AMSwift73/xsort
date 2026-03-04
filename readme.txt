
The xsort ("external lib, sort") package: Sorting algorithms for Odin programmers.
Version 1.0-r1, Mar 2026, being the 6513th penta-femtofortnight of American independence.

	This package may be of help to you in the reordering of arrays of numeric primitives, arrays of structures (SoA) (and similar), and with structures-of-arrays (SOA). It does not currently assist with the sorting of strings, or with non-array datatypes (maps, trees, etc.).
	All code in xsort is made available under the terms of the MIT license, unless specified otherwise.

"But my project is not in Odin?"
	No worries. Treat the code here as pseudo-code, similar to straightforward C, with additional (hopefully helpful) comments. Grab the simple Odin compiler and you get demos too. That'll all help you in your own porting.

"What's in this library?"
	The first - and for many developers the primary - thing you gain with xsort are sorting functions that automatically select reasonable algorithms and methods based on number of array elements and (where important) element size. There are four of them, one each for the major use-cases of this library:
	1. Sort an array of any numeric type, forward, or backwards. Call "xsort.sort()".
	2. Sort an array of numbers or structs, using a custom comparator. Select stable or unstable sorts: the former preserves the relative ordering of equal-value elements; the latter sometimes offers speed improvements. Call "xsort.sort_cmp_unstable()" (which means "give me sort speed, on any array size, with any size of array elements.")
	3. Do the same, but require that only stable sorts (those that preserve the ordering of equal-value elements) be considered. Call "xsort.sort_cmp_stable()".
	4. Generate a sort index on an array, then use it to either:
		A. sort that or similar arrays, or to 
		B. treat that array as though it were sorted. 
		Batched sorts combine these steps and are particularly efficient on arrays of large structs. They are automatically considered for use by the general-purpose sorting functions above. To call them explicitly, invoke "xsort.twinsort_cmp_batched()" and friends.
		Unbatched sorts give you maximal power and flexibility and are the go-to option when saving sorts, developing multi-parameter sorts, and when sorting structures-of-arrays (SoAs). Call "xsort.gen_sorted_index_stable()", then "reorder_from_index()".

		All of the above benefits from a small and simple, but also fine-tuned collection of sorting algorithms, including insertion sort, optimized shellsort, and LSD radix sort. However, the standout performer among them is undeniably Igor van den Hoven's twinsort, a stable sort that can outcompete an (unstable) quicksort within a wide range of array sizes (~30 < elements < ~1000k).
	If you need to optimize for a particular use-case, the first step is to start calling these directly: "insertion_sort_cmp()" and friends.

	What developers see first with xsort is convenience. Then performance. Then flexibility and power. Yet perhaps what you will end up appreciating most is dependability: you may depend on the general-purpose sorting calls here to slow down less as you increase data size (especially structure size) than they do in many other libraries. They stay "good enough" for longer - especially when stable sorts are needed - maintaining application performance and interface responsiveness.


"How do I use and test this library?"
	Usage is simple. Do one of three things:
	1. Use the library in your project. Place the xsort folder as a sub-folder of your source directory and use (import "xsort") statements, or
	2. Place it in your user library directory (if you have set up your development environment to find it), or (if not)
	3. Place the xsort folder in <Odin dir>/shared.
		If you do this, then the file structure will be <odin dir>/shared/xsort, and your import statements will be similar to (import "shared:xsort".)

	Testing is also uncomplicated.
	All the xsort library code lives in <project source dir>/xsort. All the testing and demonstration code lives in /test. Copy one of the test files to <src> and compile with (on Windows) either 
	"odin build . -debug -out:..\xsort-d.exe" or "odin build . -o:speed -out:..\xsort.exe"
	If not on Windows, change the "\" and lose the ".exe" and that should be enough (verify this).
	All of the test suites automatically do something when run. However, to get full value out of several of them, you will want to pass parameters.
	Parameters: 1) Number of elements in the array. 2) Number of times to perform the tests. When verifying, use 1. 3) (only on test #2). Data pattern to fill the array with. and 3 or 4) Random number seed.
	See the main proc of each file for details.


	For usage, consult /xsort/guide.txt. It can be read as you run one or more of the .odin files in the test directory.
