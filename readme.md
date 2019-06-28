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

# Micro/Ex functions
## Declare Statement
- Declare var_list As type ;
	- var_list: a list of variables seperated by comma
		- variables: variable or array variable
	- type: Integer or Float
- For example:
```=
	Declare a, arr[100] as float;
```
The compiler should generate the assembly code:
```=
	Declare a, Float
	Declare arr, Float_array, 100
```

## Assignment Statement
- var := expression ;
	- var: the assigned variable should be declared before use, otherwise error message would show.
	- expression: support +, -, *, / with precedence, also parenthesis can be use to have higher precedence.
- For example:
```=
	arr[0] := 1;
	arr[1] := 2;
	a := -arr[0] + arr[1] * (arr[0] + arr[1]);
```
The compiler should generate the assembly code:
```=
	F_STORE 1, arr[0]
	F_STORE 2, arr[1]
	F_UMINUS arr[0], T&1
	F_ADD arr[0], arr[1], T&2
	F_MUL arr[1], T&2, T&3
	F_ADD T&1, T&3, T&2
	F_STORE T&2, a
```
Note that ``T&[number]`` is free register.

## For Loop Statement
- FOR (var := expression to expression) statement_list ENDFOR
	- expression: returns a variable name or number in literal
	- statement_list: a sequence of statements including all the statements.
	- to: TO (increment by 1) or DOWNTO (decrease by 1)
- For example:
```=
	Declare i, sum as Integer;
	sum := 0;
	FOR ( i := 1 TO 10 ) 
		sum := sum + i;
	ENDFOR
```
The compiler should generate the assembly code:
```=
	Declare i, Integer
	Declare sum, Integer
	I_STORE 0, sum
	I_STORE 1, i
lb&1:	I_ADD sum, i, T&1
	I_STORE T&1, sum
	INC i
	I_CMP i, 10
	JL lb&1
```	

## If Else Statement
- IF ( comparison_expression ) THEN statement_list ENDIF
- IF ( comparison_expression ) THEN statement_list ELSE statement_list ENDIF
	- comparison_expression: support <, >, <=, >=, ==, != of logical operator
- For example:
```=
	IF ( sum > 50 ) THEN
		print ( sum );
	ELSE
		print( a );
	ENDIF
```
The compiler should generate the assembly code:
```=
	I_CMP sum, 50
	JLE lb&2
	CALL print, sum
	J lb&3
lb&2:	CALL print, a
lb&3:
```
