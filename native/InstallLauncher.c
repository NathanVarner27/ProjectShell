/*
 * Project Shell Windows installer launcher.
 * Requires Install-ProjectShell.ps1 alongside this .exe.
 * Built with no elevated execution manifest; installer runs as the current user.
 * Windows-only, x64; no C runtime dependency.
 */

typedef unsigned int DWORD;
typedef unsigned int UINT;
typedef unsigned short WORD;
typedef unsigned short WCHAR;
typedef int BOOL;
typedef void *HANDLE;
typedef void *HMODULE;
typedef void *LPVOID;
typedef WCHAR *LPWSTR;
typedef const WCHAR *LPCWSTR;

#define WINAPI __stdcall
#define DLLIMPORT __declspec(dllimport)
#define INVALID_FILE_ATTRIBUTES ((DWORD)0xFFFFFFFFu)
#define FILE_ATTRIBUTE_DIRECTORY 0x00000010u
#define CREATE_NEW_CONSOLE 0x00000010u
#define INFINITE 0xFFFFFFFFu
#define MB_OK 0x00000000u
#define MB_ICONERROR 0x00000010u

struct StartupInfoW {
    DWORD cb;
    LPWSTR lpReserved;
    LPWSTR lpDesktop;
    LPWSTR lpTitle;
    DWORD dwX;
    DWORD dwY;
    DWORD dwXSize;
    DWORD dwYSize;
    DWORD dwXCountChars;
    DWORD dwYCountChars;
    DWORD dwFillAttribute;
    DWORD dwFlags;
    WORD wShowWindow;
    WORD cbReserved2;
    unsigned char *lpReserved2;
    HANDLE hStdInput;
    HANDLE hStdOutput;
    HANDLE hStdError;
};
struct ProcessInformation {
    HANDLE hProcess;
    HANDLE hThread;
    DWORD dwProcessId;
    DWORD dwThreadId;
};

DLLIMPORT DWORD WINAPI GetModuleFileNameW(HMODULE module, LPWSTR buffer, DWORD size);
DLLIMPORT UINT WINAPI GetSystemDirectoryW(LPWSTR buffer, UINT size);
DLLIMPORT DWORD WINAPI GetFileAttributesW(LPCWSTR path);
DLLIMPORT BOOL WINAPI CreateProcessW(LPCWSTR app, LPWSTR command, void* psecurity,
    void* tsecurity, BOOL inherit, DWORD flags, void* environment,
    LPCWSTR currentDirectory, struct StartupInfoW *startup,
    struct ProcessInformation *proc);
DLLIMPORT DWORD WINAPI WaitForSingleObject(HANDLE handle, DWORD milliseconds);
DLLIMPORT BOOL WINAPI GetExitCodeProcess(HANDLE process, DWORD *exitCode);
DLLIMPORT BOOL WINAPI CloseHandle(HANDLE handle);
DLLIMPORT void WINAPI ExitProcess(UINT code);
DLLIMPORT LPCWSTR WINAPI GetCommandLineW(void);
DLLIMPORT int WINAPI MessageBoxW(HANDLE window, LPCWSTR message, LPCWSTR caption, UINT type);

/* Minimal compiler-generated copies; avoids an external C runtime. */
__declspec(noinline) void *memcpy(void *dest, const void *src, unsigned long long n) {
    volatile unsigned char *d = (volatile unsigned char*)dest;
    const volatile unsigned char *s = (const volatile unsigned char*)src;
    for (unsigned long long i = 0; i < n; ++i) d[i] = s[i];
    return dest;
}
__declspec(noinline) void *memset(void *dest, int value, unsigned long long n) {
    volatile unsigned char *d = (volatile unsigned char*)dest;
    for (unsigned long long i = 0; i < n; ++i) d[i] = (unsigned char)value;
    return dest;
}
static WCHAR executable[32768];
static WCHAR script[32768];
static WCHAR powershell[512];
static WCHAR command[32768];
static struct StartupInfoW si;
static struct ProcessInformation pi;

static int length(const WCHAR *s) {
    int n = 0;
    while (s[n]) { ++n; }
    return n;
}
static int append(WCHAR *target, int capacity, const WCHAR *src) {
    int d = length(target), i = 0;
    while (src[i]) {
        if (d + i + 1 >= capacity) return 0;
        target[d + i] = src[i];
        ++i;
    }
    target[d + i] = 0;
    return 1;
}

static int dbp_mode=0;
static int dbp_equal(const WCHAR *a,const WCHAR *b){while(*a && *a==*b){++a;++b;}return *a==*b;}
static int dbp_parse(const WCHAR *s){
 if(!s || !*s)return -1;
 if(*s==L'"'){++s;while(*s && *s!=L'"')++s;if(!*s)return -1;++s;if(*s && *s!=L' ' && *s!=L'\t')return -1;}
 else {while(*s && *s!=L' ' && *s!=L'\t')++s;}
 while(*s==L' ' || *s==L'\t')++s;
 if(!*s)return 0;
 if(dbp_equal(s,L"--silent"))return 1;
 if(dbp_equal(s,L"--silent-with-progress"))return 2;
 return -1;
}

static void fail(LPCWSTR message, UINT exitCode) {
    if(dbp_mode==0) MessageBoxW(0, message, L"Project Shell Installer", MB_OK | MB_ICONERROR);
    ExitProcess(exitCode);
}

void WINAPI InstallEntry(void) {
    dbp_mode=dbp_parse(GetCommandLineW());
    if(dbp_mode<0)ExitProcess(87);
    DWORD code = 1;
    int i, lastSlash = -1;
    DWORD scriptAttr;
    DWORD exeSize = GetModuleFileNameW(0, executable, 32768);
    if (!exeSize || exeSize >= 32767) fail(L"Cannot locate the installer executable.", 2);
    for (i = 0; i < (int)exeSize; ++i) {
        if (executable[i] == L'\\' || executable[i] == L'/') lastSlash = i;
    }
    if (lastSlash < 0) fail(L"Cannot determine the installer folder.", 2);
    for (i = 0; i <= lastSlash; ++i) script[i] = executable[i];
    script[lastSlash + 1] = 0;
    if (!append(script, 32768, L"Install-ProjectShell.ps1")) fail(L"Installer path is too long.", 2);
    scriptAttr = GetFileAttributesW(script);
    if (scriptAttr == INVALID_FILE_ATTRIBUTES || (scriptAttr & FILE_ATTRIBUTE_DIRECTORY)) {
        fail(L"Install-ProjectShell.ps1 was not found next to Install-ProjectShell.exe.\nExtract the complete release ZIP before launching the installer.", 3);
    }

    UINT sysLength = GetSystemDirectoryW(powershell, 512);
    if (sysLength == 0 || sysLength >= 512 ||
        !append(powershell, 512, L"\\WindowsPowerShell\\v1.0\\powershell.exe")) {
        fail(L"Could not locate Windows PowerShell.", 4);
    }
    if (GetFileAttributesW(powershell) == INVALID_FILE_ATTRIBUTES) {
        fail(L"Windows PowerShell 5.1 was not found.", 4);
    }
    if (!append(command, 32768, L"\"") ||
        !append(command, 32768, powershell) ||
        !append(command, 32768, dbp_mode?L"\" -NonInteractive -NoLogo -NoProfile -ExecutionPolicy Bypass -File \"":L"\" -NoExit -NoLogo -NoProfile -ExecutionPolicy Bypass -File \"") ||
        !append(command, 32768, script) ||
        !append(command, 32768, dbp_mode?L"\" -Unattended":L"\" -Guided")) {
        fail(L"Installer command path is too long.", 5);
    }

    si.cb = (DWORD)sizeof(si);
    si.lpTitle = L"Project Shell | Installer";
    /* A separate normal console is created for numbered installer prompts. */
    if (!CreateProcessW(powershell, command, 0, 0, 0, dbp_mode==1?0x08000000u:CREATE_NEW_CONSOLE, 0, 0, &si, &pi)) {
        fail(L"Could not launch the PowerShell installer. Check Windows security settings.", 6);
    }
    WaitForSingleObject(pi.hProcess, INFINITE);
    GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    ExitProcess(code);
}
