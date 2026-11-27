#!/usr/bin/env python3
"""Build source-traceable, self-contained Windows x64 ProjectShell EXE from the release ZIP.

Run in CI after building the official ZIP. Requires Python 3, clang-cl, and lld-link.
No network connection is needed during packaging or when the EXE is launched.
"""
from __future__ import annotations
import argparse
import hashlib
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
C = r"""
/* ProjectShell standalone setup: generated from the official release ZIP. */
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
#define INVALID_HANDLE_VALUE ((HANDLE)(-1))
#define CREATE_NEW_CONSOLE 0x00000010u
#define INFINITE 0xFFFFFFFFu
#define GENERIC_WRITE 0x40000000u
#define CREATE_ALWAYS 2u
#define FILE_ATTRIBUTE_NORMAL 0x00000080u
#define MB_OK 0x0u
#define MB_ICONERROR 0x10u
struct StartupInfoW {
 DWORD cb; LPWSTR lpReserved; LPWSTR lpDesktop; LPWSTR lpTitle;
 DWORD dwX,dwY,dwXSize,dwYSize,dwXCountChars,dwYCountChars,dwFillAttribute,dwFlags;
 WORD wShowWindow,cbReserved2; unsigned char *lpReserved2;
 HANDLE hStdInput,hStdOutput,hStdError;
};
struct ProcessInformation {
 HANDLE hProcess; HANDLE hThread; DWORD dwProcessId,dwThreadId;
};
DLLIMPORT DWORD WINAPI GetTempPathW(DWORD,LPWSTR);
DLLIMPORT UINT WINAPI GetTempFileNameW(LPCWSTR,LPCWSTR,UINT,LPWSTR);
DLLIMPORT BOOL WINAPI DeleteFileW(LPCWSTR);
DLLIMPORT BOOL WINAPI CreateDirectoryW(LPCWSTR,void*);
DLLIMPORT HANDLE WINAPI CreateFileW(LPCWSTR,DWORD,DWORD,void*,DWORD,DWORD,HANDLE);
DLLIMPORT BOOL WINAPI WriteFile(HANDLE,const void*,DWORD,DWORD*,void*);
DLLIMPORT BOOL WINAPI CloseHandle(HANDLE);
DLLIMPORT UINT WINAPI GetSystemDirectoryW(LPWSTR,UINT);
DLLIMPORT DWORD WINAPI GetFileAttributesW(LPCWSTR);
DLLIMPORT BOOL WINAPI CreateProcessW(LPCWSTR,LPWSTR,void*,void*,BOOL,DWORD,void*,LPCWSTR,struct StartupInfoW*,struct ProcessInformation*);
DLLIMPORT DWORD WINAPI WaitForSingleObject(HANDLE,DWORD);
DLLIMPORT BOOL WINAPI GetExitCodeProcess(HANDLE,DWORD*);
DLLIMPORT void WINAPI ExitProcess(UINT);
DLLIMPORT LPCWSTR WINAPI GetCommandLineW(void);
DLLIMPORT int WINAPI MessageBoxW(HANDLE,LPCWSTR,LPCWSTR,UINT);
__declspec(noinline) void *memcpy(void *dest,const void *src,unsigned long long n){
 volatile unsigned char *d=(volatile unsigned char*)dest;
 const volatile unsigned char *s=(const volatile unsigned char*)src;
 for(unsigned long long i=0;i<n;i++)d[i]=s[i];return dest;
}
__declspec(noinline) void *memset(void *dest,int x,unsigned long long n){
 volatile unsigned char *d=(volatile unsigned char*)dest;
 for(unsigned long long i=0;i<n;i++)d[i]=(unsigned char)x;return dest;
}
static const unsigned char zipPayload[] = {
/*EMBED_ZIP*/
};
static const unsigned char bootstrapPayload[] = {
/*EMBED_BOOTSTRAP*/
};
static WCHAR temp[512],stage[512],shell[512],zipfile[768],psfile[768],cmd[4096];
static struct StartupInfoW si;
static struct ProcessInformation pi;
static int slen(const WCHAR*s){int i=0;while(s[i])++i;return i;}
static int append(WCHAR *dst,int max,const WCHAR *src){
 int i=slen(dst),j=0;while(src[j]){if(i+j+1>=max)return 0;dst[i+j]=src[j];j++;}dst[i+j]=0;return 1;
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

static void fail(LPCWSTR message, UINT code){
 if(dbp_mode==0)MessageBoxW(0,message,L"ProjectShell standalone installer",MB_OK|MB_ICONERROR);ExitProcess(code);
}
static int put(LPCWSTR path,const unsigned char *data,DWORD count){
 DWORD written=0;
 HANDLE h=CreateFileW(path,GENERIC_WRITE,0,0,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,0);
 if(h==INVALID_HANDLE_VALUE)return 0;
 BOOL ok=WriteFile(h,data,count,&written,0);
 CloseHandle(h);
 return ok && written==count;
}
void WINAPI InstallEntry(void){
 dbp_mode=dbp_parse(GetCommandLineW());
 if(dbp_mode<0)ExitProcess(87);
 DWORD code=1,len=GetTempPathW(512,temp);
 if(!len||len>=512)fail(L"Cannot locate the Windows temporary directory.",2);
 if(!GetTempFileNameW(temp,L"PSH",0,stage))fail(L"Cannot create the installer staging path.",3);
 if(!DeleteFileW(stage)||!CreateDirectoryW(stage,0))fail(L"Cannot create the installer staging directory.",4);
 if(!append(zipfile,768,stage)||!append(zipfile,768,L"\\ProjectShell.zip"))fail(L"Temporary ZIP path is too long.",5);
 if(!append(psfile,768,stage)||!append(psfile,768,L"\\bootstrap.ps1"))fail(L"Temporary script path is too long.",6);
 if(!put(zipfile,zipPayload,(DWORD)sizeof(zipPayload)))fail(L"Cannot extract the embedded ProjectShell package.",7);
 if(!put(psfile,bootstrapPayload,(DWORD)sizeof(bootstrapPayload)))fail(L"Cannot write the temporary installer script.",8);
 UINT n=GetSystemDirectoryW(shell,512);
 if(!n||n>=512||!append(shell,512,L"\\WindowsPowerShell\\v1.0\\powershell.exe"))
   fail(L"Windows PowerShell 5.1 was not found.",9);
 if(GetFileAttributesW(shell)==INVALID_FILE_ATTRIBUTES)fail(L"Cannot find Windows PowerShell 5.1.",9);
 if(!append(cmd,4096,L"\"")||!append(cmd,4096,shell)||
    !append(cmd,4096,dbp_mode?L"\" -NonInteractive -NoLogo -NoProfile -ExecutionPolicy Bypass -File \"":L"\" -NoExit -NoLogo -NoProfile -ExecutionPolicy Bypass -File \"")||
    !append(cmd,4096,psfile)||!append(cmd,4096,L"\" -Stage \"")||
    !append(cmd,4096,stage)||!append(cmd,4096,L"\""))fail(L"Installer command line too long.",10);
 if(dbp_mode && !append(cmd,4096,L" -Unattended"))fail(L"Installer arguments too long.",10);
 si.cb=(DWORD)sizeof(si);
 si.lpTitle=L"ProjectShell | Standalone Setup";
 if(!CreateProcessW(shell,cmd,0,0,0,dbp_mode==1?0x08000000u:CREATE_NEW_CONSOLE,0,0,&si,&pi))
   fail(L"Windows could not start the PowerShell installer.",11);
 WaitForSingleObject(pi.hProcess,INFINITE);
 GetExitCodeProcess(pi.hProcess,&code);
 CloseHandle(pi.hThread);CloseHandle(pi.hProcess);
 if(code){if(dbp_mode)ExitProcess(code);fail(L"Installer failed. Review the PowerShell window for details.",12);}
 ExitProcess(0);
}
"""
BOOTSTRAP = r"""[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Stage,[switch]$Unattended)
$ErrorActionPreference = 'Stop'

function Get-ProjectShellSha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
        finally { $sha.Dispose() }
    } finally { $stream.Dispose() }
}


function Write-CINativeDiagnostic($Failure) {
    if ($env:GITHUB_ACTIONS -eq 'true' -and $env:RUNNER_ENVIRONMENT -eq 'github-hosted' -and $env:RUNNER_TEMP) {
        try {
            $folder = [IO.Path]::GetFullPath($env:LOCALAPPDATA)
            $runner = [IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\') + '\'
            if ($folder.StartsWith($runner,[StringComparison]::OrdinalIgnoreCase)) {
                $log = Join-Path $folder 'ProjectShell-Native-Diagnostics.txt'
                [IO.File]::AppendAllText($log, ($Failure.ToString() + [Environment]::NewLine + $Failure.ScriptStackTrace + [Environment]::NewLine))
            }
        } catch { }
    }
}

$bundle = Join-Path $Stage 'ProjectShell.zip'
$extract = Join-Path $Stage 'Contents'
try {
    $expected = '__SHA__'
    if ((Get-ProjectShellSha256 $bundle) -ne $expected) {
        throw 'Embedded installer package failed SHA-256 verification.'
    }
    New-Item -ItemType Directory -Path $extract -Force | Out-Null
    Expand-Archive -LiteralPath $bundle -DestinationPath $extract -Force
    foreach ($name in @('Install-ProjectShell.ps1','ProjectShell.ps1','ProjectShell.Workspaces.ps1','ProjectShell.Catalogue.ps1','ProjectShell.Migration.ps1','Diagnose-Launch.ps1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $extract $name) -PathType Leaf)) {
            throw ('Missing required component: ' + $name)
        }
    }
    Write-Host 'PROJECTSHELL | STANDALONE INSTALLER' -ForegroundColor Cyan
    if ($Unattended) { & (Join-Path $extract 'Install-ProjectShell.ps1') -Unattended }
    else { & (Join-Path $extract 'Install-ProjectShell.ps1') -Guided }
    Write-Host 'Installer finished. Close this console when ready.' -ForegroundColor Green
}
catch {
    Write-CINativeDiagnostic $_
    Write-Host ('PROJECTSHELL ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
finally {
    Remove-Item -LiteralPath $bundle -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $Stage 'bootstrap.ps1') -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $Stage -Force -ErrorAction SilentlyContinue
}
"""

def c_bytes(data: bytes) -> str:
    return "\n".join(
        "    " + ",".join(f"0x{b:02X}" for b in data[i:i+16]) + ","
        for i in range(0, len(data), 16)
    )

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("release_zip", type=Path)
    parser.add_argument("output_exe", type=Path)
    args = parser.parse_args()
    archive = args.release_zip.read_bytes()
    with zipfile.ZipFile(args.release_zip) as z:
        assert z.testzip() is None, "Release ZIP integrity verification failed"
        assert {
            "Install-ProjectShell.ps1",
            "ProjectShell.ps1",
            "ProjectShell.Workspaces.ps1",
            "ProjectShell.Catalogue.ps1",
            "ProjectShell.Migration.ps1",
            "Diagnose-Launch.ps1",
        }.issubset(set(z.namelist())), "Missing essential installer scripts"
    digest = hashlib.sha256(archive).hexdigest().upper()
    bootstrap = BOOTSTRAP.replace("__SHA__", digest).encode("ascii")
    generated = C.replace("/*EMBED_ZIP*/", c_bytes(archive)).replace(
        "/*EMBED_BOOTSTRAP*/", c_bytes(bootstrap)
    )
    with tempfile.TemporaryDirectory(prefix="projectshell-standalone-") as temp:
        work = Path(temp)
        source = work / "Standalone.c"
        obj = work / "Standalone.obj"
        source.write_text(generated, encoding="utf-8")
        for library in ("kernel32", "user32"):
            subprocess.run([
                "lld-link", "/lib", f"/def:{ROOT / 'native' / (library + '.def')}",
                "/machine:x64", f"/out:{work / (library + '.lib')}"
            ], check=True)
        subprocess.run([
            "clang-cl", "--target=x86_64-pc-windows-msvc", "/nologo", "/O2",
            "/GS-", "/Zl", "/clang:-fno-builtin", "/c", f"/Fo{obj}", str(source)
        ], check=True)
        args.output_exe.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([
            "lld-link", "/nologo", "/nodefaultlib", "/machine:x64",
            "/subsystem:windows", "/entry:InstallEntry", "/manifest:embed",
            "/manifestuac:level='asInvoker' uiAccess='false'",
            f"/out:{args.output_exe}", str(obj), str(work / "kernel32.lib"),
            str(work / "user32.lib")
        ], check=True)
    print(f"Standalone Windows EXE: {args.output_exe}")
    print(f"Embedded ZIP SHA-256: {digest}")

if __name__ == "__main__":
    main()
