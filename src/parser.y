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
int max_register = 0;
int register_status[REGISTER_MAX+1] = {0};
int forloop_statement_valid = 1;	/*define the for loop condition validity*/
int label_count = 0;
int label_status[LABEL_MAX+1] = {0};
int print_statements[STMT_SCOPE_MAX] = {0};
%}

%union {
    double dval;
    struct symtab *symb;
	int dint;
	struct v_name *vname;
	struct forhead *forhead;
}

%token <symb> NAME;
%token <vname> ARRAY_NAME;
%token <vname> ARRAY_VAR_NAME;
%token <dval> NUMBER;
%token <dint> TYPE;
%token PROGRAM Begin End DECLARE AS ASSIGN_OP Exit;
%token FOR ENDFOR TO DOWNTO;
%type <symb> program;
%type <vname> v_name;
%type <dint> v_list;
%type <symb> expression;
%type <symb> mul_expression;
%type <symb> primary;
%type <symb> name_or_array_name;
%type <dint> to;	/*boolean: 0 is TO, 1 is DOWNTO*/
%type <forhead> for_head;

%%
start:	program Begin statement_list_origin End	{ 
			fprintf(stderr, "Finish Program with name: %s\n", $1->name); 
			char this_register_name[100+REGISTER_MAX];
			for(int reg_i = 1; reg_i <= max_register; reg_i ++){
				sprintf(this_register_name, "T&%d", reg_i);
				generate(3, "Declare", this_register_name, "Float", NULL);
			}
		}
     ; 

program:	PROGRAM NAME	{
			$$ = $2;
			generate(2, "START", $2->name, NULL, NULL);
			add_statement_list(1);
		}
	   ;

statement_list_origin:	statement_list	{
							end_statement_list();
						}
					 ;

statement_list:	statement ';'
			  | statement_list statement ';'
			  |	statement_list forloop_statement	/*with no ';' ended*/
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
				  |	ARRAY_VAR_NAME	{
						int lb, rb;
						char *ori_name = strdup($1->name);
						for(lb = 0; lb < strlen(ori_name); lb++){
							if($1->name[lb] == '['){
								$1->name[lb] = '\0';
								lb ++;
								break;
							}
						}
						for(rb = lb; rb < strlen(ori_name); rb++){
							if($1->name[rb] == ']'){
								$1->name[rb] = '\0';
								break;
							}
						}
						char checked_var_name[VAR_NAME_MAX+10];
						sprintf(checked_var_name, "%s[0]", $1->name);
						if(check_symtab(checked_var_name) == NULL || check_symtab(&($1->name[lb])) == NULL){
							if(check_symtab(&($1->name[lb])) == NULL)
								fprintf(stderr, "Hello: %s\n", &($1->name[lb]));
							// Variable reference before declaration
							char error_msg[1000];
							sprintf(error_msg, "Variable %s reference before declaration\n", ori_name);
							yyerror(error_msg);
							exit(-1);
						}
						$$ = (struct symtab*) malloc(sizeof(struct symtab));
						$$->name = ori_name;
						$$->value = 0;
					}
				  ;

forloop_statement:	FOR for_head statement_list_origin ENDFOR	{
						if($2->forloop_valid == 0){
							// Do not print anything
						}else{
							if($2->to == 0){
								// TO
								generate(2, "INC", $2->l_exp_name, NULL, NULL);
								generate(3, "F_CMP", $2->l_exp_name, $2->r_exp_name, NULL);
							}else{
								// DOWNTO
								generate(2, "DEC", $2->l_exp_name, NULL, NULL);
								generate(3, "F_CMP", $2->r_exp_name, $2->l_exp_name, NULL);
							}
							char *last_forloop_label_name = $2->label_name;
							generate(2, "JL", last_forloop_label_name, NULL, NULL);
						}
					}
				 ;

for_head:	'(' name_or_array_name ASSIGN_OP expression to expression ')'	{
				$2->value = $4->value;
				generate(3, "F_STORE", $4->name, $2->name, NULL);
				$$ = (struct forhead *) malloc(sizeof(struct forhead));
				$$->l_exp_name = strdup($2->name);
				$$->r_exp_name = strdup($4->name);
				$$->to = $5;
				if(($5 == 0 && $4->value >= $6->value) || ($5 == 1 && $4->value <= $6->value)){
					// forloop condition not fulfilled
					// skip the following statement_list
					add_statement_list(-1);
					$$->forloop_valid = 0;
				}else{
					add_statement_list(1);
					char *label_name = new_label();
					generate(1, label_name, NULL, NULL, NULL);
					add_label(label_name);
					$$->forloop_valid = 1;
					$$->label_name = label_name;
				}
			}
		;

to:	TO	{
		$$ = 0;
	}
  |	DOWNTO	{
		$$ = 1;
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
	if(register_count > max_register)
		max_register = register_count;
	char register_name[100+REGISTER_MAX];
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
	if(check_symtab(sp->name) == NULL){
		// Might be something like LLL[I]
		return;
	}
	if(sp->name[0] == 'T' && sp->name[1] == '&'){
		int register_index = atoi(&(sp->name[2]));
		if(register_index < 1 || register_index > REGISTER_MAX || register_status[register_index] == 0){
			char error_msg[100+REGISTER_MAX];
			sprintf(error_msg, "Free an invalid register %s", sp->name);
			yyerror(error_msg);
			exit(-1);
		}
		fprintf(stderr, "Free register: %s\n", sp->name);
		register_status[register_index] = 0;
		register_count --;
		free_symtab(sp);
	}else{
		// Free a variable is not included in this function
	}
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
	int last_type = get_last_statement_list_type();
	if(last_type == -1){
		// Do not print out the instructions
	}else if(length < 1 || length > 4){
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


char *new_label(){
	label_count ++;
	char label_name[100+LABEL_MAX];
	sprintf(label_name, "lb&%d", label_count);
	return strdup(label_name);
}

void add_label(char *label){
	int label_index = atoi(&(label[3]));
	if(label_index < 1 || label_index > LABEL_MAX || label_index > label_count){
		yyerror("In add_label: invalid label index received.\n");
		exit(-1);
	}
	if(label_status[label_index] == 1){
		yyerror("In add_label: Regenerated label detected.\n");
		exit(-1);
	}
	label_status[label_index] = 1;
}

int get_last_not_printed_label_index(){
	for(int i = 1; i <= label_count; i ++){
		if(label_status[i] == 0){
			return i;
		}
	}
	return -1;
}

char *get_last_label(){
	char label_name[100+LABEL_MAX];
	sprintf(label_name, "lb&%d", label_count);
	return strdup(label_name);
}

void end_statement_list(){
	int last_index = get_last_statement_list_index();
	print_statements[last_index] = 0;
}

int get_last_statement_list_index(){
	for(int i = STMT_SCOPE_MAX-1; i >= 0; i --){
		if(print_statements[i] != 0){
			return i;
		}
	}
	return 0;
}

int get_last_statement_list_type(){
	int last_index = get_last_statement_list_index();
	return print_statements[last_index];
}

void add_statement_list(int add_num){
	if(add_num != 1 && add_num != -1){
		yyerror("In add_statement_list: add_num must be 1 or -1");
		exit(-1);
	}
	int last_index = get_last_statement_list_index();
	last_index ++;
	if(last_index >= STMT_SCOPE_MAX){
		yyerror("In add_statement_list: Maximum of scopes reached!");
		exit(-1);
	}
	print_statements[last_index] = add_num;
}
