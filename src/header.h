#include <stddef.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#define NSYMS 20	/* maximum number of symbols */

struct symtab {
	char *name;
	double value;
} my_symtab[NSYMS];

struct symtab *symlook(char *s);

struct v_name {
	char *name;
	int array_num;
};

struct v_list {
	int total_num;
	struct v_name table[NSYMS];
} my_vlist;

void reset_vlist(void);
void insert_vlist(struct v_name *vname);
