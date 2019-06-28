#include <stddef.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#define NSYMS 1024	/* maximum number of symbols */
#define REGISTER_MAX 32	/* maximum number of registers */
#define VAR_NAME_MAX 1000	/*maximum number of variable names */
#define STMT_SCOPE_MAX 32	/*maximum number of scopes of statement list*/
#define LABEL_MAX 100
#define EXP_LIST_MAX 100

struct symtab {
	char *name;
	double value;
	int type;
} my_symtab[NSYMS];

struct v_name {
	char *name;
	int array_num;
};

struct v_list {
	int total_num;
	struct v_name table[NSYMS];
} my_vlist;

struct forhead {
	char *l_exp_name;	/* left expression name */
	char *r_exp_name;	/* right expression name*/
	int to;	/* TO (0) or DOWNTO(1) */
	int forloop_valid;	/* valid (1) if forhead condition is fulfilled
							else (0) not fulfilled condition */
	char *label_name;	/* The corresponding for loop header label name */
	int cmp_type;		/* 0 is I_CMP, 1 is F_CMP */
} ;

struct exp_list {
	int total;
	struct symtab *symtab[EXP_LIST_MAX];
} ;

void clean_up(int status);
void reset_vlist(void);
void insert_vlist(struct v_name *vname);
void generate(int length, char *instruction, char *name_1, char *name_2, char *name_3);
struct symtab *new_symtab(char *s, int type);
struct symtab *check_symtab(char *s);
struct symtab *new_register();
void free_symtab(struct symtab *tp);
void free_register(struct symtab *sp);

char *new_label();
void add_label(char *label);
char *get_last_not_printed_label();
char *get_last_label();

void end_statement_list();
int get_last_statement_list_index();
int get_last_statement_list_type();
void add_statement_list(int add_num);

