/*
** $Id: lvm.c,v 2.63 2006/06/05 15:58:59 roberto Exp $
** Lua virtual machine
** See Copyright Notice in lua.h
*/


#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define lvm_c
#define LUA_CORE

#include "lua.h"

#include "ldebug.h"
#include "ldo.h"
#include "lfunc.h"
#include "lgc.h"
#include "lobject.h"
#include "lopcodes.h"
#include "lstate.h"
#include "lstring.h"
#include "ltable.h"
#include "ltm.h"
#include "lvm.h"



/* limit for table tag-method chains (to avoid loops) */
#define MAXTAGLOOP	100


/* Functions for finding out, when integer operations remain in range
 * (and doing them).
 */
#ifdef LUA_TINT
static int try_addint( StkId ra, lua_Integer ib, lua_Integer ic ) {
  lua_Integer v= ib+ic; /* may overflow */
  if (ib>0 && ic>0)      { if (v < 0) return 0; /*overflow, use floats*/ }
  else if (ib<0 && ic<0) { if (v >= 0) return 0; }
  setivalue(ra, v);
  return 1;
}
static int try_subint( StkId ra, lua_Integer ib, lua_Integer ic ) {
  lua_Integer v= ib-ic; /* may overflow */
  if (ib>=0 && ic<0)     { if (v < 0) return 0; /*overflow, use floats*/ }
  else if (ib<0 && ic>0) { if (v >= 0) return 0; }
  setivalue(ra, v);
  return 1;
}
static int try_mulint( StkId ra, lua_Integer ib, lua_Integer ic ) {
  /* If either is -2^31, multiply with anything but 0,1 would be out or range.
   * 0,1 will go through the float route, but will fall back to integers
   * eventually (no accuracy lost, so no need to check).
   * Also, anything causing -2^31 result (s.a. -2*2^30) will take the float
   * route, but later fall back to integer without accuracy loss. :)
   */
  if (ib!=LUA_INTEGER_MIN && ic!=LUA_INTEGER_MIN) {
    lua_Integer b= abs(ib), c= abs(ic);
    if ( (ib==0) || (LUA_INTEGER_MAX/b > c) ||
                   ((LUA_INTEGER_MAX/b == c) && (LUA_INTEGER_MAX%b == 0)) ) {
      setivalue(ra, ib*ic);  /* no overflow */
      return 1;
    }
  }
  return 0;
}
static int try_divint( StkId ra, lua_Integer ib, lua_Integer ic ) {
  /* -2^31/N: leave to float side (either the division causes non-integer results,
   *          or fallback to integer through float calculation, but without accuracy
   *          lost (N=2,4,8,..,256 and N=2^30,2^29,..2^23).
   * N/-2^31: leave to float side (always non-integer results or 0 or +1)
   * N/0:     leave to float side, to give an error
   *
   * Note: We _can_ use ANSI C mod here, even on negative values, since
   *       we only test for == 0 (the sign would be implementation dependent).
   */
  if (ic!=0 && ib!=LUA_INTEGER_MIN && ic!=LUA_INTEGER_MIN) {
    if (ib%ic == 0) { setivalue(ra, ib/ic); return 1; }
  }
  return 0;
}
static int try_modint( StkId ra, lua_Integer ib, lua_Integer ic ) {
  if (ic!=0) {
    /* ANSI C can be trusted when b%c==0, or when values are non-negative. 
     * b - (floor(b/c) * c)
     *   -->
     * + +: b - (b/c) * c (b % c can be used)
     * - -: b - (b/c) * c (b % c could work, but not defined by ANSI C)
     * 0 -: b - (b/c) * c (=0, b % c could work, but not defined by ANSI C)
     * - +: b - (b/c-1) * c (when b!=-c)
     * + -: b - (b/c-1) * c (when b!=-c)
     *
     * o MIN%MIN ends up 0, via overflow in calcs but that does not matter.
     * o MIN%MAX ends up MAX-1 (and other such numbers), also after overflow,
     *   but that does not matter, results do.
     */
    lua_Integer v= ib % ic;
    if ( v!=0 && (ib<0 || ic<0) ) {
      v= ib - ((ib/ic) - ((ib<=0 && ic<0) ? 0:1)) * ic;
    }      
    /* Result should always have same sign as 2nd argument. (PIL2) */
    lua_assert( (v<0) ? (ic<0) : (v>0) ? (ic>0) : 1 );
    setivalue(ra, v);
    return 1;
  }
  return 0;  /* let float side return NaN */
}
static int try_powint( StkId ra, lua_Integer ib, lua_Integer ic ) {
  /* Fallback to floats would not hurt (no accuracy lost) but we can do
   * some common cases (2^N where N=[0..30]) for speed.
   */
  if (ib==2 && ic>=0 && ic <= 30) {
    setivalue(ra, 1<<ic);   /* 1,2,4,...2^30 */
    return 1;
  }
  return 0;
}
static int try_unmint( StkId ra, lua_Integer ib ) {
  /* Negating -2^31 leaves the range. */
  if ( ib != LUA_INTEGER_MIN )  
    { setivalue(ra,-ib); return 1; }
  return 0;
}
#endif /* LUA_TINT */


const TValue *luaV_tonumber (const TValue *obj, TValue *n) {
  lua_Number num;
  if (ttisnumber(obj)) return obj;

#ifdef LUA_TINT
  /* Reason to handle integers differently is not only speed, but accuracy
     as well. We don't want to lose LSB's because of interim casts.
  */
  if (ttisstring(obj)) {
    lua_Integer i;
    if (luaO_str2i(svalue(obj), &i)) {
      setivalue(n,i);
      return n;
    }
    /* Now, DO NOT use 'setnvalue_fast()' here, since the number might be
     * i.e. "1.0", which needs to be stored as an integer.
     */
    if (luaO_str2d(svalue(obj), &num)) {
      setnvalue(n,num);
      return n;
    }
  }
#else
  if (ttisstring(obj) && luaO_str2d(svalue(obj), &num)) {
    setnvalue(n, num);
    return n;
  }
#endif
  return NULL;
}


int luaV_tostring (lua_State *L, StkId obj) {
  if (!ttisnumber(obj))
    return 0;
  else {
    char s[LUAI_MAXNUMBER2STR];
#ifdef LUA_TINT
  /* Reason to handle integers differently is not only speed,
     but accuracy as well. We want to make any integer tostring()
     without roundings, at all (only [-0..9] used).
  */
    if (ttisinteger(obj)) {
      lua_Integer i = ivalue(obj);
      lua_integer2str(s, i);
    }
    else {  
      lua_Number n = nvalue_fast(obj);
      lua_number2str(s, n);
    }
#else
    lua_Number n = nvalue(obj);
    lua_number2str(s, n);
#endif
    setsvalue2s(L, obj, luaS_new(L, s));
    return 1;
  }
}


static void traceexec (lua_State *L, const Instruction *pc) {
  lu_byte mask = L->hookmask;
  const Instruction *oldpc = L->savedpc;
  L->savedpc = pc;
  if (mask > LUA_MASKLINE) {  /* instruction-hook set? */
    if (L->hookcount == 0) {
      resethookcount(L);
      luaD_callhook(L, LUA_HOOKCOUNT, -1);
    }
  }
  if (mask & LUA_MASKLINE) {
    Proto *p = ci_func(L->ci)->l.p;
    int npc = pcRel(pc, p);
    int newline = getline(p, npc);
    /* call linehook when enter a new function, when jump back (loop),
       or when enter a new line */
    if (npc == 0 || pc <= oldpc || newline != getline(p, pcRel(oldpc, p)))
      luaD_callhook(L, LUA_HOOKLINE, newline);
  }
}


static void callTMres (lua_State *L, StkId res, const TValue *f,
                        const TValue *p1, const TValue *p2) {
  ptrdiff_t result = savestack(L, res);
  setobj2s(L, L->top, f);  /* push function */
  setobj2s(L, L->top+1, p1);  /* 1st argument */
  setobj2s(L, L->top+2, p2);  /* 2nd argument */
  luaD_checkstack(L, 3);
  L->top += 3;
  luaD_call(L, L->top - 3, 1);
  res = restorestack(L, result);
  L->top--;
  setobjs2s(L, res, L->top);
}



static void callTM (lua_State *L, const TValue *f, const TValue *p1,
                    const TValue *p2, const TValue *p3) {
  setobj2s(L, L->top, f);  /* push function */
  setobj2s(L, L->top+1, p1);  /* 1st argument */
  setobj2s(L, L->top+2, p2);  /* 2nd argument */
  setobj2s(L, L->top+3, p3);  /* 3th argument */
  luaD_checkstack(L, 4);
  L->top += 4;
  luaD_call(L, L->top - 4, 0);
}


void luaV_gettable (lua_State *L, const TValue *t, TValue *key, StkId val) {
  int loop;
  for (loop = 0; loop < MAXTAGLOOP; loop++) {
    const TValue *tm;
    if (ttistable(t)) {  /* `t' is a table? */
      Table *h = hvalue(t);
      const TValue *res = luaH_get(h, key); /* do a primitive get */
      if (!ttisnil(res) ||  /* result is no nil? */
          (tm = fasttm(L, h->metatable, TM_INDEX)) == NULL) { /* or no TM? */
        setobj2s(L, val, res);
        return;
      }
      /* else will try the tag method */
    }
    else if (ttisnil(tm = luaT_gettmbyobj(L, t, TM_INDEX)))
      luaG_typeerror(L, t, "index");
    if (ttisfunction(tm)) {
      callTMres(L, val, tm, t, key);
      return;
    }
    t = tm;  /* else repeat with `tm' */ 
  }
  luaG_runerror(L, "loop in gettable");
}


void luaV_settable (lua_State *L, const TValue *t, TValue *key, StkId val) {
  int loop;
  for (loop = 0; loop < MAXTAGLOOP; loop++) {
    const TValue *tm;
    if (ttistable(t)) {  /* `t' is a table? */
      Table *h = hvalue(t);
      TValue *oldval = luaH_set(L, h, key); /* do a primitive set */
      if (!ttisnil(oldval) ||  /* result is no nil? */
          (tm = fasttm(L, h->metatable, TM_NEWINDEX)) == NULL) { /* or no TM? */
        setobj2t(L, oldval, val);
        luaC_barriert(L, h, val);
        return;
      }
      /* else will try the tag method */
    }
    else if (ttisnil(tm = luaT_gettmbyobj(L, t, TM_NEWINDEX)))
      luaG_typeerror(L, t, "index");
    if (ttisfunction(tm)) {
      callTM(L, tm, t, key, val);
      return;
    }
    t = tm;  /* else repeat with `tm' */ 
  }
  luaG_runerror(L, "loop in settable");
}


static int call_binTM (lua_State *L, const TValue *p1, const TValue *p2,
                       StkId res, TMS event) {
  const TValue *tm = luaT_gettmbyobj(L, p1, event);  /* try first operand */
  if (ttisnil(tm))
    tm = luaT_gettmbyobj(L, p2, event);  /* try second operand */
  if (!ttisfunction(tm)) return 0;
  callTMres(L, res, tm, p1, p2);
  return 1;
}


static const TValue *get_compTM (lua_State *L, Table *mt1, Table *mt2,
                                  TMS event) {
  const TValue *tm1 = fasttm(L, mt1, event);
  const TValue *tm2;
  if (tm1 == NULL) return NULL;  /* no metamethod */
  if (mt1 == mt2) return tm1;  /* same metatables => same metamethods */
  tm2 = fasttm(L, mt2, event);
  if (tm2 == NULL) return NULL;  /* no metamethod */
  if (luaO_rawequalObj(tm1, tm2))  /* same metamethods? */
    return tm1;
  return NULL;
}


static int call_orderTM (lua_State *L, const TValue *p1, const TValue *p2,
                         TMS event) {
  const TValue *tm1 = luaT_gettmbyobj(L, p1, event);
  const TValue *tm2;
  if (ttisnil(tm1)) return -1;  /* no metamethod? */
  tm2 = luaT_gettmbyobj(L, p2, event);
  if (!luaO_rawequalObj(tm1, tm2))  /* different metamethods? */
    return -1;
  callTMres(L, L->top, tm1, p1, p2);
  return !l_isfalse(L->top);
}


static int l_strcmp (const TString *ls, const TString *rs) {
  const char *l = getstr(ls);
  size_t ll = ls->tsv.len;
  const char *r = getstr(rs);
  size_t lr = rs->tsv.len;
  for (;;) {
    int temp = strcoll(l, r);
    if (temp != 0) return temp;
    else {  /* strings are equal up to a `\0' */
      size_t len = strlen(l);  /* index of first `\0' in both strings */
      if (len == lr)  /* r is finished? */
        return (len == ll) ? 0 : 1;
      else if (len == ll)  /* l is finished? */
        return -1;  /* l is smaller than r (because r is not finished) */
      /* both strings longer than `len'; go on comparing (after the `\0') */
      len++;
      l += len; ll -= len; r += len; lr -= len;
    }
  }
}


int luaV_lessthan (lua_State *L, const TValue *l, const TValue *r) {
  int res;
#ifdef LUA_TINT
  int tl,tr;
#endif
  if (ttype2(l) != ttype2(r))
    return luaG_ordererror(L, l, r);
#ifdef LUA_TINT
  tl= ttype(l), tr= ttype(r);
  if (tl==tr) {  /* clear arithmetics */
    switch(tl) {
      case LUA_TINT:      return ivalue(l) < ivalue(r);
      case LUA_TNUMBER:   return luai_numlt(nvalue_fast(l), nvalue_fast(r));
      case LUA_TSTRING:   return l_strcmp(rawtsvalue(l), rawtsvalue(r)) < 0;
    }
  } else if (tl==LUA_TINT) {  /* l:int, r:num */
      return luai_numlt( cast_num(ivalue(l)), nvalue_fast(r) );
  } else if (tl==LUA_TNUMBER) {  /* l:num, r:int */
      return luai_numlt( nvalue_fast(l), cast_num(ivalue(r)) );
  }
  if ((res = call_orderTM(L, l, r, TM_LT)) != -1)
    return res;
#else
  else if (ttisnumber(l))
    return luai_numlt(nvalue(l), nvalue(r));
  else if (ttisstring(l))
    return l_strcmp(rawtsvalue(l), rawtsvalue(r)) < 0;
  else if ((res = call_orderTM(L, l, r, TM_LT)) != -1)
    return res;
#endif
  return luaG_ordererror(L, l, r);
}


static int lessequal (lua_State *L, const TValue *l, const TValue *r) {
  int res;
#ifdef LUA_TINT
  int tl, tr;
#endif
  if (ttype2(l) != ttype2(r))
    return luaG_ordererror(L, l, r);
#ifdef LUA_TINT
  tl= ttype(l), tr= ttype(r);
  if (tl==tr) {  /* clear arithmetics */
    switch(tl) {
      case LUA_TINT:      return ivalue(l) <= ivalue(r);
      case LUA_TNUMBER:   return luai_numle(nvalue_fast(l), nvalue_fast(r));
      case LUA_TSTRING:   return l_strcmp(rawtsvalue(l), rawtsvalue(r)) <= 0;
    }
  } else if (tl==LUA_TINT) {  /* l:int, r:num */
      return luai_numle( cast_num(ivalue(l)), nvalue_fast(r) );
  } else if (tl==LUA_TNUMBER) {  /* l:num, r:int */
      return luai_numle( nvalue_fast(l), cast_num(ivalue(r)) );
  }
  if ((res = call_orderTM(L, l, r, TM_LE)) != -1)  /* first try `le' */
    return res;
  else if ((res = call_orderTM(L, r, l, TM_LT)) != -1)  /* else try `lt' */
    return !res;
#else
  else if (ttisnumber(l))
    return luai_numle(nvalue(l), nvalue(r));
  else if (ttisstring(l))
    return l_strcmp(rawtsvalue(l), rawtsvalue(r)) <= 0;
  else if ((res = call_orderTM(L, l, r, TM_LE)) != -1)  /* first try `le' */
    return res;
  else if ((res = call_orderTM(L, r, l, TM_LT)) != -1)  /* else try `lt' */
    return !res;
#endif
  return luaG_ordererror(L, l, r);
}


int luaV_equalval (lua_State *L, const TValue *t1, const TValue *t2) {
  const TValue *tm;
  lua_assert(ttype(t1) == ttype(t2));
  switch (ttype(t1)) {
    case LUA_TNIL: return 1;
#ifdef LUA_TINT
    case LUA_TINT: return ivalue(t1) == ivalue(t2);
    case LUA_TNUMBER: return luai_numeq(nvalue_fast(t1), nvalue_fast(t2));
#else
    case LUA_TNUMBER: return luai_numeq(nvalue(t1), nvalue(t2));
#endif
    case LUA_TBOOLEAN: return bvalue(t1) == bvalue(t2);  /* true must be 1 !! */
    case LUA_TLIGHTUSERDATA: return pvalue(t1) == pvalue(t2);
    case LUA_TUSERDATA: {
      if (uvalue(t1) == uvalue(t2)) return 1;
      tm = get_compTM(L, uvalue(t1)->metatable, uvalue(t2)->metatable,
                         TM_EQ);
      break;  /* will try TM */
    }
    case LUA_TTABLE: {
      if (hvalue(t1) == hvalue(t2)) return 1;
      tm = get_compTM(L, hvalue(t1)->metatable, hvalue(t2)->metatable, TM_EQ);
      break;  /* will try TM */
    }
    default: return gcvalue(t1) == gcvalue(t2);
  }
  if (tm == NULL) return 0;  /* no TM? */
  callTMres(L, L->top, tm, t1, t2);  /* call TM */
  return !l_isfalse(L->top);
}


void luaV_concat (lua_State *L, int total, int last) {
  do {
    StkId top = L->base + last + 1;
    int n = 2;  /* number of elements handled in this pass (at least 2) */
    if (!tostring(L, top-2) || !tostring(L, top-1)) {
      if (!call_binTM(L, top-2, top-1, top-2, TM_CONCAT))
        luaG_concaterror(L, top-2, top-1);
    } else if (tsvalue(top-1)->len > 0) {  /* if len=0, do nothing */
      /* at least two string values; get as many as possible */
      size_t tl = tsvalue(top-1)->len;
      char *buffer;
      int i;
      /* collect total length */
      for (n = 1; n < total && tostring(L, top-n-1); n++) {
        size_t l = tsvalue(top-n-1)->len;
        if (l >= MAX_SIZET - tl) luaG_runerror(L, "string length overflow");
        tl += l;
      }
      buffer = luaZ_openspace(L, &G(L)->buff, tl);
      tl = 0;
      for (i=n; i>0; i--) {  /* concat all strings */
        size_t l = tsvalue(top-i)->len;
        memcpy(buffer+tl, svalue(top-i), l);
        tl += l;
      }
      setsvalue2s(L, top-n, luaS_newlstr(L, buffer, tl));
    }
    total -= n-1;  /* got `n' strings to create 1 new */
    last -= n-1;
  } while (total > 1);  /* repeat until only 1 result left */
}


static void Arith (lua_State *L, StkId ra, const TValue *rb,
                   const TValue *rc, TMS op) {
  TValue tempb, tempc;
  const TValue *b, *c;
  if ((b = luaV_tonumber(rb, &tempb)) != NULL &&
      (c = luaV_tonumber(rc, &tempc)) != NULL) {
      /*FIXME*/
    lua_Number nb, nc;
#ifdef LUA_TINT
    /* Keep integer arithmetics in the integer realm, if possible (for speed,
     * but also accuracy). 
     */
    if (ttisinteger(b) && ttisinteger(c)) {
      lua_Integer ib = ivalue(b), ic = ivalue(c);
      switch (op) {
        case TM_ADD: if (try_addint(ra, ib, ic)) return; break;
        case TM_SUB: if (try_subint(ra, ib, ic)) return; break;
        case TM_MUL: if (try_mulint(ra, ib, ic)) return; break;
        case TM_DIV: if (try_divint(ra, ib, ic)) return; break;
        case TM_MOD: if (try_modint(ra, ib, ic)) return; break;
        case TM_POW: if (try_powint(ra, ib, ic)) return; break;
        case TM_UNM: if (try_unmint(ra, ib)) return; break;
#if defined(LUA_BITWISE_OPERATORS)
      	case TM_INTDIV: if (try_divint(ra, ib, ic)) return; break;
#endif
        default: lua_assert(0); break;
      }
    }
    /* Fallback to floating point, when leaving range. */
#endif
    nb = nvalue(b), nc = nvalue(c);

    switch (op) {
      case TM_ADD: setnvalue(ra, luai_numadd(nb, nc)); return;
      case TM_SUB: setnvalue(ra, luai_numsub(nb, nc)); return;
      case TM_MUL: setnvalue(ra, luai_nummul(nb, nc)); return;
      case TM_DIV: setnvalue(ra, luai_numdiv(nb, nc)); return;
      case TM_MOD: setnvalue(ra, luai_nummod(nb, nc)); return;
      case TM_POW: setnvalue(ra, luai_numpow(nb, nc)); return;
      case TM_UNM: setnvalue(ra, luai_numunm(nb)); return;
#if defined(LUA_BITWISE_OPERATORS)
      case TM_INTDIV: setnvalue(ra, luai_numintdiv(nb, nc)); return;
#endif
      default: lua_assert(0); break;
    }
  }
  if (!call_binTM(L, rb, rc, ra, op))
    luaG_aritherror(L, rb, rc);
}

#if defined(LUA_BITWISE_OPERATORS)
static void Logic (lua_State *L, StkId ra, const TValue *rb,
                   const TValue *rc, TMS op) {
  TValue tempb, tempc;
  const TValue *b, *c;
  if ((b = luaV_tonumber(rb, &tempb)) != NULL &&
      (c = luaV_tonumber(rc, &tempc)) != NULL) {
    lua_Number nb = nvalue(b), nc = nvalue(c);
    lua_Integer r;
    switch (op) {
      case TM_BLSHFT: luai_loglshft(r, nb, nc); break;
      case TM_BRSHFT: luai_logrshft(r, nb, nc); break;
      case TM_BOR: luai_logor(r, nb, nc); break;
      case TM_BAND: luai_logand(r, nb, nc); break;
      case TM_BXOR: luai_logxor(r, nb, nc); break;
      case TM_BNOT: luai_lognot(r, nb); break;
      default: lua_assert(0); r = 0; break;
    }
    setnvalue(ra, r);
  }
  else if (!call_binTM(L, rb, rc, ra, op))
    luaG_logicerror(L, rb, rc);
}
#endif

/*
** some macros for common tasks in `luaV_execute'
*/

#define runtime_check(L, c)	{ if (!(c)) break; }

#define RA(i)	(base+GETARG_A(i))
/* to be used after possible stack reallocation */
#define RB(i)	check_exp(getBMode(GET_OPCODE(i)) == OpArgR, base+GETARG_B(i))
#define RC(i)	check_exp(getCMode(GET_OPCODE(i)) == OpArgR, base+GETARG_C(i))
#define RKB(i)	check_exp(getBMode(GET_OPCODE(i)) == OpArgK, \
	ISK(GETARG_B(i)) ? k+INDEXK(GETARG_B(i)) : base+GETARG_B(i))
#define RKC(i)	check_exp(getCMode(GET_OPCODE(i)) == OpArgK, \
	ISK(GETARG_C(i)) ? k+INDEXK(GETARG_C(i)) : base+GETARG_C(i))
#define KBx(i)	check_exp(getBMode(GET_OPCODE(i)) == OpArgK, k+GETARG_Bx(i))


#define dojump(L,pc,i)	{(pc) += (i); luai_threadyield(L);}


#define Protect(x)	{ L->savedpc = pc; {x;}; base = L->base; }

#ifdef LUA_TINT
  #define arith_op(op_num,tm,op_int) { \
        TValue *rb = RKB(i); \
        TValue *rc = RKC(i); \
        int done= 0; \
        if (ttisinteger(rb) && ttisinteger(rc)) { \
          lua_Integer ib = ivalue(rb), ic = ivalue(rc); \
          if (op_int (ra,ib,ic)) done=1; \
        } \
        if (!done) { \
          if (ttisnumber(rb) && ttisnumber(rc)) { \
            lua_Number nb = nvalue(rb), nc = nvalue(rc); \
            setnvalue(ra, op_num (nb, nc)); \
          } else \
            Protect(Arith(L, ra, rb, rc, tm)); \
        } \
      }
#else
  #define arith_op(op,tm,_) { \
        TValue *rb = RKB(i); \
        TValue *rc = RKC(i); \
        if (ttisnumber(rb) && ttisnumber(rc)) { \
          lua_Number nb = nvalue(rb), nc = nvalue(rc); \
          setnvalue(ra, op(nb, nc)); \
        } \
        else \
          Protect(Arith(L, ra, rb, rc, tm)); \
      }
#endif

#if defined(LUA_BITWISE_OPERATORS)
#define logic_op(op,tm) { \
        TValue *rb = RKB(i); \
        TValue *rc = RKC(i); \
        if (ttisnumber(rb) && ttisnumber(rc)) { \
          lua_Integer r; \
          op(r, nvalue(rb), nvalue(rc)); \
          setnvalue(ra, r); \
        } \
        else \
          Protect(Logic(L, ra, rb, rc, tm)); \
      }
#endif



void luaV_execute (lua_State *L, int nexeccalls) {
  LClosure *cl;
  StkId base;
  TValue *k;
  const Instruction *pc;
 reentry:  /* entry point */
  lua_assert(isLua(L->ci));
  pc = L->savedpc;
  cl = &clvalue(L->ci->func)->l;
  base = L->base;
  k = cl->p->k;
  /* main loop of interpreter */
  for (;;) {
    const Instruction i = *pc++;
    StkId ra;
    if ((L->hookmask & (LUA_MASKLINE | LUA_MASKCOUNT)) &&
        (--L->hookcount == 0 || L->hookmask & LUA_MASKLINE)) {
      traceexec(L, pc);
      if (L->status == LUA_YIELD) {  /* did hook yield? */
        L->savedpc = pc - 1;
        return;
      }
      base = L->base;
    }
    /* warning!! several calls may realloc the stack and invalidate `ra' */
    ra = RA(i);
    lua_assert(base == L->base && L->base == L->ci->base);
    lua_assert(base <= L->top && L->top <= L->stack + L->stacksize);
    lua_assert(L->top == L->ci->top || luaG_checkopenop(i));
    switch (GET_OPCODE(i)) {
      case OP_MOVE: {
        setobjs2s(L, ra, RB(i));
        continue;
      }
      case OP_LOADK: {
        setobj2s(L, ra, KBx(i));
        continue;
      }
      case OP_LOADBOOL: {
        setbvalue(ra, GETARG_B(i));
        if (GETARG_C(i)) pc++;  /* skip next instruction (if C) */
        continue;
      }
      case OP_LOADNIL: {
        TValue *rb = RB(i);
        do {
          setnilvalue(rb--);
        } while (rb >= ra);
        continue;
      }
      case OP_GETUPVAL: {
        int b = GETARG_B(i);
        setobj2s(L, ra, cl->upvals[b]->v);
        continue;
      }
      case OP_GETGLOBAL: {
        TValue g;
        TValue *rb = KBx(i);
        sethvalue(L, &g, cl->env);
        lua_assert(ttisstring(rb));
        Protect(luaV_gettable(L, &g, rb, ra));
        continue;
      }
      case OP_GETTABLE: {
        Protect(luaV_gettable(L, RB(i), RKC(i), ra));
        continue;
      }
      case OP_SETGLOBAL: {
        TValue g;
        sethvalue(L, &g, cl->env);
        lua_assert(ttisstring(KBx(i)));
        Protect(luaV_settable(L, &g, KBx(i), ra));
        continue;
      }
      case OP_SETUPVAL: {
        UpVal *uv = cl->upvals[GETARG_B(i)];
        setobj(L, uv->v, ra);
        luaC_barrier(L, uv, ra);
        continue;
      }
      case OP_SETTABLE: {
        Protect(luaV_settable(L, ra, RKB(i), RKC(i)));
        continue;
      }
      case OP_NEWTABLE: {
        int b = GETARG_B(i);
        int c = GETARG_C(i);
        sethvalue(L, ra, luaH_new(L, luaO_fb2int(b), luaO_fb2int(c)));
        Protect(luaC_checkGC(L));
        continue;
      }
      case OP_SELF: {
        StkId rb = RB(i);
        setobjs2s(L, ra+1, rb);
        Protect(luaV_gettable(L, rb, RKC(i), ra));
        continue;
      }
      case OP_ADD: {
        arith_op(luai_numadd, TM_ADD, try_addint);
        continue;
      }
      case OP_SUB: {
        arith_op(luai_numsub, TM_SUB, try_subint);
        continue;
      }
      case OP_MUL: {
        arith_op(luai_nummul, TM_MUL, try_mulint);
        continue;
      }
      case OP_DIV: {
        arith_op(luai_numdiv, TM_DIV, try_divint);
        continue;
      }
      case OP_MOD: {
        arith_op(luai_nummod, TM_MOD, try_modint);
        continue;
      }
      case OP_POW: {
        arith_op(luai_numpow, TM_POW, try_powint);
        continue;
      }
      case OP_UNM: {
        TValue *rb = RB(i);
#ifdef LUA_TINT
        if (ttisinteger(rb)) {
            if (try_unmint( ra, ivalue(rb) ))
                continue;
        }
#endif
        if (ttisnumber(rb)) {
          lua_Number nb = nvalue(rb);
          setnvalue(ra, luai_numunm(nb));
        }
        else {
          Protect(Arith(L, ra, rb, rb, TM_UNM));
        }
        continue;
      }
#if defined(LUA_BITWISE_OPERATORS)
      case OP_BOR: {
        logic_op(luai_logor, TM_BOR);
        continue;
      }
      case OP_BAND: {
        logic_op(luai_logand, TM_BAND);
        continue;
      }
      case OP_BXOR: {
        logic_op(luai_logxor, TM_BXOR);
        continue;
      }
      case OP_BLSHFT: {
        logic_op(luai_loglshft, TM_BRSHFT);
        continue;
      }
      case OP_BRSHFT: {
        logic_op(luai_logrshft, TM_BRSHFT);
        continue;
      }
      case OP_BNOT: {
        TValue *rb = RB(i);
        if (ttisnumber(rb)) {
          lua_Integer r;
          luai_lognot(r, nvalue(rb));
          setnvalue(ra, r);
        }
        else {
          Protect(Logic(L, ra, rb, rb, TM_BNOT));
        }
        continue;
      }
      case OP_INTDIV: {
        arith_op(luai_numintdiv, TM_DIV, try_divint);
        continue;
      }
#endif
      case OP_NOT: {
        int res = l_isfalse(RB(i));  /* next assignment may change this value */
        setbvalue(ra, res);
        continue;
      }
      case OP_LEN: {
        const TValue *rb = RB(i);
        switch (ttype(rb)) {
          case LUA_TTABLE: {
            setivalue(ra, luaH_getn(hvalue(rb)));
            break;
          }
          case LUA_TSTRING: {
            setivalue(ra, tsvalue(rb)->len);
            break;
          }
          default: {  /* try metamethod */
            Protect(
              if (!call_binTM(L, rb, luaO_nilobject, ra, TM_LEN))
                luaG_typeerror(L, rb, "get length of");
            )
          }
        }
        continue;
      }
      case OP_CONCAT: {
        int b = GETARG_B(i);
        int c = GETARG_C(i);
        Protect(luaV_concat(L, c-b+1, c); luaC_checkGC(L));
        setobjs2s(L, RA(i), base+b);
        continue;
      }
      case OP_JMP: {
        dojump(L, pc, GETARG_sBx(i));
        continue;
      }
      case OP_EQ: {
        TValue *rb = RKB(i);
        TValue *rc = RKC(i);
        Protect(
          if (equalobj(L, rb, rc) == GETARG_A(i))
            dojump(L, pc, GETARG_sBx(*pc));
        )
        pc++;
        continue;
      }
      case OP_LT: {
        Protect(
          if (luaV_lessthan(L, RKB(i), RKC(i)) == GETARG_A(i))
            dojump(L, pc, GETARG_sBx(*pc));
        )
        pc++;
        continue;
      }
      case OP_LE: {
        Protect(
          if (lessequal(L, RKB(i), RKC(i)) == GETARG_A(i))
            dojump(L, pc, GETARG_sBx(*pc));
        )
        pc++;
        continue;
      }
      case OP_TEST: {
        if (l_isfalse(ra) != GETARG_C(i))
          dojump(L, pc, GETARG_sBx(*pc));
        pc++;
        continue;
      }
      case OP_TESTSET: {
        TValue *rb = RB(i);
        if (l_isfalse(rb) != GETARG_C(i)) {
          setobjs2s(L, ra, rb);
          dojump(L, pc, GETARG_sBx(*pc));
        }
        pc++;
        continue;
      }
      case OP_CALL: {
        int b = GETARG_B(i);
        int nresults = GETARG_C(i) - 1;
        if (b != 0) L->top = ra+b;  /* else previous instruction set top */
        L->savedpc = pc;
        switch (luaD_precall(L, ra, nresults)) {
          case PCRLUA: {
            nexeccalls++;
            goto reentry;  /* restart luaV_execute over new Lua function */
          }
          case PCRC: {
            /* it was a C function (`precall' called it); adjust results */
            if (nresults >= 0) L->top = L->ci->top;
            base = L->base;
            continue;
          }
          default: {
            return;  /* yield */
          }
        }
      }
      case OP_TAILCALL: {
        int b = GETARG_B(i);
        if (b != 0) L->top = ra+b;  /* else previous instruction set top */
        L->savedpc = pc;
        lua_assert(GETARG_C(i) - 1 == LUA_MULTRET);
        switch (luaD_precall(L, ra, LUA_MULTRET)) {
          case PCRLUA: {
            /* tail call: put new frame in place of previous one */
            CallInfo *ci = L->ci - 1;  /* previous frame */
            int aux;
            StkId func = ci->func;
            StkId pfunc = (ci+1)->func;  /* previous function index */
            if (L->openupval) luaF_close(L, ci->base);
            L->base = ci->base = ci->func + ((ci+1)->base - pfunc);
            for (aux = 0; pfunc+aux < L->top; aux++)  /* move frame down */
              setobjs2s(L, func+aux, pfunc+aux);
            ci->top = L->top = func+aux;  /* correct top */
            lua_assert(L->top == L->base + clvalue(func)->l.p->maxstacksize);
            ci->savedpc = L->savedpc;
            ci->tailcalls++;  /* one more call lost */
            L->ci--;  /* remove new frame */
            goto reentry;
          }
          case PCRC: {  /* it was a C function (`precall' called it) */
            base = L->base;
            continue;
          }
          default: {
            return;  /* yield */
          }
        }
      }
      case OP_RETURN: {
        int b = GETARG_B(i);
        if (b != 0) L->top = ra+b-1;
        if (L->openupval) luaF_close(L, base);
        L->savedpc = pc;
        b = luaD_poscall(L, ra);
        if (--nexeccalls == 0)  /* was previous function running `here'? */
          return;  /* no: return */
        else {  /* yes: continue its execution */
          if (b) L->top = L->ci->top;
          lua_assert(isLua(L->ci));
          lua_assert(GET_OPCODE(*((L->ci)->savedpc - 1)) == OP_CALL);
          goto reentry;
        }
      }
      case OP_FORLOOP: {
		lua_Number step, idx, limit;
#ifdef LUA_TINT
        /* If all start,step and limit are integers, we don't need to 
         * check against overflow in the looping.
         * 
         * Note: Avoid use of "for i=1,math.huge do ..." on non-FPU
         *       architectures, since "math.huge" causes the slower
         *       non-integer fallback (use 99999 instead).
         */
        if (ttisinteger(ra) && ttisinteger(ra+1) && ttisinteger(ra+2)) {
          lua_Integer step = ivalue(ra+2);
          lua_Integer idx = ivalue(ra) + step; /* increment index */
          lua_Integer limit = ivalue(ra+1);
          if (step > 0 ? (idx <= limit) : (limit <= idx)) {
            dojump(L, pc, GETARG_sBx(i));  /* jump back */
            setivalue(ra, idx);  /* update internal index... */
            setivalue(ra+3, idx);  /* ...and external index */
          }
          continue;
        } 
        /* fallback to non-integer looping (don't use 'nvalue_fast', 
           some values may be integer!) 
        */
#endif
        step = nvalue(ra+2);
        idx = luai_numadd(nvalue(ra), step); /* increment index */
        limit = nvalue(ra+1);
        if (luai_numlt(0, step) ? luai_numle(idx, limit)
                                : luai_numle(limit, idx)) {
          dojump(L, pc, GETARG_sBx(i));  /* jump back */
          setnvalue(ra, idx);  /* update internal index... */
          setnvalue(ra+3, idx);  /* ...and external index */
        }
        continue;
      }
      case OP_FORPREP: {
        const TValue *init = ra;
        const TValue *plimit = ra+1;
        const TValue *pstep = ra+2;
        L->savedpc = pc;  /* next steps may throw errors */
        if (!tonumber(init, ra))
          luaG_runerror(L, LUA_QL("for") " initial value must be a number");
        else if (!tonumber(plimit, ra+1))
          luaG_runerror(L, LUA_QL("for") " limit must be a number");
        else if (!tonumber(pstep, ra+2))
          luaG_runerror(L, LUA_QL("for") " step must be a number");
#ifdef LUA_TINT
        /* Step back one value (must make sure also that is safely within range)
         */
        if ( ttisinteger(ra) && ttisinteger(pstep) &&
              try_subint( ra, ivalue(ra), ivalue(pstep) ) )  { /*done*/ }
        else { 
            /* don't use 'nvalue_fast()', the values may be integer */
            setnvalue(ra, luai_numsub(nvalue(ra), nvalue(pstep)));
        }
#else
        setnvalue(ra, luai_numsub(nvalue(ra), nvalue(pstep)));
#endif
        dojump(L, pc, GETARG_sBx(i));
        continue;
      }
      case OP_TFORLOOP: {
        StkId cb = ra + 3;  /* call base */
        setobjs2s(L, cb+2, ra+2);
        setobjs2s(L, cb+1, ra+1);
        setobjs2s(L, cb, ra);
        L->top = cb+3;  /* func. + 2 args (state and index) */
        Protect(luaD_call(L, cb, GETARG_C(i)));
        L->top = L->ci->top;
        cb = RA(i) + 3;  /* previous call may change the stack */
        if (!ttisnil(cb)) {  /* continue loop? */
          setobjs2s(L, cb-1, cb);  /* save control variable */
          dojump(L, pc, GETARG_sBx(*pc));  /* jump back */
        }
        pc++;
        continue;
      }
      case OP_SETLIST: {
        int n = GETARG_B(i);
        int c = GETARG_C(i);
        int last;
        Table *h;
        if (n == 0) {
          n = cast_int(L->top - ra) - 1;
          L->top = L->ci->top;
        }
        if (c == 0) c = cast_int(*pc++);
        runtime_check(L, ttistable(ra));
        h = hvalue(ra);
        last = ((c-1)*LFIELDS_PER_FLUSH) + n;
        if (last > h->sizearray)  /* needs more space? */
          luaH_resizearray(L, h, last);  /* pre-alloc it at once */
        for (; n > 0; n--) {
          TValue *val = ra+n;
          setobj2t(L, luaH_setnum(L, h, last--), val);
          luaC_barriert(L, h, val);
        }
        continue;
      }
      case OP_CLOSE: {
        luaF_close(L, ra);
        continue;
      }
      case OP_CLOSURE: {
        Proto *p;
        Closure *ncl;
        int nup, j;
        p = cl->p->p[GETARG_Bx(i)];
        nup = p->nups;
        ncl = luaF_newLclosure(L, nup, cl->env);
        ncl->l.p = p;
        for (j=0; j<nup; j++, pc++) {
          if (GET_OPCODE(*pc) == OP_GETUPVAL)
            ncl->l.upvals[j] = cl->upvals[GETARG_B(*pc)];
          else {
            lua_assert(GET_OPCODE(*pc) == OP_MOVE);
            ncl->l.upvals[j] = luaF_findupval(L, base + GETARG_B(*pc));
          }
        }
        setclvalue(L, ra, ncl);
        Protect(luaC_checkGC(L));
        continue;
      }
      case OP_VARARG: {
        int b = GETARG_B(i) - 1;
        int j;
        CallInfo *ci = L->ci;
        int n = cast_int(ci->base - ci->func) - cl->p->numparams - 1;
        if (b == LUA_MULTRET) {
          Protect(luaD_checkstack(L, n));
          ra = RA(i);  /* previous call may change the stack */
          b = n;
          L->top = ra + n;
        }
        for (j = 0; j < b; j++) {
          if (j < n) {
            setobjs2s(L, ra + j, ci->base - n + j);
          }
          else {
            setnilvalue(ra + j);
          }
        }
        continue;
      }
    }
  }
}

