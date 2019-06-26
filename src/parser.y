%{
#include "header.h"
#include "y.tab.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
void yyerror(s) char *s;
{
    fprintf(stderr, "%s\n", s);
}

int yylex (void);
char num_to_type[2][10] = {"Integer", "Float"};
int line_count = 1;
%}

%union {
    double dval;
    struct symtab *symb;
	int dint;
	struct v_name *vname;
}

%token <symb> NAME;
%token <vname> ARRAY_NAME;
%token <dval> NUMBER;
%token <dint> TYPE;
%token PROGRAM Begin End DECLARE AS ASSIGN_OP;
%type <vname> v_name;
%type <dint> v_list;
%type <dval> expression;
%type <dval> mul_expression;

%%
start:	PROGRAM NAME Begin statement_list End	{ fprintf(stderr, "Finish Program with name: %s\n", $2->name); }
     ; 

statement_list:	statement ';'
			  | statement_list statement ';'
			  ;

statement:	declare_statement
		 |	assign_statement
		 ;

declare_statement: DECLARE v_list AS TYPE	{
		for(int i = 0; i < my_vlist.total_num; i++){
			if(my_vlist.table[i].array_num == 0){
				generate(3, "Declare", my_vlist.table[i].name, num_to_type[$4-1], NULL);
			}else{
				char name_3[100];
				sprintf(name_3, "%d", my_vlist.table[i].array_num);
				generate(4, "Declare", my_vlist.table[i].name, num_to_type[$4-1], name_3);
			}
		}
		reset_vlist();
	}

v_list:	v_name	{
				insert_vlist($1);
			}
	  |	v_list ',' v_name	{
				insert_vlist($3);
				/*
				printf("my_vlist\n");
				for(int i = 0; i < my_vlist.total_num; i++){
					printf("%d: name = %s, array_num = %d\n", i+1, my_vlist.table[i].name, my_vlist.table[i].array_num);
				}
				*/
			}
	  ;

v_name: ARRAY_NAME	{
				$$ = $1;	
			}
	  |	NAME	{
				$$->name = $1->name;
				$$->array_num = 0;
			}
	  ;

assign_statement:	NAME ASSIGN_OP expression;

expression:	expression '+' mul_expression	{
					$$ = $1 + $3;
					fprintf(stderr, "exp: exp + mul_exp\t%f = %f + %f\n", $$, $1, $3);
				}
			  |	expression '-' mul_expression	{
					$$ = $1 - $3;
					fprintf(stderr, "exp: exp - mul_exp\t%f = %f - %f\n", $$, $1, $3);
				}
			  |	mul_expression	{
					$$ = $1;
					fprintf(stderr, "exp: mul_exp\t%f = %f\n", $$, $1);
				}
			  ;

mul_expression:	mul_expression '*' NUMBER	{
					$$ = $1 * $3;
					fprintf(stderr, "mul_exp: mul_exp * NUMBER\t%f = %f * %f\n", $$, $1, $3);
				}
			  | mul_expression '/' NUMBER	{
					$$ = $1 / $3;
					fprintf(stderr, "mul_exp: mul_exp / NUMBER\t%f = %f / %f\n", $$, $1, $3);
				}
			  |	NUMBER	{
					$$ = $1;
					fprintf(stderr, "mul_exp: NUMBER\t%f = %f\n", $$, $1);
				}
			  ;
%%

struct symtab *symlook(char *s){
	char *p;
	struct symtab *sp;
	
	for(sp = my_symtab; sp < &my_symtab[NSYMS]; sp++) {
		if(sp->name && !strcmp(sp->name, s))
			return sp;
		if(!sp->name) {
			sp->name = strdup(s);
			return sp;
		}
	}
	yyerror("Too many symbols");
	exit(1);
} 

void reset_vlist(void){
	/*
	for(int i = 0; i < my_vlist.total_num; i++){
		if(my_vlist.table[i].name != NULL)
			free(my_vlist.table[i].name);
		my_vlist.table[i].array_num = 0;
	}
	*/
	my_vlist.total_num = 0;
}

void insert_vlist(struct v_name *vname){
	int i_now = my_vlist.total_num;
	my_vlist.table[i_now].name = vname->name;
	my_vlist.table[i_now].array_num = vname->array_num;
	my_vlist.total_num ++;
}

void generate(int length, char *instruction, char *name_1, char *name_2, char *name_3){
	if(length < 1 || length > 4){
		yyerror("Generate function error, input length should between 1 and 4\n");
	}else if(length == 1){
		// This is label
		printf("%s:", instruction);
	}else{
		if(length == 2){
			printf("\t%s %s\n", instruction, name_1);
		}else if(length == 3){
			printf("\t%s %s, %s\n", instruction, name_1, name_2);
		}else if(length == 4){
			printf("\t%s %s, %s, %s\n", instruction, name_1, name_2, name_3);
		}
	}
}
