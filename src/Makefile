.PHONY: all

all: compiler
    
compiler: lex.yy.c y.tab.c
	gcc lex.yy.c y.tab.c -ly -ll -o compiler

lex.yy.c: scanner.l
	lex scanner.l

y.tab.c: parser.y
	yacc -d parser.y

run:
	./compiler < ../data/testfile.micro 2> /dev/null

clean:
	rm lex.yy.c y.tab.c y.tab.h compiler 
