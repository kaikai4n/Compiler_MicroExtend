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
int register_count = 0;
int register_status[REGISTER_MAX+1] = {0};
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
%token PROGRAM Begin End DECLARE AS ASSIGN_OP Exit;
%type <vname> v_name;
%type <dint> v_list;
%type <symb> expression;
%type <symb> mul_expression;
%type <symb> primary;
%type <symb> name_or_array_name;

%%
start:	PROGRAM NAME Begin statement_list End	{ fprintf(stderr, "Finish Program with name: %s\n", $2->name); }
     ; 

statement_list:	statement ';'
			  | statement_list statement ';'
			  ;

statement:	declare_statement
		 |	assign_statement
		 |	exit_statement
		 ;

declare_statement: DECLARE v_list AS TYPE	{
		for(int i = 0; i < my_vlist.total_num; i++){
			if(my_vlist.table[i].array_num == -1){
				generate(3, "Declare", my_vlist.table[i].name, num_to_type[$4-1], NULL);
				new_symtab(my_vlist.table[i].name);
			}else{
				if(my_vlist.table[i].array_num < 2){
					yyerror("Array size must > 1\n");
					exit(-1);
				}
				char name_3[VAR_NAME_MAX];
				sprintf(name_3, "%d", my_vlist.table[i].array_num);
				generate(4, "Declare", my_vlist.table[i].name, num_to_type[$4-1], name_3);
				
				char this_array_name[VAR_NAME_MAX];
				for(int array_i = 0; array_i < my_vlist.table[i].array_num; array_i ++){
					sprintf(this_array_name, "%s[%d]", my_vlist.table[i].name, array_i);
					new_symtab(this_array_name);
				}
			}
		}
		reset_vlist();
	}

v_list:	v_name	{
				insert_vlist($1);
			}
	  |	v_list ',' v_name	{
				insert_vlist($3);
			}
	  ;

v_name: ARRAY_NAME	{
				$$ = $1;	
			}
	  |	NAME	{
				$$->name = strdup($1->name);
				$$->array_num = -1;
			}
	  ;

assign_statement:	name_or_array_name ASSIGN_OP expression	{
						generate(3, "F_STORE", $3->name, $1->name, NULL);
						$1->value = $3->value;
						free_register($3);
					}
				;

expression:	expression '+' mul_expression	{
					$$ = new_register();
					$$->value = $1->value + $3->value;
					fprintf(stderr, "exp: exp + mul_exp\t%lf = %lf + %lf\n", $$->value, $1->value, $3->value);
					generate(4, "F_ADD", $1->name, $3->name, $$->name);
					free_register($1);
					free_register($3);
				}
			  |	expression '-' mul_expression	{
					$$ = new_register();
					$$->value = $1->value - $3->value;
					fprintf(stderr, "exp: exp - mul_exp\t%lf = %lf - %lf\n", $$->value, $1->value, $3->value);
					generate(4, "F_SUB", $1->name, $3->name, $$->name);
					free_register($1);
					free_register($3);
				}
			  |	mul_expression	{
					$$ = $1;
					fprintf(stderr, "exp: mul_exp\t%lf = %lf\n", $$->value, $1->value);
				}
			  ;

mul_expression:	mul_expression '*' primary	{
					$$ = new_register();
					$$->value = $1->value * $3->value;
					fprintf(stderr, "mul_exp: mul_exp * NUMBER\t%lf = %lf * %lf\n", $$->value, $1->value, $3->value);
					generate(4, "F_MUL", $1->name, $3->name, $$->name);
					free_register($1);
					free_register($3);
				}
			  | mul_expression '/' primary	{
					$$ = new_register();
					$$->value = $1->value / $3->value;
					fprintf(stderr, "mul_exp: mul_exp / NUMBER\t%lf = %lf / %lf\n", $$->value, $1->value, $3->value);
					generate(4, "F_DIV", $1->name, $3->name, $$->name);
					free_register($1);
					free_register($3);
				}
			  |	primary	{
					$$ = $1;
					fprintf(stderr, "mul_exp: NUMBER\t%lf = %lf\n", $$->value, $1->value);
				}
			  ;

primary:	NUMBER	{
			$$ = new_register();
			$$->value = $1;
			fprintf(stderr, "Declare a new register: %s and assign value: %lf\n", $$->name, $$->value);
			char name_1[VAR_NAME_MAX];
			sprintf(name_1, "%lf", $1);
			generate(3, "F_STORE", name_1, $$->name, NULL);
		}
	   |	'-' primary	{
			$$ = new_register();
			$$->value = -$2->value;
			fprintf(stderr, "primary: - primary\t%lf = %lf\n", $$->value, $2->value);
			generate(3, "F_UMINUS", $2->name, $$->name, NULL);
		}
	   |	'(' expression ')'	{
			$$ = $2;
			fprintf(stderr, "primary: ( expression )\t remove expression\n");
		}
	   |	name_or_array_name	{
			$$ = $1;
		}
	   ;

name_or_array_name:	NAME	{
						struct symtab *sp = check_symtab($1->name);
						if(sp == NULL){
							// Must Declare before reference
							char error_msg[1000];
							sprintf(error_msg, "Variable %s reference before declaration\n", $1->name);
							yyerror(error_msg);
							exit(-1);
						}
						free($1->name);
						free($1);
						$$ = sp;
						fprintf(stderr, "primary: NAME\n");
					}
				  |	ARRAY_NAME	{
						char this_array_name[VAR_NAME_MAX];
						sprintf(this_array_name, "%s[0]", $1->name);
						struct symtab *sp = check_symtab(this_array_name);
						if(sp == NULL){
							// Must Declare before reference
							char error_msg[1000];
							sprintf(error_msg, "Variable %s reference before declaration\n", $1->name);
							yyerror(error_msg);
							exit(-1);
						}
						sprintf(this_array_name, "%s[%d]", $1->name, $1->array_num);
						sp = check_symtab(this_array_name);
						if(sp == NULL){
							// Array index too large
							char error_msg[1000];
							sprintf(error_msg, "Array %s index %d out of bound.\n", $1->name, $1->array_num);
							yyerror(error_msg);
							exit(-1);
						}
						$$ = sp;
						fprintf(stderr, "primary: ARRAY_NAME\t(%s=%lf)\n", this_array_name, sp->value);
						free($1->name);
						free($1);
					}
				  ;

exit_statement:	Exit '(' NUMBER ')'	{
					clean_up($3);
					exit(0);
				}
			  ;
%%

struct symtab *new_symtab(char *s){
	struct symtab *sp;
	
	for(sp = my_symtab; sp < &my_symtab[NSYMS]; sp++) {
		if(sp->name && !strcmp(sp->name, s)){
			char error_msg[VAR_NAME_MAX+100];
			sprintf(error_msg, "In new_symtab: Already defined variable %s\n", sp->name);
			yyerror(error_msg);
			exit(-1);
		}
		if(!sp->name) {
			sp->name = strdup(s);
			sp->value = 0;
			return sp;
		}
	}
	yyerror("In new_symlook: Too many variables, cannot define new variable.");
	exit(-1);
}

struct symtab* check_symtab(char *s){
	struct symtab *sp;
	for(sp = my_symtab; sp < &my_symtab[NSYMS]; sp++) {
		if(sp->name && !strcmp(sp->name, s))
			return sp;
	}
	return NULL;
}

struct symtab *new_register(){
	int free_register_index = 1;
	for(; free_register_index < REGISTER_MAX+1; free_register_index ++){
		if(register_status[free_register_index] == 0)
			break;
	}
	if(free_register_index > REGISTER_MAX){
		yyerror("In new_register: Register not enough!! Program Exit.");
		exit(-1);
	}
	register_status[free_register_index] = 1;
	register_count ++;
	char register_name[VAR_NAME_MAX];
	sprintf(register_name, "T&%d", free_register_index);
	struct symtab *sp = new_symtab(register_name);
	return sp;
}

void free_symtab(struct symtab *tp){
	struct symtab *sp;
	for(sp = my_symtab; sp < &my_symtab[NSYMS]; sp++) {
		if(sp->name != NULL && sp == tp){
			fprintf(stderr, "Free variable %s\n", sp->name);
			free(sp->name);
			sp->name = NULL;
			return;
		}
	}
	fprintf(stderr, "Cannot find variable %s to free.\n", sp->name);
	exit(-1);
}

void free_register(struct symtab *sp){
	// clear unused register;
	int register_index = atoi(&(sp->name[2]));
	fprintf(stderr, "Free register: %s\n", sp->name);
	register_status[register_index] = 0;
	register_count --;
	free_symtab(sp);
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
	my_vlist.table[i_now].name = strdup(vname->name);
	my_vlist.table[i_now].array_num = vname->array_num;
	my_vlist.total_num ++;
}

void generate(int length, char *instruction, char *name_1, char *name_2, char *name_3){
	if(length < 1 || length > 4){
		yyerror("In generate: Generate function error, input length should between 1 and 4\n");
		exit(-1);
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

void clean_up(int status){
	if(status < 0)
		fprintf(stderr, "Program exited unexpectedly with status: %d\n", status);
	else
		fprintf(stderr, "Program ended\n");
}
