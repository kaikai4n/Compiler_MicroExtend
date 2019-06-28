Compiler Micro/Ex
===

# Environment
- mac OS
- bison (GNU Bison) 2.3
- flex 2.5.35 Apple(flex-31)
- gcc version
	- Configured with: --prefix=/Library/Developer/CommandLineTools/usr --with-gxx-include-dir=/usr/include/c++/4.2.1
	- Apple LLVM version 10.0.0 (clang-1000.10.44.4)
	- Target: x86\_64-apple-darwin17.7.0
	- Thread model: posix

# How to run
- Change directory into ``src``
- ```=
	make 
	make run
```
- The results are shown with stdout
- To run with or without stderr message:
```=
	./compiler < $input 
	./compiler < $input 2> /dev/null
```
- The demo input is ``data/testfile.micro``, output is ``data/testfile.out``.

# Micro/Ex function
## Declare Statement

## Assignment Statement

## For Loop Statement

## If Else Statement
