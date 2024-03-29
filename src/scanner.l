%{
#include "header.h"
#include "y.tab.h"
char *token_type[] = {"", "BEGIN", "END", "READ", "WRITE", "Name", "Integer Literal", "Float Point Literal", "Exponential Float Point Literal", "String Literal", "Left Parenthesis", "Right parenthesis", "Semicolon", "Comma", "Assign Operation", "Plus Operation", "Minus Operation", "Multiplication Operation", "Division", "Not Equal", "Greater than", "Less than", "Greater or equal", "Less or equal", "Equal", "IF", "THEN", "ELSE", "ENDIF", "FOR", "TO", "ENDFOR", "WHILE", "ENDWHILE", "DECLARE", "AS", "INTEGER", "REAL", "ScanEof", "Syntax Error", "Program", "Float"};
extern int line_count;
%}

int_regex       [0-9]
float_regex     ({int_regex}+\.{int_regex}*)|({int_regex}*\.{int_regex}+)

%%

\n				{
		line_count ++;
	}
[\t ]+		/* ignore white space */ ;
\%\%[^\n]*\n	{
		/* ignore comments */
		fprintf(stderr, "Comment at line %d\n", line_count) ;
		line_count ++;
	}

\%\{[^\%^\}]*\%\}	{
		int new_lines_count = 0;
		for(int i = 0; i < strlen(yytext); i++){
			if(yytext[i] == '\n')
				new_lines_count ++;
		}
		fprintf(stderr, "Comment multiple lines: %d lines\n", new_lines_count);
		line_count += new_lines_count;
	}

[Bb][Ee][Gg][Ii][Nn]                    {return Begin;}
[Ee][Nn][Dd]                            {return End;}
[Rr][Ee][Aa][Dd]                        {return 3;}
[Ww][Rr][Ii][Tt][Ee]                    {return 4;}
[Ee][Xx][Ii][Tt]						{return Exit;}
\(                                      {return '(';}
\)                                      {return ')';}
;                                       {return ';';}
\,                                      {return ',';}
:=                                      {return ASSIGN_OP;}
\+                                      {return '+';}
-                                       {return '-';}
\*                                      {return '*';}
\/                                      {return '/';}
>                                       {return CMP_G;}
\<                                      {return CMP_L;}
>=                                      {return CMP_GE;}
\<=                                     {return CMP_LE;}
==                                      {return CMP_E;}
!=                                      {return CMP_NE;}
[Ii][Ff]                                {return IF;}
[Tt][Hh][Ee][Nn]                        {return THEN;}
[Ee][Ll][Ss][Ee]                        {return ELSE;}
[Ee][Nn][Dd][Ii][Ff]                    {return ENDIF;}
[Ff][Oo][Rr]                            {return FOR;}
[Ee][Nn][Dd][Ff][Oo][Rr]                {return ENDFOR;}
[Tt][Oo]                                {return TO;}
[Ss][Tt][Ee][Pp]						{return STEP;}
[Dd][Oo][Ww][Nn][Tt][Oo]				{return DOWNTO;}
[Ww][Hh][Ii][Ll][Ee]                    {return 32;}
[Ee][Nn][Dd][Ww][Hh][Ii][Ll][Ee]        {return 33;}
[Dd][Ee][Cc][Ll][Aa][Rr][Ee]            {return DECLARE;}
[Aa][Ss]                                {return AS;}
[Ii][Nn][Tt][Ee][Gg][Ee][Rr]            {
        yylval.dint=0; 
        return TYPE;
    }
[Rr][Ee][Aa][Ll]                        {return 37;}
<<EOF>>                                 {return 38;}
[Pp][Rr][Oo][Gg][Rr][Aa][Mm]            {return PROGRAM;}
[Ff][Ll][Oo][Aa][Tt]                    {
        yylval.dint=1;
        return TYPE;
    }
[Pp][Rr][Ii][Nn][Tt]					{return PRINT;}
[a-zA-Z]+([a-zA-Z0-9_]*)                {
		yylval.symb = (struct symtab*) malloc(sizeof(struct symtab));
		yylval.symb->name = strdup(yytext);
		yylval.symb->value = 0;
        return NAME;
    }
[a-zA-Z]+([a-zA-Z0-9_]*)\[[0-9]+\] {
		int lb, rb;
		for(lb = 0; lb < strlen(yytext); lb++){
			if(yytext[lb] == '['){
				yytext[lb] = '\0';
				lb ++;
				break;
			}
		}
		for(rb = lb; rb < strlen(yytext); rb++){
			if(yytext[rb] == ']'){
				yytext[rb] = '\0';
				break;
			}
		}
		char this_array_name[VAR_NAME_MAX];
		sprintf(this_array_name, "%s[0]", yytext);
		struct symtab *sp = check_symtab(this_array_name);
		yylval.vname = (struct v_name*) malloc(sizeof(struct v_name));
		yylval.vname->name = strdup(yytext);
		yylval.vname->array_num = atoi(&yytext[lb]);
        return ARRAY_NAME;
    }
[a-zA-Z]+([a-zA-Z0-9_]*)\[[a-zA-Z]+[a-zA-Z0-9_]*\] {
		yylval.vname = (struct v_name*) malloc(sizeof(struct v_name));
		yylval.vname->name = strdup(yytext);
		return ARRAY_VAR_NAME;		
	}
-?([1-9]+[0-9]*|0)	{
		yylval.symb = (struct symtab *) malloc(sizeof(struct symtab));
		yylval.symb->name = strdup(yytext);
        yylval.symb->value = atof(yytext);
		yylval.symb->type = 0;	/* NUMBER is Int */
        return NUMBER;
	}
-?([0-9]+|([0-9]*\.[0-9]+)([eE][-+]?[0-9]+)?) {
		yylval.symb = (struct symtab *) malloc(sizeof(struct symtab));
		yylval.symb->name = strdup(yytext);
        yylval.symb->value = atof(yytext);
		yylval.symb->type = 1;	/* NUMBER is Float */
        return NUMBER;
    }
\".+\"                                  {return 9;}

.                                       {return 39;}   /*lexical error */ 
%%
