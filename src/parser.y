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
char *program_name;
%}

%union {
    double dval;
    struct symtab *symb;
	int dint;
	struct v_name *vname;
	struct forhead *forhead;
	char *str;
	struct exp_list *explist;
}

%token <symb> NAME;
%token <vname> ARRAY_NAME ARRAY_VAR_NAME;
%token <symb> NUMBER;
%token <dint> TYPE;
%token PROGRAM Begin End DECLARE AS ASSIGN_OP Exit PRINT;
%token FOR ENDFOR TO DOWNTO;
%token IF ELSE ENDIF THEN;
%token CMP_L CMP_G CMP_LE CMP_GE CMP_E CMP_NE;
%type <vname> v_name;
%type <dint> v_list;
%type <dint> to;	/*boolean: 0 is TO, 1 is DOWNTO*/
%type <dint> cmp_condition; /* 0: <, 1: >, 2: <=, 3: >=, 4: ==, 5: != */
%type <symb> expression mul_expression primary name_or_array_name;
%type <forhead> for_head;
%type <str> condition condition_statement if_head if_head_to_statement;
%type <explist> expression_list;

%%
start:	program Begin statement_list_origin End	{ 
			fprintf(stderr, "Finish Program with name: %s\n", program_name); 
			clean_up(0);
			exit(0);
		}
     ; 

program:	PROGRAM NAME	{
			generate(2, "START", $2->name, NULL, NULL);
			add_statement_list(1);
			program_name = $2->name;
		}
	   ;

statement_list_origin:	statement_list	{
							end_statement_list();
						}
					 ;

statement_list:	statement ';'
			  | statement_list statement ';'
			  |	nosemi_statement
			  |	statement_list nosemi_statement
			  ;

nosemi_statement:	forloop_statement	/*with no ';' ended*/
				|	if_statement
				;

statement:	declare_statement
		 |	assign_statement
		 |	print_statement
		 |	exit_statement
		 ;

declare_statement: DECLARE v_list AS TYPE	{
		for(int i = 0; i < my_vlist.total_num; i++){
			if(my_vlist.table[i].array_num == -1){
				generate(3, "Declare", my_vlist.table[i].name, num_to_type[$4], NULL);
				new_symtab(my_vlist.table[i].name, $4);
			}else{
				if(my_vlist.table[i].array_num < 2){
					yyerror("Array size must > 1\n");
					exit(-1);
				}
				char name_2[VAR_NAME_MAX];
				sprintf(name_2, "%s_array", num_to_type[$4]);
				char name_3[VAR_NAME_MAX];
				sprintf(name_3, "%d", my_vlist.table[i].array_num);
				generate(4, "Declare", my_vlist.table[i].name, name_2, name_3);
				
				char this_array_name[VAR_NAME_MAX];
				for(int array_i = 0; array_i < my_vlist.table[i].array_num; array_i ++){
					sprintf(this_array_name, "%s[%d]", my_vlist.table[i].name, array_i);
					new_symtab(this_array_name, $4);
				}
			}
		}
		generate(0, NULL, NULL, NULL, NULL);
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
						int type = $1->type;
						if(type == 0){
							generate(3, "I_STORE", $3->name, $1->name, NULL);
							$1->value = (float) (int) $3->value;
						}else{
							generate(3, "F_STORE", $3->name, $1->name, NULL);
							$1->value = $3->value;
						}
						free_register($3);
					}
				;

expression:	expression '+' mul_expression	{
					int type = ($1->type || $3->type) ? 1 : 0;
					$$ = new_register(type);
					$$->value = $1->value + $3->value;
					fprintf(stderr, "exp: exp + mul_exp\t%lf = %lf + %lf\n", $$->value, $1->value, $3->value);
					if(type == 0)
						generate(4, "I_ADD", $1->name, $3->name, $$->name);
					else
						generate(4, "F_ADD", $1->name, $3->name, $$->name);
					free_register($1);
					free_register($3);
				}
			  |	expression '-' mul_expression	{
					int type = ($1->type || $3->type) ? 1 : 0;
					$$ = new_register(type);
					$$->value = $1->value - $3->value;
					fprintf(stderr, "exp: exp - mul_exp\t%lf = %lf - %lf\n", $$->value, $1->value, $3->value);
					if(type == 0)
						generate(4, "I_SUB", $1->name, $3->name, $$->name);
					else
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
					int type = ($1->type || $3->type) ? 1 : 0;
					$$ = new_register(type);
					$$->value = $1->value * $3->value;
					fprintf(stderr, "mul_exp: mul_exp * NUMBER\t%lf = %lf * %lf\n", $$->value, $1->value, $3->value);
					if(type == 0)
						generate(4, "I_MUL", $1->name, $3->name, $$->name);
					else
						generate(4, "F_MUL", $1->name, $3->name, $$->name);
					free_register($1);
					free_register($3);
				}
			  | mul_expression '/' primary	{
					int type = ($1->type || $3->type) ? 1 : 0;
					$$ = new_register(type);
					$$->value = (int) $1->value / (int) $3->value;
					fprintf(stderr, "mul_exp: mul_exp / NUMBER\t%lf = %lf / %lf\n", $$->value, $1->value, $3->value);
					if(type == 0)
						generate(4, "I_DIV", $1->name, $3->name, $$->name);
					else
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
			$$ = $1;
		}
	   |	'-' primary	{
			int type = $2->type;
			$$ = new_register(type);
			$$->value = -$2->value;
			fprintf(stderr, "primary: - primary\t%lf = %lf\n", $$->value, $2->value);
			if(type == 0)
				generate(3, "I_UMINUS", $2->name, $$->name, NULL);
			else
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
						fprintf(stderr, "primary: NAME\t%s\n", $$->name);
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
							// Variable reference before declaration
							// for example LLL[I]
							// The former is LLL not declared
							// The latter is I not declared
							char error_msg[1000];
							sprintf(error_msg, "Variable %s reference before declaration\n", ori_name);
							yyerror(error_msg);
							exit(-1);
						}
						$$->name = ori_name;
						$$->value = 0;
						$$->type = check_symtab(checked_var_name)->type;
					}
				  ;

forloop_statement:	FOR for_head statement_list_origin ENDFOR	{
						if($2->forloop_valid == 0){
							// Do not print anything
						}else{
							char cmp_type[100];
							if($2->cmp_type == 0)
								sprintf(cmp_type, "I_CMP");
							else
								sprintf(cmp_type, "F_CMP");
							char *last_forloop_label_name = $2->label_name;
							if($2->to == 0){
								// TO
								generate(2, "INC", $2->l_exp_name, NULL, NULL);
								generate(3, cmp_type, $2->l_exp_name, $2->r_exp_name, NULL);
								generate(2, "JL", last_forloop_label_name, NULL, NULL);
							}else{
								// DOWNTO
								generate(2, "DEC", $2->l_exp_name, NULL, NULL);
								generate(3, cmp_type, $2->l_exp_name, $2->r_exp_name, NULL);
								generate(2, "JG", last_forloop_label_name, NULL, NULL);
							}
						}
						generate(0, NULL, NULL, NULL, NULL);
					}
				 ;

for_head:	'(' name_or_array_name ASSIGN_OP expression to expression ')'	{
				int type = $2->type;
				if(type == 0){
					$2->value = (int) $4->value;
					generate(3, "I_STORE", $4->name, $2->name, NULL);
				}else{
					$2->value = $4->value;
					generate(3, "F_STORE", $4->name, $2->name, NULL);
				}
				$$ = (struct forhead *) malloc(sizeof(struct forhead));
				$$->l_exp_name = strdup($2->name);
				$$->r_exp_name = strdup($6->name);
				$$->to = $5;
				$$->cmp_type = (type || $6->type) ? 1 : 0;
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


if_statement:	IF if_head_to_statement ELSE statement_list ENDIF	{
					fprintf(stderr, "IF THEN ELSE ENDIF detected\n");
					char *endif_label = $2;
					generate(0, NULL, NULL, NULL, NULL);
					generate(1, endif_label, NULL, NULL, NULL);
					add_label(endif_label);
				}

			|	IF if_head THEN statement_list ENDIF	{
					fprintf(stderr, "IF THEN ENDIF detected\n");
					char *last_not_printed_label = $2;
					generate(0, NULL, NULL, NULL, NULL);
					generate(1, last_not_printed_label, NULL, NULL, NULL);
					add_label(last_not_printed_label);
				}
			;

if_head_to_statement:	if_head THEN statement_list	{
							char *endif_label = new_label();
							$$ = endif_label;
							generate(2, "J", endif_label, NULL, NULL);
							char *else_label = $1;
							generate(1, else_label, NULL, NULL, NULL);
							add_label(else_label);
						}
					;

if_head:	'(' condition_statement ')'	{
			$$ = $2;
		}
	   ;

condition_statement:	condition	{
						$$ = $1;
					}
				   ;

condition:	expression cmp_condition expression	{
				int type = ($1->type || $3->type) ? 1 : 0;
				if(type == 0)
					generate(3, "I_CMP", $1->name, $3->name, NULL);
				else
					generate(3, "F_CMP", $1->name, $3->name, NULL);
				char *label_name = new_label();
				$$ = label_name;
				switch($2) {
					case 0:
						// !JL = JGE
						generate(2, "JGE", label_name, NULL, NULL);
						break;
					case 1:
						// !JG = JLE
						generate(2, "JLE", label_name, NULL, NULL);
						break;
					case 2:
						// !JLE = JG
						generate(2, "JG", label_name, NULL, NULL);
						break;
					case 3:
						// !JGE = JL
						generate(2, "JL", label_name, NULL, NULL);
						break;
					case 4:
						// !JE = JNE
						generate(2, "JNE", label_name, NULL, NULL);
						break;
					case 5:
						// !JNE = JE
						generate(2, "JE", label_name, NULL, NULL);
						break;
					default:
						yyerror("Invalid comparison operand\n");
						exit(-1);
				}
			}
		 ;

cmp_condition:	CMP_L	{$$ = 0;}
			 |	CMP_G	{$$ = 1;}
			 |	CMP_LE	{$$ = 2;}
			 |	CMP_GE	{$$ = 3;}
			 |	CMP_E	{$$ = 4;}
			 |	CMP_NE	{$$ = 5;}
			 ;

print_statement:	PRINT '(' expression_list ')'	{
					char msg_to_print[(VAR_NAME_MAX+2) * ($3->total)]; // include \0 and ','
					msg_to_print[0] = '\0';
					for(int i = 0; i < $3->total; i ++){
						if(i != 0)
							strcat(msg_to_print, ", ");
						strcat(msg_to_print, $3->symtab[i]->name);
					}
					generate(3, "CALL", "print", msg_to_print, NULL);
				}

expression_list:	expression_list ',' expression	{
					if($1->total >= EXP_LIST_MAX){
						yyerror("Expression list exceed limits.");
						exit(-1);
					}
					$$ = $1;
					$$->symtab[$$->total] = $3;
					$$->total ++;
				}
			   |	expression	{
					$$ = (struct exp_list *) malloc(sizeof(struct exp_list));
					$$->total = 1;
					$$->symtab[0] = $1;
				}
			   ;

exit_statement:	Exit '(' NUMBER ')'	{
					clean_up((int)$3->value);
					exit(0);
				}
			  ;
%%

struct symtab *new_symtab(char *s, int type){
	struct symtab *sp;
	if(type != 0 && type != 1){
		yyerror("In new_symtab: Invalid type argument given\n");
		exit(-1);
	}
	
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
			sp->type = type;
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

struct symtab *new_register(int type){
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
	struct symtab *sp = new_symtab(register_name, type);
	return sp;
}

void free_symtab(struct symtab *tp){
	struct symtab *sp;
	for(sp = my_symtab; sp < &my_symtab[NSYMS]; sp++) {
		if(sp->name != NULL && !strcmp(sp->name, tp->name)){
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
		// Might be something like LLL[I], or NUMBER name
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
	}else if(length < 0 || length > 4){
		yyerror("In generate: Generate function error, input length should between 0 and 4\n");
		exit(-1);
	}else if(length == 0){
		printf("\n");
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
	if(status < 0){
		fprintf(stderr, "Program exited unexpectedly with status: %d\n", status);
	}else{
		fprintf(stderr, "Program ended\n");
	}
	generate(2, "HALT", program_name, NULL, NULL);
	generate(0, NULL, NULL, NULL, NULL);
	char this_register_name[100+REGISTER_MAX];
	for(int reg_i = 1; reg_i <= max_register; reg_i ++){
		sprintf(this_register_name, "T&%d", reg_i);
		generate(3, "Declare", this_register_name, "Float", NULL);
	}
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

char *get_last_not_printed_label(){
	for(int i = 1; i <= label_count; i ++){
		if(label_status[i] == 0){
			char label_name[100+LABEL_MAX];
			sprintf(label_name, "lb&%d", i);
			return strdup(label_name);
		}
	}
	return NULL;
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
