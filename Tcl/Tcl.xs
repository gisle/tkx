/*
 * Tcl.xs --
 *
 *	This file contains XS code for the Perl's Tcl bridge module.
 *
 * Copyright (c) 1994-1997, Malcolm Beattie
 * Copyright (c) 2003-2004, Vadim Konovalov
 * Copyright (c) 2004 ActiveState Corp., a division of Sophos PLC
 *
 * RCS: @(#) $Id: Tcl.xs,v 1.33 2004/05/10 23:54:20 hobbs2 Exp $
 */

#define PERL_NO_GET_CONTEXT     /* we want efficiency */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifndef DEBUG_REFCOUNTS
#define DEBUG_REFCOUNTS 0
#endif

/*
 * Until we update for 8.4 CONST-ness
 */
#define USE_NON_CONST

/*
 * Both Perl and Tcl use these macros
 */
#undef STRINGIFY
#undef JOIN

#include <tcl.h>

#ifdef USE_TCL_STUBS
/*
 * If we use the Tcl stubs mechanism, this provides us Tcl version
 * and direct dll independence, but we must force the loading of
 * the dll ourselves based on a set of heuristics in NpLoadLibrary.
 */

#ifndef TCL_LIB_FILE
# ifdef WIN32
#   define TCL_LIB_FILE "tcl84.dll"
# else
#   define TCL_LIB_FILE "libtcl8.4.so"
# endif
#endif

/*
 * Default directory in which to look for Tcl/Tk libraries.  The
 * symbol is defined by Makefile.
 */

#ifndef LIB_RUNTIME_DIR
#   define LIB_RUNTIME_DIR "."
#endif
static char defaultLibraryDir[sizeof(LIB_RUNTIME_DIR)+200] = LIB_RUNTIME_DIR;

#ifdef WIN32

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#undef WIN32_LEAN_AND_MEAN
#define dlopen(libname, flags)	LoadLibrary(libname)
#define dlsym(handle, symbol)	GetProcAddress((HINSTANCE) handle, symbol)
#define dlclose(path)		((void *) FreeLibrary((HMODULE) path))
#define snprintf _snprintf

#else

#include <dlfcn.h>
#define HMODULE void *
#ifndef MAX_PATH
#define MAX_PATH 1024
#endif

#endif

/*
 * Tcl library handle
 */
static HMODULE tclHandle = NULL;

static Tcl_Interp *g_Interp = NULL;
static int (* tclKit_AppInit)(Tcl_Interp *) = NULL;

#else

/*
 * !USE_TCL_STUBS
 */

static int (* tclKit_AppInit)(Tcl_Interp *) = Tcl_Init;

#endif

typedef Tcl_Interp *Tcl;
typedef AV *Tcl__Var;

/*
 * Variables denoting the Tcl object types defined in the core.
 */

static Tcl_ObjType *tclBooleanTypePtr = NULL;
static Tcl_ObjType *tclByteArrayTypePtr = NULL;
static Tcl_ObjType *tclDoubleTypePtr = NULL;
static Tcl_ObjType *tclIntTypePtr = NULL;
static Tcl_ObjType *tclListTypePtr = NULL;
static Tcl_ObjType *tclStringTypePtr = NULL;
static Tcl_ObjType *tclWideIntTypePtr = NULL;

/*
 * This tells us whether Tcl is in a "callable" state.  Set to 1 in BOOT
 * and 0 in Tcl__Finalize (END).  Once finalized, we should not make any
 * more calls to Tcl_* APIs.
 * hvInterps is a hash that records all live interps, so that we can
 * force their deletion before the finalization.
 */
static int initialized = 0;
static HV *hvInterps = NULL;

/*
 * FUNCTIONS
 */

#ifdef USE_TCL_STUBS
/*
 *----------------------------------------------------------------------
 *
 * NpLoadLibrary --
 *
 *
 * Results:
 *	Stores the handle of the library found in tclHandle and the
 *	name it successfully loaded from in dllFilename (if dllFilenameSize
	is != 0).
 *
 * Side effects:
 *	Loads the library - user needs to dlclose it..
 *
 *----------------------------------------------------------------------
 */

static int
NpLoadLibrary(pTHX_ HMODULE *tclHandle, char *dllFilename, int dllFilenameSize)
{
    char *pos, *envdll, libname[MAX_PATH];
    HMODULE handle = (HMODULE) NULL;

    /*
     * Try a user-supplied Tcl dll to start with.
     */
    envdll = getenv("PERL_TCL_DLL");
    if (envdll != NULL) {
	handle = dlopen(envdll, RTLD_NOW | RTLD_GLOBAL);
	if (handle) {
	    *tclHandle = handle;
	    if (dllFilenameSize > 0) {
		memcpy(dllFilename, envdll, dllFilenameSize);
	    }
	    return TCL_OK;
	}
    }

    if (!handle) {
	if (strlen(TCL_LIB_FILE) < 3) {
	    warn("Invalid base Tcl library filename provided: '%s'",
		    TCL_LIB_FILE);
	    return TCL_ERROR;
	}

	/* Try based on full path. */
	snprintf(libname, MAX_PATH-1, "%s/%s",
		defaultLibraryDir, TCL_LIB_FILE);
	handle = dlopen(libname, RTLD_NOW | RTLD_GLOBAL);
	if (!handle) {
	    /* Try based on anywhere in the path. */
	    strcpy(libname, TCL_LIB_FILE);
	    handle = dlopen(libname, RTLD_NOW | RTLD_GLOBAL);
	}
	if (!handle) {
	    /* Try different versions anywhere in the path. */
	    pos = strstr(libname, "tcl8")+4;
	    if (*pos == '.') {
		pos++;
	    }
	    *pos = '9'; /* count down from '8' to '4'*/
	    while (!handle && (--*pos > '3')) {
		handle = dlopen(libname, RTLD_NOW | RTLD_GLOBAL);
	    }
	}
    }

#ifdef WIN32
    if (!handle) {
	char path[MAX_PATH], vers[MAX_PATH];
	DWORD result, size = MAX_PATH;
	HKEY regKey;
#define TCL_REG_DIR_KEY "Software\\ActiveState\\ActiveTcl"

	result = RegOpenKeyEx(HKEY_LOCAL_MACHINE, TCL_REG_DIR_KEY, 0,
		KEY_READ, &regKey);
	if (result != ERROR_SUCCESS) {
	    warn("Could not access registry \"HKLM\\%s\"\n", TCL_REG_DIR_KEY);

	    result = RegOpenKeyEx(HKEY_CURRENT_USER, TCL_REG_DIR_KEY, 0,
		    KEY_READ, &regKey);
	    if (result != ERROR_SUCCESS) {
		warn("Could not access registry \"HKCU\\%s\"\n",
			TCL_REG_DIR_KEY);
		return TCL_ERROR;
	    }
	}

	result = RegQueryValueEx(regKey, "CurrentVersion", NULL, NULL,
		vers, &size);
	RegCloseKey(regKey);
	if (result != ERROR_SUCCESS) {
	    warn("Could not access registry \"%s\" CurrentVersion\n",
		    TCL_REG_DIR_KEY);
	    return TCL_ERROR;
	}

	snprintf(path, MAX_PATH-1, "%s\\%s", TCL_REG_DIR_KEY, vers);

	result = RegOpenKeyEx(HKEY_LOCAL_MACHINE, path, 0, KEY_READ, &regKey);
	if (result != ERROR_SUCCESS) {
	    warn("Could not access registry \"%s\"\n", path);
	    return TCL_ERROR;
	}

	size = MAX_PATH;
	result = RegQueryValueEx(regKey, NULL, NULL, NULL, path, &size);
	RegCloseKey(regKey);
	if (result != ERROR_SUCCESS) {
	    warn("Could not access registry \"%s\" Default\n", TCL_REG_DIR_KEY);
	    return TCL_ERROR;
	}

	warn("Found current Tcl installation at \"%s\"\n", path);

	snprintf(libname, MAX_PATH-1, "%s\\bin\\%s", path, TCL_LIB_FILE);
	handle = dlopen(libname, RTLD_NOW | RTLD_GLOBAL);
    }
#endif

    if (!handle) {
	warn("NpLoadLibrary: could not find Tcl dll\n");
	return TCL_ERROR;
    }
    *tclHandle = handle;
    if (dllFilenameSize > 0) {
	memcpy(dllFilename, libname, dllFilenameSize);
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * NpInitialize --
 *
 *	Create the main interpreter.
 *
 * Results:
 *	The pointer to the main interpreter.
 *
 * Side effects:
 *	Will panic if called twice. (Must call DestroyMainInterp in between)
 *
 *----------------------------------------------------------------------
 */

static int
NpInitialize(pTHX_ SV *X)
{
    static Tcl_Interp * (* createInterp)() = NULL;
    static void (* findExecutable)(char *) = NULL;
    /*
     * We want the Tcl_InitStubs func static to ourselves - before Tcl
     * is loaded dyanmically and possibly changes it.
     */
    static CONST char *(*initstubs)(Tcl_Interp *, CONST char *, int)
	= Tcl_InitStubs;
    char dllFilename[MAX_PATH];
    dllFilename[0] = '\0';

#ifdef USE_TCL_STUBS
    /*
     * Determine the libname and version number dynamically
     */
    if (tclHandle == NULL) {
	/*
	 * First see if some other part didn't already load Tcl.
	 */
	createInterp = (Tcl_Interp * (*)()) dlsym(tclHandle,
		"Tcl_CreateInterp");

	if (createInterp == NULL) {
	    if (NpLoadLibrary(aTHX_ &tclHandle, dllFilename, MAX_PATH)
		    != TCL_OK) {
		warn("Failed to load Tcl dll!");
		return TCL_ERROR;
	    }
	}

	createInterp = (Tcl_Interp * (*)()) dlsym(tclHandle,
		"Tcl_CreateInterp");
	if (createInterp == NULL) {
#ifndef WIN32
	    char *error = dlerror();
	    if (error != NULL) {
		warn(error);
	    }
#endif
	    return TCL_ERROR;
	}
	findExecutable = (void (*)(char *)) dlsym(tclHandle,
		"Tcl_FindExecutable");

	tclKit_AppInit = (int (*)(Tcl_Interp *)) dlsym(tclHandle,
		"TclKit_AppInit");
    }
#else
    createInterp   = Tcl_CreateInterp;
    findExecutable = Tcl_FindExecutable;
#endif

#ifdef WIN32
    if (dllFilename[0] == '\0') {
	GetModuleFileNameA((HINSTANCE) tclHandle, dllFilename, MAX_PATH);
    }
    findExecutable(dllFilename);
#else
    findExecutable(X && SvPOK(X) ? SvPV_nolen(X) : NULL);
#endif

    g_Interp = createInterp();
    if (g_Interp == (Tcl_Interp *) NULL) {
	warn("Failed to create main Tcl interpreter!");
	return TCL_ERROR;
    }

    /*
     * Until Tcl_InitStubs is called, we cannot make any Tcl/Tk API
     * calls without grabbing them by symbol out of the dll.
     * This will be Tcl_PkgRequire for non-stubs builds.
     */
    if (initstubs(g_Interp, "8.4", 0) == NULL) {
	warn("Failed to initialize Tcl stubs!");
	return TCL_ERROR;
    }

    /*
     * If we didn't find TclKit_AppInit, then this is a regular Tcl
     * installation, so invoke Tcl_Init.
     * Otherwise, we need to set the kit path to indicate we want to
     * use the dll as our base kit.
     */
    if (tclKit_AppInit == NULL) {
	tclKit_AppInit = Tcl_Init;
    } else {
	char * (* tclKit_SetKitPath)(char *) = NULL;
	/*
	 * We need to see if this has TclKit_SetKitPath
	 */
	if ((dllFilename[0] != '\0')
		&& (tclKit_SetKitPath = (char * (*)(char *)) dlsym(tclHandle,
			    "TclKit_SetKitPath")) != NULL) {
	    /*
	     * XXX: Need to figure out how to populate dllFilename if
	     * NpLoadLibrary didn't do it for us on Unix.
	     */
	    tclKit_SetKitPath(dllFilename);
	}
    }
    if (tclKit_AppInit(g_Interp) != TCL_OK) {
	CONST84 char *msg = Tcl_GetVar(g_Interp, "errorInfo", TCL_GLOBAL_ONLY);
	warn("Failed to initialize Tcl:\n%s", msg);
	return TCL_ERROR;
    }

    /*
     * Hold on to the interp handle until finalize, as special
     * kit-based interps require the first initialized interp to
     * remain alive.
     */

    return TCL_OK;
}
#endif

#if DEBUG_REFCOUNTS
static void
check_refcounts(Tcl_Obj *objPtr) {
    int rc = objPtr->refCount;
    if (rc != 1) {
	fprintf(stderr, "objPtr %p refcount %d\n", objPtr, rc); fflush(stderr);
    }
    if (objPtr->typePtr == tclListTypePtr) {
	int objc, i;
	Tcl_Obj **objv;

	Tcl_ListObjGetElements(NULL, objPtr, &objc, &objv);
	for (i = 0; i < objc; i++) {
	    check_refcounts(objv[i]);
	}
    }
}
#endif

static int
has_highbit(CONST char *s, int len)
{
    CONST char *e = s + len;
    while (s < e) {
	if (*s++ & 0x80)
	    return 1;
    }
    return 0;
}

static SV *
SvFromTclObj(pTHX_ Tcl_Obj *objPtr)
{
    SV *sv;
    int len;
    char *str;

    if (objPtr == NULL) {
	/*
	 * Use newSV(0) instead of &PL_sv_undef as it may be stored in an AV.
	 * It also provides symmetry with the other newSV* calls below.
	 * This SV will also be mortalized later.
	 */
	sv = newSV(0);
    }
    else if (objPtr->typePtr == tclIntTypePtr) {
	sv = newSViv(objPtr->internalRep.longValue);
    }
    else if (objPtr->typePtr == tclDoubleTypePtr) {
	sv = newSVnv(objPtr->internalRep.doubleValue);
    }
    else if (objPtr->typePtr == tclBooleanTypePtr) {
	/*
	 * Booleans can originate as words (yes/true/...), so if there is a
	 * string rep, use it instead.  We could check if the first byte
	 * isdigit().  No need to check utf-8 as the all valid boolean words
	 * are ascii-7.
	 */
	if (objPtr->typePtr == NULL) {
	    sv = newSVsv(boolSV(objPtr->internalRep.longValue != 0));
	} else {
	    str = Tcl_GetStringFromObj(objPtr, &len);
	    sv = newSVpvn(str, len);
	}
    }
    else if (objPtr->typePtr == tclByteArrayTypePtr) {
	str = Tcl_GetByteArrayFromObj(objPtr, &len);
	sv = newSVpvn(str, len);
    }
    else if (objPtr->typePtr == tclListTypePtr) {
	/*
	 * tclListTypePtr should become an AV.
	 * This code needs to reconcile with G_ context in prepare_Tcl_result
	 * and user's expectations of how data will be passed in.  The key is
	 * that a stringified-list and pure-list should be operable in the
	 * same way in Perl.
	 *
	 * We have to watch for "empty" lists, which could equate to the
	 * empty string.  Tcl's literal object sharing means that "" could
	 * be typed as a list, although we don't want to see it that way.
	 * Just treat empty list objects as an empty (not undef) SV.
	 */
	int objc;
	Tcl_Obj **objv;

	Tcl_ListObjGetElements(NULL, objPtr, &objc, &objv);
	if (objc) {
	    int i;
	    AV *av = newAV();

	    for (i = 0; i < objc; i++) {
		av_push(av, SvFromTclObj(aTHX_ objv[i]));
	    }
	    sv = newRV_noinc((SV *) av);
	}
	else {
	    sv = newSVpvn("", 0);
	}
    }
    /* tclStringTypePtr is true unicode */
    /* tclWideIntTypePtr is 64-bit int */
    else {
	str = Tcl_GetStringFromObj(objPtr, &len);
	sv = newSVpvn(str, len);
	/* should turn on, but let's check this first for efficiency */
	if (len && has_highbit(str, len)) {
	    SvUTF8_on(sv);
	}
    }
    return sv;
}

/*
 * Create a Tcl_Obj from a Perl SV.
 * Return Tcl_Obj with refcount = 0.  Caller should call Tcl_IncrRefCount
 * or pass of to function that does (manage object lifetime).
 */
static Tcl_Obj *
TclObjFromSv(pTHX_ SV *sv)
{
    Tcl_Obj *objPtr = NULL;

    if (SvGMAGICAL(sv))
	mg_get(sv);

    if (SvROK(sv) && !SvOBJECT(SvRV(sv)) && (SvTYPE(SvRV(sv)) == SVt_PVAV)) {
	/*
	 * Recurse into ARRAYs, turning them into Tcl list Objs
	 */
	SV **svp;
	AV *av    = (AV *) SvRV(sv);
	I32 avlen = av_len(av);
	int i;

	objPtr = Tcl_NewListObj(0, (Tcl_Obj **) NULL);

	for (i = 0; i <= avlen; i++) {
	    svp = av_fetch(av, i, FALSE);
	    if (svp == NULL) {
		/* watch for sparse arrays - translate as empty element */
		/* XXX: Is this handling refcount on NewObj right? */
		Tcl_ListObjAppendElement(NULL, objPtr, Tcl_NewObj());
	    } else {
		if ((AV *) SvRV(*svp) == av) {
		    /* XXX: Is this a proper check for cyclical reference? */
		    croak("cyclical array reference found");
		    abort();
		}
		Tcl_ListObjAppendElement(NULL, objPtr,
			TclObjFromSv(aTHX_ sv_mortalcopy(*svp)));
	    }
	}
    }
    else if (SvPOK(sv)) {
	STRLEN length;
	char *str = SvPV(sv, length);
	/*
	 * Tcl's "String" object expects utf-8 strings.  If we aren't sure
	 * that we have a utf-8 data, pass it as a Tcl ByteArray (C char*).
	 *
	 * XXX Possible optimization opportunity here.  Tcl will actually
	 * XXX accept and handle most latin-1 char sequences correctly, but
	 * XXX not blocks of truly binary data.  This code is 100% correct,
	 * XXX but could be tweaked to improve performance.
	 */
	if (SvUTF8(sv)) {
	    objPtr = Tcl_NewStringObj(str, length);
	} else {
	    objPtr = Tcl_NewByteArrayObj(str, length);
	}
    }
    else if (SvNOK(sv)) {
	double dval = SvNV(sv);
	int ival;
	/*
	 * Perl does math with doubles by default, so 0 + 1 == 1.0.
	 * Check for int-equiv doubles and make those ints.
	 * XXX This check possibly only necessary for <=5.6.x
	 */
	if (((double)(ival = SvIV(sv)) == dval)) {
	    objPtr = Tcl_NewIntObj(ival);
	} else {
	    objPtr = Tcl_NewDoubleObj(dval);
	}
    }
    else if (SvIOK(sv)) {
	objPtr = Tcl_NewIntObj(SvIV(sv));
    }
    else {
	/*
	 * Catch-all
	 * XXX: Should we recurse other REFs, or better to stringify them?
	 */
	STRLEN length;
	char *str = SvPV(sv, length);
	/*
	 * Tcl's "String" object expects utf-8 strings.  If we aren't sure
	 * that we have a utf-8 data, pass it as a Tcl ByteArray (C char*).
	 */
	if (SvUTF8(sv)) {
	    objPtr = Tcl_NewStringObj(str, length);
	} else {
	    objPtr = Tcl_NewByteArrayObj(str, length);
	}
    }

    return objPtr;
}

int Tcl_EvalInPerl(ClientData clientData, Tcl_Interp *interp,
	int objc, Tcl_Obj *CONST objv[])
{
    dTHX; /* fetch context */
    dSP;
    I32 count;
    SV *sv;
    int rc;

    /*
     * This is the command created in Tcl to eval stuff in Perl
     */

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "string");
    }

    ENTER;
    SAVETMPS;

    PUSHMARK(sp);
    PUTBACK;
    count = perl_eval_sv(sv_2mortal(SvFromTclObj(aTHX_ objv[1])),
	    G_EVAL|G_SCALAR);
    SPAGAIN;

    if (SvTRUE(ERRSV)) {
	Tcl_SetResult(interp, SvPV_nolen(ERRSV), TCL_VOLATILE);
	POPs; /* pop the undef off the stack */
	rc = TCL_ERROR;
    }
    else {
	if (count != 1) {
	    croak("Perl sub bound to Tcl proc returned %d args, expected 1",
		    count);
	}
	sv = POPs; /* pop the undef off the stack */

	if (SvOK(sv)) {
	    Tcl_Obj *objPtr = TclObjFromSv(aTHX_ sv);
	    /* Tcl_SetObjResult will incr refcount */
	    Tcl_SetObjResult(interp, objPtr);
	}
	rc = TCL_OK;
    }

    PUTBACK;
    /*
     * If the routine returned undef, it indicates that it has done the
     * SetResult itself and that we should return TCL_ERROR
     */

    FREETMPS;
    LEAVE;
    return rc;
}

int Tcl_PerlCallWrapper(ClientData clientData, Tcl_Interp *interp,
	int objc, Tcl_Obj *CONST objv[])
{
    dTHX; /* fetch context */
    dSP;
    AV *av = (AV *) clientData;
    I32 count;
    SV *sv;
    int rc;

    /*
     * av = [$perlsub, $realclientdata, $interp, $deleteProc]
     * (where $deleteProc is optional but we don't need it here anyway)
     */

    if (AvFILL(av) != 2 && AvFILL(av) != 3)
	croak("bad clientdata argument passed to Tcl_PerlCallWrapper");

    ENTER;
    SAVETMPS;

    PUSHMARK(sp);
    EXTEND(sp, objc + 2);
    /*
     * Place clientData and original interp on the stack, then the
     * Tcl object invoke list, including the command name.  Users
     * who only want the args from Tcl can splice off the first 3 args
     */
    PUSHs(sv_mortalcopy(*av_fetch(av, 1, FALSE)));
    PUSHs(sv_mortalcopy(*av_fetch(av, 2, FALSE)));
    while (objc--) {
	PUSHs(sv_2mortal(SvFromTclObj(aTHX_ *objv++)));
    }
    PUTBACK;
    count = perl_call_sv(*av_fetch(av, 0, FALSE), G_EVAL|G_SCALAR);
    SPAGAIN;

    if (SvTRUE(ERRSV)) {
	Tcl_SetResult(interp, SvPV_nolen(ERRSV), TCL_VOLATILE);
	POPs; /* pop the undef off the stack */
	rc = TCL_ERROR;
    }
    else {
	if (count != 1) {
	    croak("Perl sub bound to Tcl proc returned %d args, expected 1",
		    count);
	}
	sv = POPs; /* pop the undef off the stack */

	if (SvOK(sv)) {
	    Tcl_Obj *objPtr = TclObjFromSv(aTHX_ sv);
	    /* Tcl_SetObjResult will incr refcount */
	    Tcl_SetObjResult(interp, objPtr);
	}
	rc = TCL_OK;
    }

    PUTBACK;
    /*
     * If the routine returned undef, it indicates that it has done the
     * SetResult itself and that we should return TCL_ERROR
     */

    FREETMPS;
    LEAVE;
    return rc;
}

void
Tcl_PerlCallDeleteProc(ClientData clientData)
{
    dTHX; /* fetch context */
    AV *av = (AV *) clientData;

    /*
     * av = [$perlsub, $realclientdata, $interp, $deleteProc]
     * (where $deleteProc is optional but we don't need it here anyway)
     */

    if (AvFILL(av) == 3) {
	dSP;

	PUSHMARK(sp);
	EXTEND(sp, 1);
	PUSHs(sv_mortalcopy(*av_fetch(av, 1, FALSE)));
	PUTBACK;
	(void) perl_call_sv(*av_fetch(av, 3, FALSE), G_SCALAR|G_DISCARD);
    }
    else if (AvFILL(av) != 2) {
	croak("bad clientdata argument passed to Tcl_PerlCallDeleteProc");
    }

    SvREFCNT_dec(av);
}

void
prepare_Tcl_result(pTHX_ Tcl interp, char *caller)
{
    dSP;
    Tcl_Obj *objPtr, **objv;
    int gimme, objc, i;

    objPtr = Tcl_GetObjResult(interp);

    gimme = GIMME_V;
    if (gimme == G_SCALAR) {
	/*
	 * This checks Tcl_Obj type.  XPUSH not needed because we
	 * are called when there is enough space on the stack.
	 */
	PUSHs(sv_2mortal(SvFromTclObj(aTHX_ objPtr)));
    }
    else if (gimme == G_ARRAY) {
	if (Tcl_ListObjGetElements(interp, objPtr, &objc, &objv)
		!= TCL_OK) {
	    croak("%s called in list context did not return a valid Tcl list",
		    caller);
	}
	if (objc) {
	    EXTEND(sp, objc);
	    for (i = 0; i < objc; i++) {
		/*
		 * This checks Tcl_Obj type
		 */
		PUSHs(sv_2mortal(SvFromTclObj(aTHX_ objv[i])));
	    }
	}
    }
    else {
	/* G_VOID context - ignore result */
    }
    PUTBACK;
    return;
}

char *
var_trace(ClientData clientData, Tcl_Interp *interp,
	char *name1, char *name2, int flags)
{
    dTHX; /* fetch context */

    if (flags & TCL_TRACE_READS) {
        warn("TCL_TRACE_READS\n");
    }
    else if (flags & TCL_TRACE_WRITES) {
        warn("TCL_TRACE_WRITES\n");
    }
    else if (flags & TCL_TRACE_ARRAY) {
        warn("TCL_TRACE_ARRAY\n");
    }
    else if (flags & TCL_TRACE_UNSETS) {
        warn("TCL_TRACE_UNSETS\n");
    }
    return 0;
}

MODULE = Tcl	PACKAGE = Tcl	PREFIX = Tcl_

SV *
Tcl_new(class = "Tcl")
	char *	class
    CODE:
	RETVAL = newSV(0);
	/*
	 * We might consider Tcl_Preserve/Tcl_Release of the interp.
	 */
	if (initialized) {
	    Tcl interp = Tcl_CreateInterp();
	    /*
	     * Add to the global hash of live interps.
	     */
	    if (hvInterps) {
		(void) hv_store(hvInterps, (const char *) &interp,
			sizeof(Tcl), &PL_sv_undef, 0);
	    }
	    sv_setref_pv(RETVAL, class, (void*)interp);
	}
    OUTPUT:
	RETVAL

char *
Tcl_result(interp)
	Tcl	interp
    CODE:
	if (initialized) {
	    RETVAL = Tcl_GetStringResult(interp);
	}
    OUTPUT:
	RETVAL

void
Tcl_Eval(interp, script)
	Tcl	interp
	SV *	script
	SV *	interpsv = ST(0);
	STRLEN	length = NO_INIT
	char *cscript = NO_INIT
    PPCODE:
	if (!initialized) { return; }
	(void) sv_2mortal(SvREFCNT_inc(interpsv));
	PUTBACK;
	Tcl_ResetResult(interp);
	/* sv_mortalcopy here prevents stringifying script - necessary ?? */
	cscript = SvPV(sv_mortalcopy(script), length);
	if (Tcl_EvalEx(interp, cscript, length, 0) != TCL_OK) {
	    croak(Tcl_GetStringResult(interp));
	}
	prepare_Tcl_result(aTHX_ interp, "Tcl::Eval");
	SPAGAIN;

void
Tcl_EvalFile(interp, filename)
	Tcl	interp
	char *	filename
	SV *	interpsv = ST(0);
    PPCODE:
	if (!initialized) { return; }
	(void) sv_2mortal(SvREFCNT_inc(interpsv));
	PUTBACK;
	Tcl_ResetResult(interp);
	if (Tcl_EvalFile(interp, filename) != TCL_OK) {
	    croak(Tcl_GetStringResult(interp));
	}
	prepare_Tcl_result(aTHX_ interp, "Tcl::EvalFile");
	SPAGAIN;

void
Tcl_GlobalEval(interp, script)
	Tcl	interp
	SV *	script
	SV *	interpsv = ST(0);
	STRLEN	length = NO_INIT
	char *cscript = NO_INIT
    PPCODE:
	if (!initialized) { return; }
	(void) sv_2mortal(SvREFCNT_inc(interpsv));
	PUTBACK;
	Tcl_ResetResult(interp);
	/* sv_mortalcopy here prevents stringifying script - necessary ?? */
	cscript = SvPV(sv_mortalcopy(script), length);
	if (Tcl_EvalEx(interp, cscript, length, TCL_EVAL_GLOBAL) != TCL_OK) {
	    croak(Tcl_GetStringResult(interp));
	}
	prepare_Tcl_result(aTHX_ interp, "Tcl::GlobalEval");
	SPAGAIN;

void
Tcl_EvalFileHandle(interp, handle)
	Tcl	interp
	PerlIO*	handle
	int	append = 0;
	SV *	interpsv = ST(0);
	SV *	sv = sv_newmortal();
	char *	s = NO_INIT
    PPCODE:
	if (!initialized) { return; }
	(void) sv_2mortal(SvREFCNT_inc(interpsv));
	PUTBACK;
        while (s = sv_gets(sv, handle, append))
	{
            if (!Tcl_CommandComplete(s))
		append = 1;
	    else
	    {
		Tcl_ResetResult(interp);
		if (Tcl_Eval(interp, s) != TCL_OK)
		    croak(Tcl_GetStringResult(interp));
		append = 0;
	    }
	}
	if (append)
	    croak("unexpected end of file in Tcl::EvalFileHandle");
	prepare_Tcl_result(aTHX_ interp, "Tcl::EvalFileHandle");
	SPAGAIN;

void
Tcl_invoke(interp, sv, ...)
	Tcl		interp
	SV *		sv
    PPCODE:
	{
	    /*
	     * 'Tcl::invoke' invokes the command directly, avoiding
	     * command tracing and the ::unknown mechanism.
	     */
#define NUM_OBJS 16
	    Tcl_Obj     *baseobjv[NUM_OBJS];
	    Tcl_Obj    **objv = baseobjv;
	    char        *cmdName;
	    int          objc, i, result;
	    STRLEN       length;
	    Tcl_CmdInfo	 cmdinfo;

	    if (!initialized) { return; }

	    objv = baseobjv;
	    objc = items-1;
	    if (objc > NUM_OBJS) {
		New(666, objv, objc, Tcl_Obj *);
	    }

	    SP += items;
	    PUTBACK;

	    /* Verify first arg is a Tcl command */
	    cmdName = SvPV(sv, length);
	    if (!Tcl_GetCommandInfo(interp, cmdName, &cmdinfo)) {
		croak("Tcl procedure '%s' not found", cmdName);
	    }

	    if (cmdinfo.objProc && cmdinfo.isNativeObjectProc) {
		/*
		 * We might want to check that this isn't
		 * TclInvokeStringCommand, which just means we waste time
		 * making Tcl_Obj's.
		 *
		 * Emulate TclInvokeObjectCommand (from Tcl), namely create the
		 * object argument array "objv" before calling right procedure
		 */
		objv[0] = Tcl_NewStringObj(cmdName, length);
		Tcl_IncrRefCount(objv[0]);
		for (i = 1; i < objc; i++) {
		    /*
		     * Use efficient Sv to Tcl_Obj conversion.
		     * This returns Tcl_Obj with refcount 1.
		     * This can cause recursive calls if we have tied vars.
		     */
		    objv[i] = TclObjFromSv(aTHX_ sv_mortalcopy(ST(i+1)));
		    Tcl_IncrRefCount(objv[i]);
		}
		SP -= items;
		PUTBACK;

		/*
		 * Result interp result and invoke the command's object-based
		 * Tcl_ObjCmdProc.
		 */
#if DEBUG_REFCOUNTS
		for (i = 1; i < objc; i++) { check_refcounts(objv[i]); }
#endif
		Tcl_ResetResult(interp);
		result = (*cmdinfo.objProc)(cmdinfo.objClientData, interp,
			objc, objv);

		/*
		 * Decrement ref count for first arg, others decr'd below
		 */
		Tcl_DecrRefCount(objv[0]);
	    }
	    else {
		/*
		 * we have cmdinfo.objProc==0
		 * prepare string arguments into argv (1st is already done)
		 * and call found procedure
		 */
		char  *baseargv[NUM_OBJS];
		char **argv = baseargv;

		if (objc > NUM_OBJS) {
		    New(666, argv, objc, char *);
		}

		argv[0] = cmdName;
		for (i = 1; i < objc; i++) {
		    /*
		     * We need the inefficient round-trip through Tcl_Obj to
		     * ensure that we are listify-ing correctly.
		     * This can cause recursive calls if we have tied vars.
		     */
		    objv[i] = TclObjFromSv(aTHX_ sv_mortalcopy(ST(i+1)));
		    Tcl_IncrRefCount(objv[i]);
		    argv[i] = Tcl_GetString(objv[i]);
		}
		SP -= items;
		PUTBACK;

		/*
		 * Result interp result and invoke the command's string-based
		 * procedure.
		 */
#if DEBUG_REFCOUNTS
		for (i = 1; i < objc; i++) { check_refcounts(objv[i]); }
#endif
		Tcl_ResetResult(interp);
		result = (*cmdinfo.proc)(cmdinfo.clientData, interp,
			objc, argv);

		if (argv != baseargv) {
		    Safefree(argv);
		}
	    }

	    /*
	     * Decrement the ref counts for the argument objects created above
	     */
	    for (i = 1;  i < objc;  i++) {
		Tcl_DecrRefCount(objv[i]);
	    }

	    if (result != TCL_OK) {
		croak(Tcl_GetStringResult(interp));
	    }
	    prepare_Tcl_result(aTHX_ interp, "Tcl::invoke");

	    if (objv != baseobjv) {
		Safefree(objv);
	    }
	    SPAGAIN;
#undef NUM_OBJS
	}


void
Tcl_icall(interp, sv, ...)
	Tcl		interp
	SV *		sv
    PPCODE:
	{
	    /*
	     * 'Tcl::icall' passes the args to Tcl to invoke.  It will do
	     * command tracing and call ::unknown mechanism for unrecognized
	     * commands.
	     */
#define NUM_OBJS 16
	    Tcl_Obj  *baseobjv[NUM_OBJS];
	    Tcl_Obj **objv = baseobjv;
	    int       objc, i, result;

	    if (!initialized) { return; }

	    objc = items-1;
	    if (objc > NUM_OBJS) {
		New(666, objv, objc, Tcl_Obj *);
	    }

	    SP += items;
	    PUTBACK;
	    for (i = 0; i < objc;  i++) {
		/*
		 * Use efficient Sv to Tcl_Obj conversion.
		 * This returns Tcl_Obj with refcount 1.
		 * This can cause recursive calls if we have tied vars.
		 */
		objv[i] = TclObjFromSv(aTHX_ sv_mortalcopy(ST(i+1)));
		Tcl_IncrRefCount(objv[i]);
	    }
	    SP -= items;
	    PUTBACK;

	    /*
	     * Reset current result and invoke using Tcl_EvalObjv.
	     * This will trigger command traces and handle async signals.
	     */
#if DEBUG_REFCOUNTS
	    for (i = 1;  i < objc;  i++) { check_refcounts(objv[i]); }
#endif
	    Tcl_ResetResult(interp);
	    result = Tcl_EvalObjv(interp, objc, objv, 0);

	    /*
	     * Decrement the ref counts for the argument objects created above
	     */
	    for (i = 0;  i < objc;  i++) {
		Tcl_DecrRefCount(objv[i]);
	    }

	    if (result != TCL_OK) {
		croak(Tcl_GetStringResult(interp));
	    }
	    prepare_Tcl_result(aTHX_ interp, "Tcl::icall");

	    if (objv != baseobjv) {
		Safefree(objv);
	    }
	    SPAGAIN;
#undef NUM_OBJS
	}


void
Tcl_DESTROY(interp)
	Tcl	interp
    CODE:
	if (initialized) {
	    Tcl_DeleteInterp(interp);
	    /*
	     * Remove from the global hash of live interps.
	     */
	    if (hvInterps) {
		(void) hv_delete(hvInterps, (const char *) interp,
			sizeof(Tcl), G_DISCARD);
	    }
	}

void
Tcl__Finalize(interp=NULL)
	Tcl	interp
    CODE:
	/*
	 * This should be called from the END block - when we no
	 * longer plan to use Tcl *AT ALL*.
	 */
	if (!initialized) { return; }
	if (hvInterps) {
	    /*
	     * Delete all the global hash of live interps.
	     */
	    HE *he;

	    hv_iterinit(hvInterps);
	    he = hv_iternext(hvInterps);
	    while (he) {
		I32 len;
		interp = *((Tcl *) hv_iterkey(he, &len));
		Tcl_DeleteInterp(interp);
		he = hv_iternext(hvInterps);
	    }
	    hv_undef(hvInterps);
	    hvInterps = NULL;
	}
#ifdef USE_TCL_STUBS
	if (g_Interp) {
	    Tcl_DeleteInterp(g_Interp);
	    g_Interp = NULL;
	}
#endif
	Tcl_Finalize();
	initialized = 0;
#ifdef USE_TCL_STUBS
	if (tclHandle) {
	    dlclose(tclHandle);
	    tclHandle = NULL;
	}
#endif


void
Tcl_Init(interp)
	Tcl	interp
    CODE:
	if (!initialized) { return; }
	if (tclKit_AppInit(interp) != TCL_OK) {
	    croak(Tcl_GetStringResult(interp));
	}
	Tcl_CreateObjCommand(interp, "::perl::Eval", Tcl_EvalInPerl,
		(ClientData) NULL, NULL);

int
Tcl_DoOneEvent(interp, flags)
	Tcl	interp
	int	flags
    CODE:
	if (initialized) {
	    RETVAL = Tcl_DoOneEvent(flags);
	}
    OUTPUT:
	RETVAL

void
Tcl_CreateCommand(interp,cmdName,cmdProc,clientData=&PL_sv_undef,deleteProc=Nullsv)
	Tcl	interp
	char *	cmdName
	SV *	cmdProc
	SV *	clientData
	SV *	deleteProc
    CODE:
	if (!initialized) { return; }
	if (SvIOK(cmdProc))
	    Tcl_CreateCommand(interp, cmdName, (Tcl_CmdProc *) SvIV(cmdProc),
			      (ClientData) SvIV(clientData), NULL);
	else {
	    AV *av = (AV *) SvREFCNT_inc((SV *) newAV());
	    av_store(av, 0, newSVsv(cmdProc));
	    av_store(av, 1, newSVsv(clientData));
	    av_store(av, 2, newSVsv(ST(0)));
	    if (deleteProc) {
		av_store(av, 3, newSVsv(deleteProc));
	    }
	    Tcl_CreateObjCommand(interp, cmdName, Tcl_PerlCallWrapper,
		    (ClientData) av, Tcl_PerlCallDeleteProc);
	}
	ST(0) = &PL_sv_yes;
	XSRETURN(1);

void
Tcl_SetResult(interp, sv)
	Tcl	interp
	SV *	sv
    CODE:
	if (!initialized) { return; }
	{
	    Tcl_Obj *objPtr = TclObjFromSv(aTHX_ sv);
	    /* Tcl_SetObjResult will incr refcount */
	    Tcl_SetObjResult(interp, objPtr);
	    ST(0) = ST(1);
	    XSRETURN(1);
	}

void
Tcl_AppendElement(interp, str)
	Tcl	interp
	char *	str

void
Tcl_ResetResult(interp)
	Tcl	interp

char *
Tcl_AppendResult(interp, ...)
	Tcl	interp
	int	i = NO_INIT
    CODE:
	for (i = 1; i <= items; i++)
	    Tcl_AppendResult(interp, SvPV_nolen(ST(i)), NULL);
	RETVAL = Tcl_GetStringResult(interp);
    OUTPUT:
	RETVAL

SV *
Tcl_DeleteCommand(interp, cmdName)
	Tcl	interp
	char *	cmdName
    CODE:
	RETVAL = boolSV(Tcl_DeleteCommand(interp, cmdName) == TCL_OK);
    OUTPUT:
	RETVAL

void
Tcl_SplitList(interp, str)
	Tcl		interp
	char *		str
	int		argc = NO_INIT
	char **		argv = NO_INIT
	char **		tofree = NO_INIT
    PPCODE:
	if (Tcl_SplitList(interp, str, &argc, &argv) == TCL_OK)
	{
	    tofree = argv;
	    EXTEND(sp, argc);
	    while (argc--)
		PUSHs(sv_2mortal(newSVpv(*argv++, 0)));
	    ckfree((char *) tofree);
	}

SV *
Tcl_SetVar(interp, varname, value, flags = 0)
	Tcl	interp
	char *	varname
	SV *	value
	int	flags
    CODE:
	RETVAL = SvFromTclObj(aTHX_ Tcl_SetVar2Ex(interp, varname, NULL,
				      TclObjFromSv(aTHX_ value), flags));
    OUTPUT:
	RETVAL

SV *
Tcl_SetVar2(interp, varname1, varname2, value, flags = 0)
	Tcl	interp
	char *	varname1
	char *	varname2
	SV *	value
	int	flags
    CODE:
	RETVAL = SvFromTclObj(aTHX_ Tcl_SetVar2Ex(interp, varname1, varname2,
				      TclObjFromSv(aTHX_ value), flags));
    OUTPUT:
	RETVAL

SV *
Tcl_GetVar(interp, varname, flags = 0)
	Tcl	interp
	char *	varname
	int	flags
    CODE:
	RETVAL = SvFromTclObj(aTHX_ Tcl_GetVar2Ex(interp, varname, NULL, flags));
    OUTPUT:
	RETVAL

SV *
Tcl_GetVar2(interp, varname1, varname2, flags = 0)
	Tcl	interp
	char *	varname1
	char *	varname2
	int	flags
    CODE:
	RETVAL = SvFromTclObj(aTHX_ Tcl_GetVar2Ex(interp, varname1, varname2, flags));
    OUTPUT:
	RETVAL

SV *
Tcl_UnsetVar(interp, varname, flags = 0)
	Tcl	interp
	char *	varname
	int	flags
    CODE:
	RETVAL = boolSV(Tcl_UnsetVar2(interp, varname, NULL, flags) == TCL_OK);
    OUTPUT:
	RETVAL

SV *
Tcl_UnsetVar2(interp, varname1, varname2, flags = 0)
	Tcl	interp
	char *	varname1
	char *	varname2
	int	flags
    CODE:
	RETVAL = boolSV(Tcl_UnsetVar2(interp, varname1, varname2, flags) == TCL_OK);
    OUTPUT:
	RETVAL

void
Tcl_perl_attach(interp, name)
	Tcl	interp
	char *	name
    PPCODE:
	if (!initialized) { return; }
	PUTBACK;
	/* create Tcl array */
	Tcl_SetVar2(interp, name, NULL, "", 0);
	/* start trace on it */
	if (Tcl_TraceVar2(interp, name, 0,
	    TCL_TRACE_READS | TCL_TRACE_WRITES | TCL_TRACE_UNSETS |
	    TCL_TRACE_ARRAY,
	    &var_trace,
	    NULL /* clientData*/
	    ) != TCL_OK)
	{
	    croak(Tcl_GetStringResult(interp));
	}
	if (Tcl_TraceVar(interp, name,
	    TCL_TRACE_READS | TCL_TRACE_WRITES | TCL_TRACE_UNSETS,
	    &var_trace,
	    NULL /* clientData*/
	    ) != TCL_OK)
	{
	    croak(Tcl_GetStringResult(interp));
	}
        SPAGAIN;

void
Tcl_perl_detach(interp, name)
	Tcl	interp
	char *	name
    PPCODE:
	if (!initialized) { return; }
	PUTBACK;
	/* stop trace */
        Tcl_UntraceVar2(interp, name, 0,
	    TCL_TRACE_READS|TCL_TRACE_WRITES|TCL_TRACE_UNSETS,
	    &var_trace,
	    NULL /* clientData*/
	    );
        SPAGAIN;

MODULE = Tcl		PACKAGE = Tcl::Var

SV *
FETCH(av, key = NULL)
	Tcl::Var	av
	char *		key
	SV *		sv = NO_INIT
	Tcl		interp = NO_INIT
	char *		varname1 = NO_INIT
	int		flags = 0;
    CODE:
	/*
	 * This handles both hash and scalar fetches. The blessed object
	 * passed in is [$interp, $varname, $flags] ($flags optional).
	 */
	if (!initialized) { return; }
	if (AvFILL(av) != 1 && AvFILL(av) != 2) {
	    croak("bad object passed to Tcl::Var::FETCH");
	}
	sv = *av_fetch(av, 0, FALSE);
	if (sv_derived_from(sv, "Tcl")) {
	    IV tmp = SvIV((SV *) SvRV(sv));
	    interp = (Tcl) tmp;
	}
	else {
	    croak("bad object passed to Tcl::Var::FETCH");
	}
	if (AvFILL(av) == 2) {
	    flags = (int) SvIV(*av_fetch(av, 2, FALSE));
	}
	varname1 = SvPV_nolen(*av_fetch(av, 1, FALSE));
	RETVAL = SvFromTclObj(aTHX_ Tcl_GetVar2Ex(interp, varname1, key, flags));
    OUTPUT:
	RETVAL

void
STORE(av, sv1, sv2 = NULL)
	Tcl::Var	av
	SV *		sv1
	SV *		sv2
	SV *		sv = NO_INIT
	Tcl		interp = NO_INIT
	char *		varname1 = NO_INIT
	Tcl_Obj *	objPtr = NO_INIT
	int		flags = 0;
    CODE:
	/*
	 * This handles both hash and scalar stores. The blessed object
	 * passed in is [$interp, $varname, $flags] ($flags optional).
	 */
	if (!initialized) { return; }
	if (AvFILL(av) != 1 && AvFILL(av) != 2)
	    croak("bad object passed to Tcl::Var::STORE");
	sv = *av_fetch(av, 0, FALSE);
	if (sv_derived_from(sv, "Tcl")) {
	    IV tmp = SvIV((SV *) SvRV(sv));
	    interp = (Tcl) tmp;
	}
	else
	    croak("bad object passed to Tcl::Var::STORE");
	if (AvFILL(av) == 2) {
	    flags = (int) SvIV(*av_fetch(av, 2, FALSE));
	}
	varname1 = SvPV_nolen(*av_fetch(av, 1, FALSE));
	/*
	 * HASH:   sv1 == key,   sv2 == value
	 * SCALAR: sv1 == value, sv2 NULL
	 * Tcl_SetVar2Ex will incr refcount
	 */
	if (sv2) {
	    objPtr = TclObjFromSv(aTHX_ sv2);
	    Tcl_SetVar2Ex(interp, varname1, SvPV_nolen(sv1), objPtr, flags);
	}
	else {
	    objPtr = TclObjFromSv(aTHX_ sv1);
	    Tcl_SetVar2Ex(interp, varname1, NULL, objPtr, flags);
	}

MODULE = Tcl	PACKAGE = Tcl

BOOT:
    {
	SV *x = GvSV(gv_fetchpv("\030", TRUE, SVt_PV)); /* $^X */
#ifdef USE_TCL_STUBS
	if (NpInitialize(aTHX_ x) == TCL_ERROR) {
	    croak("Unable to initialize Tcl");
	}
#else
	/* Ideally this would be passed the dll instance location. */
	Tcl_FindExecutable(x && SvPOK(x) ? SvPV_nolen(x) : NULL);
#endif
	initialized = 1;
	hvInterps = newHV();
    }

    tclBooleanTypePtr   = Tcl_GetObjType("boolean");
    tclByteArrayTypePtr = Tcl_GetObjType("bytearray");
    tclDoubleTypePtr    = Tcl_GetObjType("double");
    tclIntTypePtr       = Tcl_GetObjType("int");
    tclListTypePtr      = Tcl_GetObjType("list");
    tclStringTypePtr    = Tcl_GetObjType("string");
    tclWideIntTypePtr   = Tcl_GetObjType("wideInt");

    /* set up constant subs */
    {
	HV *stash = gv_stashpvn("Tcl", 3, TRUE);
	newCONSTSUB(stash, "OK",               newSViv(TCL_OK));
	newCONSTSUB(stash, "ERROR",            newSViv(TCL_ERROR));
	newCONSTSUB(stash, "RETURN",           newSViv(TCL_RETURN));
	newCONSTSUB(stash, "BREAK",            newSViv(TCL_BREAK));
	newCONSTSUB(stash, "CONTINUE",         newSViv(TCL_CONTINUE));

	newCONSTSUB(stash, "GLOBAL_ONLY",      newSViv(TCL_GLOBAL_ONLY));
	newCONSTSUB(stash, "NAMESPACE_ONLY",   newSViv(TCL_NAMESPACE_ONLY));
	newCONSTSUB(stash, "APPEND_VALUE",     newSViv(TCL_APPEND_VALUE));
	newCONSTSUB(stash, "LIST_ELEMENT",     newSViv(TCL_LIST_ELEMENT));
	newCONSTSUB(stash, "TRACE_READS",      newSViv(TCL_TRACE_READS));
	newCONSTSUB(stash, "TRACE_WRITES",     newSViv(TCL_TRACE_WRITES));
	newCONSTSUB(stash, "TRACE_UNSETS",     newSViv(TCL_TRACE_UNSETS));
	newCONSTSUB(stash, "TRACE_DESTROYED",  newSViv(TCL_TRACE_DESTROYED));
	newCONSTSUB(stash, "INTERP_DESTROYED", newSViv(TCL_INTERP_DESTROYED));
	newCONSTSUB(stash, "LEAVE_ERR_MSG",    newSViv(TCL_LEAVE_ERR_MSG));
	newCONSTSUB(stash, "TRACE_ARRAY",      newSViv(TCL_TRACE_ARRAY));

	newCONSTSUB(stash, "LINK_INT",         newSViv(TCL_LINK_INT));
	newCONSTSUB(stash, "LINK_DOUBLE",      newSViv(TCL_LINK_DOUBLE));
	newCONSTSUB(stash, "LINK_BOOLEAN",     newSViv(TCL_LINK_BOOLEAN));
	newCONSTSUB(stash, "LINK_STRING",      newSViv(TCL_LINK_STRING));
	newCONSTSUB(stash, "LINK_READ_ONLY",   newSViv(TCL_LINK_READ_ONLY));

	newCONSTSUB(stash, "WINDOW_EVENTS",    newSViv(TCL_WINDOW_EVENTS));
	newCONSTSUB(stash, "FILE_EVENTS",      newSViv(TCL_FILE_EVENTS));
	newCONSTSUB(stash, "TIMER_EVENTS",     newSViv(TCL_TIMER_EVENTS));
	newCONSTSUB(stash, "IDLE_EVENTS",      newSViv(TCL_IDLE_EVENTS));
	newCONSTSUB(stash, "ALL_EVENTS",       newSViv(TCL_ALL_EVENTS));
	newCONSTSUB(stash, "DONT_WAIT",        newSViv(TCL_DONT_WAIT));
    }
