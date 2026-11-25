/*
 * ProjectShell packaged-manager launcher (experimental MSIX path).
 * Starts ProjectShell.ps1 next to this executable, NOT the installer.
 * Original native implementation derived from ProjectShell InstallLauncher.c.
 * Runs under the current user; x64, no CRT dependency.
 * Windows 10 S and Microsoft Store policy compatibility are NOT verified.
 */
typedef unsigned int DWORD;
typedef unsigned int UINT;
typedef unsigned short WORD;
typedef unsigned short WCHAR;
typedef int BOOL;
typedef void *HANDLE;
typedef void *HMODULE;
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
    DWORD cb; LPWSTR lpReserved; LPWSTR lpDesktop; LPWSTR lpTitle;
    DWORD dwX; DWORD dwY; DWORD dwXSize; DWORD dwYSize;
    DWORD dwXCountChars; DWORD dwYCountChars; DWORD dwFillAttribute;
    DWORD dwFlags; WORD wShowWindow; WORD cbReserved2;
    unsigned char *lpReserved2; HANDLE hStdInput; HANDLE hStdOutput; HANDLE hStdError;
};
struct ProcessInformation {
    HANDLE hProcess; HANDLE hThread; DWORD dwProcessId; DWORD dwThreadId;
};
DLLIMPORT DWORD WINAPI GetModuleFileNameW(HMODULE, LPWSTR, DWORD);
DLLIMPORT UINT WINAPI GetSystemDirectoryW(LPWSTR, UINT);
DLLIMPORT DWORD WINAPI GetFileAttributesW(LPCWSTR);
DLLIMPORT BOOL WINAPI CreateProcessW(LPCWSTR, LPWSTR, void*, void*, BOOL, DWORD,
    void*, LPCWSTR, struct StartupInfoW*, struct ProcessInformation*);
DLLIMPORT DWORD WINAPI WaitForSingleObject(HANDLE, DWORD);
DLLIMPORT BOOL WINAPI GetExitCodeProcess(HANDLE, DWORD*);
DLLIMPORT BOOL WINAPI CloseHandle(HANDLE);
DLLIMPORT void WINAPI ExitProcess(UINT);
DLLIMPORT int WINAPI MessageBoxW(HANDLE, LPCWSTR, LPCWSTR, UINT);
__declspec(noinline) void *memcpy(void *dest, const void *src, unsigned long long n) {
    volatile unsigned char *d=(volatile unsigned char*)dest;
    const volatile unsigned char *s=(const volatile unsigned char*)src;
    for (unsigned long long i=0;i<n;++i) d[i]=s[i];
    return dest;
}
__declspec(noinline) void *memset(void *dest, int value, unsigned long long n) {
    volatile unsigned char *d=(volatile unsigned char*)dest;
    for (unsigned long long i=0;i<n;++i) d[i]=(unsigned char)value;
    return dest;
}
static WCHAR executable[32768];
static WCHAR script[32768];
static WCHAR powershell[512];
static WCHAR command[32768];
static struct StartupInfoW si;
static struct ProcessInformation pi;
static int length(const WCHAR *s) { int n=0; while(s[n])++n;return n; }
static int append(WCHAR *dest,int cap,const WCHAR *src) {
    int n=length(dest),i=0;
    while(src[i]) { if(n+i+1>=cap)return 0; dest[n+i]=src[i];++i; }
    dest[n+i]=0;return 1;
}
static void fail(LPCWSTR detail,UINT code) {
    MessageBoxW(0,detail,L"ProjectShell Manager",MB_OK|MB_ICONERROR);
    ExitProcess(code);
}
void WINAPI ManagerEntry(void) {
    int i, lastSlash=-1;
    DWORD code=1;
    DWORD exeSize=GetModuleFileNameW(0,executable,32768);
    if(!exeSize||exeSize>=32767)fail(L"Cannot locate ProjectShell-Manager.exe.",2);
    for(i=0;i<(int)exeSize;++i) {
        if(executable[i]==L'\\'||executable[i]==L'/')lastSlash=i;
    }
    if(lastSlash<0)fail(L"Cannot locate the ProjectShell folder.",2);
    for(i=0;i<=lastSlash;++i)script[i]=executable[i];
    script[lastSlash+1]=0;
    if(!append(script,32768,L"ProjectShell.ps1"))fail(L"ProjectShell path is too long.",2);
    DWORD scriptAttr=GetFileAttributesW(script);
    if(scriptAttr==INVALID_FILE_ATTRIBUTES||(scriptAttr&FILE_ATTRIBUTE_DIRECTORY)) {
        fail(L"ProjectShell.ps1 was not found beside ProjectShell-Manager.exe.\\nThe manager requires the complete adjacent script and module set.",3);
    }
    UINT sysLength=GetSystemDirectoryW(powershell,512);
    if(sysLength==0||sysLength>=512||
       !append(powershell,512,L"\\WindowsPowerShell\\v1.0\\powershell.exe")) {
        fail(L"Cannot locate Windows PowerShell.",4);
    }
    if(GetFileAttributesW(powershell)==INVALID_FILE_ATTRIBUTES) {
        fail(L"Windows PowerShell 5.1 is unavailable.",4);
    }
    if(!append(command,32768,L"\"")||
       !append(command,32768,powershell)||
       !append(command,32768,L"\" -NoLogo -NoProfile -ExecutionPolicy Bypass -File \"")||
       !append(command,32768,script)||
       !append(command,32768,L"\"")) {
        fail(L"Manager command line is too long.",5);
    }
    si.cb=(DWORD)sizeof(si);
    si.lpTitle=L"ProjectShell | Manager";
    if(!CreateProcessW(powershell,command,0,0,0,CREATE_NEW_CONSOLE,0,0,&si,&pi)) {
        fail(L"Cannot start ProjectShell. Check Windows and PowerShell security settings.",6);
    }
    WaitForSingleObject(pi.hProcess,INFINITE);
    GetExitCodeProcess(pi.hProcess,&code);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    ExitProcess(code);
}
