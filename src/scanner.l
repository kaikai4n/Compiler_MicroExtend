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
!=                                      {return 19;}
>                                       {return 20;}
\<                                      {return 21;}
>=                                      {return 22;}
\<=                                     {return 23;}
==                                      {return 24;}
[Ii][Ff]                                {return 25;}
[Tt][Hh][Ee][Nn]                        {return 26;}
[Ee][Ll][Ss][Ee]                        {return 27;}
[Ee][Nn][Dd][Ii][Ff]                    {return 28;}
[Ff][Oo][Rr]                            {return 29;}
[Tt][Oo]                                {return 30;}
[Ee][Nn][Dd][Ff][Oo][Rr]                {return 31;}
[Ww][Hh][Ii][Ll][Ee]                    {return 32;}
[Ee][Nn][Dd][Ww][Hh][Ii][Ll][Ee]        {return 33;}
[Dd][Ee][Cc][Ll][Aa][Rr][Ee]            {return DECLARE;}
[Aa][Ss]                                {return AS;}
[Ii][Nn][Tt][Ee][Gg][Ee][Rr]            {
        yylval.dint=1; 
        return TYPE;
    }
[Rr][Ee][Aa][Ll]                        {return 37;}
<<EOF>>                                 {return 38;}
[Pp][Rr][Oo][Gg][Rr][Aa][Mm]            {return PROGRAM;}
[Ff][Ll][Oo][Aa][Tt]                    {
        yylval.dint=2;
        return TYPE;
    }
[a-zA-Z]+([a-zA-Z0-9_]*)                {
        yylval.symb = new_symtab(yytext);
		fprintf(stderr, "In lex: new NAME: %s\n", yylval.symb->name);
        return NAME;
    }
[a-zA-Z]+([a-zA-Z0-9_]*)\[[1-9]+[0-9]*\] {
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
        yylval.vname->name = strdup(yytext);
		yylval.vname->array_num = atoi(&yytext[lb]);
		for(int array_i = 0; array_i < yylval.vname->array_num; array_i ++){
			char this_array_name[VAR_NAME_MAX];
			sprintf(this_array_name, "%s[%d]", yylval.vname->name, array_i);
			fprintf(stderr, "In lex: new array name: %s\n", this_array_name);
			new_symtab(this_array_name);
		}
        return ARRAY_NAME;
    }
-?([0-9]+|([0-9]*\.[0-9]+)([eE][-+]?[0-9]+)?) {
        yylval.dval = atof(yytext);
        return NUMBER;
    }
 /*{int_regex}+                            {return 6;}
{float_regex}                           {return 7;}
([0-9]+|{float_regex})([eE][-+]?[0-9]+) {return 8;}
*/
\".+\"                                  {return 9;}

.                                       {return 39;}   /*lexical error */ 
%%
/*
int main()
{
    int i;
 
    while((i=yylex()) != 38){
        if(i == 39)
            printf("\033[31mSyntax Error: return value is %d, token is %s, type is %s\033[0m\n", i, yytext, token_type[i]);
        else 
            printf("return value is %d, token is %s, type is %s\n", i, yytext, token_type[i]);
    }

    printf("End of file\n");
}
*/

