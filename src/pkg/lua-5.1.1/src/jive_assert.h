/*
* jive_assert.h
* lexer proxy for Lua parser -- implements _assert removal
* Luiz Henrique de Figueiredo <lhf@tecgraf.puc-rio.br>
* 11 May 2007 11:18:57
* This code is hereby placed in the public domain.
* See http://lua-users.org/lists/lua-l/2007-05/msg00176.html
* Add <<#include "jive_assert.h">> just before the definition of luaX_next in llex.c
*/

#include <string.h>

static int nexttoken(LexState *ls, SemInfo *seminfo)
{
 for (;;) {
	int n;
	int t=llex(ls,seminfo);
	if (t!=TK_NAME) return t;
	if (strcmp(getstr(seminfo->ts),"_assert")!=0) return t;
	t=llex(ls,&ls->lookahead.seminfo);
	if (t!='(') {
		ls->lookahead.token = t;
		return TK_NAME;
	}
	for (n=1; n>0; ) {
		t=llex(ls,seminfo);
		if (t==TK_EOS) return t;
		if (t=='(') n++;
		if (t==')') n--;
	}
 }
}

#define llex nexttoken