# The xsort ("external lib, sort") package: Sorting algorithms for Odin programmers.
Version 1.0, Release Candidate 1
Mar 2026, being the 6513th penta-femtofortnight of American independence.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;This package may be of help to you in the reordering of arrays of numeric primitives, arrays of structures (SoA) (and similar), and with structures-of-arrays (SoA). It does not currently assist with the sorting of strings, or with non-array datatypes (maps, trees, etc.).  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;All code in xsort is made available under the terms of the MIT license, unless specified otherwise.

### "But my project is not in Odin?"
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;No worries. Treat the code here as pseudo-code, similar to straightforward C and with additional (hopefully helpful) comments. Grab the simple Odin compiler and you get demos too. That'll all help you in your own porting.

### "What's in this library?"
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;The first - and for many developers the primary - thing you gain with xsort are sorting functions that automatically select reasonable algorithms and methods based on number of array elements and (where important) element size. There are four of them, one each for the major use-cases of this library:  
1. Sort an array of any numeric type, forward, or backwards. Call `xsort.sort()`.
2. Sort an array of numbers or structs, using a custom comparator. Select stable or unstable sorts: the former preserves the relative ordering of equal-value elements; the latter sometimes offers speed improvements. Call `xsort.sort_cmp_unstable()` (which means "give me sort speed, on any array size, with any size of array elements.")
3. Do the same, but require that only stable sorts (those that preserve the ordering of equal-value elements) be considered. Call `xsort.sort_cmp_stable()`.
4. Generate a sort index on an array, then use it to either:
	- sort that or similar arrays, or to 
	- treat that array as though it were sorted.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Batched sorts combine these steps and are particularly efficient on arrays of large structs. They are automatically considered for use by the general-purpose sorting functions above. To call them explicitly, invoke `xsort.twinsort_cmp_batched()` and friends.
Unbatched sorts give you maximal power and flexibility and are the go-to option when saving sorts, developing multi-parameter sorts, and when sorting structures-of-arrays (SoAs). Call `xsort.gen_sorted_index_stable()`, then `reorder_from_index()`.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;All of the above benefits from a small and simple, but also fine-tuned, collection of sorting algorithms, including insertion sort, optimized shellsort, and LSD radix sort. However, the standout performer among them is undeniably Igor van den Hoven's twinsort, a stable sort that can equal the speed of a quicksort within a wide range of array sizes (~30 < elements < ~1000k).  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;If you need to optimize for a particular use-case, the first step is to start calling these directly: `insertion_sort_cmp()` and friends.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;What Odin developers see first with xsort is convenience. Then performance. Then flexibility and power. Yet perhaps what you will end up appreciating most is dependability: you may depend on the general-purpose sorting calls here to slow down less as you increase data size (especially structure size) than they do in many other libraries. They stay "good enough" for longer - especially when stable sorts are needed - maintaining application performance and interface responsiveness.

### "How do I use and test this library?"
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Download the repository. Rename it to xsort (so, <location>/xsort/xsort.odin). Then, do one of three things:
1. Use the library in your project. Place the xsort folder as a sub-folder of your source directory and use `import "xsort"` statements, or 
2. Place it in your user library directory (if you have set up your development environment to find it), or (if not)
3. Place the xsort folder in <Odin dir>/shared.  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;If you do this, then the file structure will be <odin dir>/shared/xsort, and your import statement will be `import "shared:xsort"`

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Testing is also uncomplicated.  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;In the xsort folder is a test folder. Copy one of the test files to your project source directory and compile (no need to rename).  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`odin build . -debug -out:..\xsort-d.exe` or  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`odin build . -o:speed -out:..\xsort.exe`  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;If not on Windows, change the "\" and lose the ".exe" and that should be enough (TODO: verify this).  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;All of the test suites automatically do something when run. However, to get full value out of several of them, you will want to pass parameters.  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Parameters: See the main procedure of each file for details, but length of array, repetitions, data pattern, and randomizer seed are often configurable.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;For usage, consult guide.txt. It may be read as you review or run one or more of the .odin files in the test directory.

### A note on suggestions, etc.:
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;I am not set up to be a particularly active maintainer of this or any library; life responsibilities are certain to call me well away this year. Thoughts, suggestions, and even code are each of them welcome, but you may find me a slow correspondent - for which I can only apologize in advance.

Respectfully yours,  
Alexander Swift
