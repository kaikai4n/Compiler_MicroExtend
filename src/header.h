#include <stddef.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#define NSYMS 1024	/* maximum number of symbols */
#define REGISTER_MAX 32	/* maximum number of registers */
#define VAR_NAME_MAX 1000	/*maximum number of variable names */

struct symtab {
	char *name;
	double value;
} my_symtab[NSYMS];

struct v_name {
	char *name;
	int array_num;
};

struct v_list {
	int total_num;
	struct v_name table[NSYMS];
} my_vlist;

void clean_up(int status);
void reset_vlist(void);
void insert_vlist(struct v_name *vname);
void generate(int length, char *instruction, char *name_1, char *name_2, char *name_3);
struct symtab *new_symtab(char *s);
struct symtab *check_symtab(char *s);
struct symtab *new_register();
void free_symtab(struct symtab *tp);
void free_register(struct symtab *sp);

