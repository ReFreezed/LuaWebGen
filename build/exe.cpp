/***************************************************************
*
*  Lua launcher
*
*---------------------------------------------------------------
*
*  LuaWebGen
*  by Marcus 'ReFreezed' Thunström
*
***************************************************************/

// #define DEV

#include <stdio.h>
#include <windows.h>

typedef signed   __int8  s8;
typedef signed   __int16 s16;
typedef signed   __int32 s32;
typedef signed   __int64 s64;
typedef unsigned __int8  u8;
typedef unsigned __int16 u16;
typedef unsigned __int32 u32;
typedef unsigned __int64 u64;



// Defer macro.
#define _CONCAT_IDENTS(x, y) x##y
#define CONCAT_IDENTS(x, y) _CONCAT_IDENTS(x, y)

template<typename T>
struct ExitScope {
	T lambda;
	ExitScope(T lambda):lambda(lambda){}
	~ExitScope(){ lambda(); }
	ExitScope(const ExitScope&);
	private:
		ExitScope& operator =(const ExitScope&);
};

class ExitScopeHelp {
	public:
		template<typename T>
		ExitScope<T> operator+(T t){ return t;}
};

#define defer const auto& CONCAT_IDENTS(defer__, __LINE__) = ExitScopeHelp() + [&]()



void errorf(const char *format, ...) {
	va_list args;
	va_start(args, format);

	fprintf(stderr, "Error: ");
	if (vfprintf(stderr, format, args) < 0)  fprintf(stderr, "Internal error.");
	fprintf(stderr, "\n");

	va_end(args);
	exit(EXIT_FAILURE);
}



inline
char *allocUtf8String(size_t bytes) {
	auto s = (char *) malloc(bytes);
	if (s)  s[0] = 0;
	return s;
}

inline
wchar_t *allocUtf16String(size_t charCount) {
	auto s = (wchar_t *) malloc(charCount*2);
	if (s) {
		s[0] = 0;
		s[1] = 0;
	}
	return s;
}



char *utf16To8(const wchar_t *strWide) {
	auto requiredSize = WideCharToMultiByte(CP_UTF8, 0, strWide, -1, nullptr, 0, nullptr, nullptr);
	if (!requiredSize)  return nullptr;

	auto utf8Str = allocUtf8String(requiredSize);
	if (!utf8Str)  return nullptr;

	if (!WideCharToMultiByte(CP_UTF8, 0, strWide, -1, utf8Str, requiredSize, nullptr, nullptr)) {
		free(utf8Str);
		return nullptr;
	}

	return utf8Str;
}

wchar_t *utf8To16(const char *str) {
	auto requiredChars = MultiByteToWideChar(CP_UTF8, 0, str, -1, nullptr, 0);
	if (!requiredChars)  return nullptr;

	auto utf16Str = allocUtf16String(requiredChars);
	if (!utf16Str)  return nullptr;

	if (!MultiByteToWideChar(CP_UTF8, 0, str, -1, utf16Str, requiredChars)) {
		free(utf16Str);
		return nullptr;
	}

	return utf16Str;
}



char *_concatStrings(int n, ...) {
	int len = 0;
	va_list args;

	va_start(args, n);
	for (int i = 0; i < n; i++) {
		len += strlen(va_arg(args, char *));
	}
	va_end(args);

	auto result = allocUtf8String(len+1);
	if (!result)  return nullptr;

	va_start(args, n);
	for (int i = 0; i < n; i++) {
		strcat(result, va_arg(args, char *));
	}
	va_end(args);

	return result;
}

// https://stackoverflow.com/questions/2124339/c-preprocessor-va-args-number-of-arguments/2124433#2124433
#define NUMARG_POINTERS(...) (sizeof((const void *[]){ 0, ##__VA_ARGS__ }) / sizeof(const void *) - 1)
#define CONCAT_STRINGS(...) _concatStrings(NUMARG_POINTERS(__VA_ARGS__), ##__VA_ARGS__)



char *getErrorText(u32 errCode) {
	if (errCode == 0)  return nullptr;

	wchar_t *strWide = nullptr;

	if (!FormatMessageW(
		FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
		nullptr, errCode, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), (wchar_t *)&strWide, 0, nullptr
	)) {
		return nullptr;
	}

	auto str = utf16To8(strWide); // May fail.
	LocalFree(strWide);

	auto len = strlen(str);

	while (len && isspace(str[len-1])) {
		str[len-1] = 0;
		len--;
	}

	return str;
}



char *getPathToExecutable() {
	static const size_t INITIAL_BUFFER_SIZE = MAX_PATH; // Note: MAX_PATH includes null, people say.
	static const size_t MAX_ITERATIONS      = 7;

	wchar_t *pathWide         = nullptr;
	u32     bufferSizeInChars = INITIAL_BUFFER_SIZE;

	for (size_t i = 0; i < MAX_ITERATIONS; ++i) {
		if (pathWide)
			pathWide = (wchar_t *) realloc(pathWide, bufferSizeInChars*2);
		else
			pathWide = (wchar_t *) malloc(bufferSizeInChars*2);

		if (!pathWide)  return nullptr;

		u32 charCount = GetModuleFileNameW(nullptr, pathWide, bufferSizeInChars);
		if (!charCount)  return nullptr;

		if (charCount < bufferSizeInChars) {
			auto path = utf16To8(pathWide); // May fail.
			free(pathWide);
			return path;
		}

		bufferSizeInChars *= 2;
	}

	return nullptr;
}



int APIENTRY WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, char *pCmdLine, int nCmdShow) {
	//
	// Construct command
	//
	#ifdef DEV
	static const char *LUA_EXE_PATH    = "..\\bin\\lua.exe";
	static const char *LUA_SCRIPT_PATH = "..\\webgen.lua";
	#else
	static const char *LUA_EXE_PATH    = "bin\\lua.exe";
	static const char *LUA_SCRIPT_PATH = "webgen.lua";
	#endif

	wchar_t *cmdWide = nullptr;

	{
		auto exeDir = getPathToExecutable();
		if (!exeDir)  errorf("Error before starting Lua: Could not get path to executable.");
		defer { free(exeDir); };

		auto exeDirLen = strlen(exeDir);

		while (exeDirLen && exeDir[exeDirLen] != '\\')  exeDirLen--;
		exeDir[exeDirLen+1] = 0;
		// Note: exeDir includes the trailing slash.

		auto cmdIn = utf16To8(GetCommandLineW());
		if (!cmdIn)  errorf("Error before starting Lua: String encoding error.");
		defer { free(cmdIn); };

		auto argsStr  = cmdIn;
		auto specials = true;

		while (*argsStr) {
			if      (*argsStr == '"')  specials = !specials;
			else if (!specials)        {}
			else if (*argsStr == ' ')  break;
			argsStr++;
		}

		auto cmd = CONCAT_STRINGS("\"", LUA_EXE_PATH, "\" \"", exeDir, LUA_SCRIPT_PATH, "\"", argsStr);
		if (!cmd)  errorf("Error before starting Lua: Command construction error.");
		defer { free(cmd); };

		cmdWide = utf8To16(cmd);
		if (!cmdWide)  errorf("Error before starting Lua: String encoding error.");
	}

	defer { free(cmdWide); };

	//
	// Run command
	//
	// https://stackoverflow.com/questions/31563579/execute-command-using-win32/31572351#31572351
	// https://stackoverflow.com/questions/53208/how-do-i-automatically-destroy-child-processes-in-windows/53214#53214
	//
	HANDLE job = CreateJobObjectW(nullptr, nullptr);
	if (!job)  errorf("Error before starting Lua: Could not create job object.");
	defer { CloseHandle(job); };

	JOBOBJECT_EXTENDED_LIMIT_INFORMATION jobLimitInfo = {0};
	jobLimitInfo.BasicLimitInformation.LimitFlags     = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;

	if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &jobLimitInfo, sizeof(typeof(jobLimitInfo)))) {
		errorf("Error before starting Lua: Could not update job object.");
	}

	SECURITY_ATTRIBUTES securityAttrs  = {0};
	securityAttrs.nLength              = sizeof(typeof(securityAttrs));
	securityAttrs.lpSecurityDescriptor = nullptr;
	securityAttrs.bInheritHandle       = true;

	STARTUPINFOW startupInfo = {0};
	startupInfo.cb           = sizeof(typeof(startupInfo));

	PROCESS_INFORMATION processInfo = {0};

	if (!CreateProcessW(
		/*lpApplicationName   */ nullptr,
		/*lpCommandLine       */ cmdWide,
		/*lpProcessAttributes */ nullptr,
		/*lpThreadAttributes  */ nullptr,
		/*bInheritHandles     */ true,
		/*dwCreationFlags     */ CREATE_SUSPENDED,
		/*lpEnvironment       */ nullptr,
		/*lpCurrentDirectory  */ nullptr,
		/*lpStartupInfo       */ &startupInfo,
		/*lpProcessInformation*/ &processInfo
	)) {
		errorf("Could not start Lua (%s): %s", LUA_EXE_PATH, getErrorText(GetLastError()));
	}
	defer {
		CloseHandle(processInfo.hThread);
		CloseHandle(processInfo.hProcess);
	};

	if (!AssignProcessToJobObject(job, processInfo.hProcess))  errorf("Error before starting Lua: Could not assign process to job object.");
	if (ResumeThread(processInfo.hThread) == -1)               errorf("Could not start Lua properly.");

	WaitForSingleObject(processInfo.hProcess, INFINITE);

	DWORD exitCode = 0;
	if (!GetExitCodeProcess(processInfo.hProcess, &exitCode))  errorf("Could not get exit code from Lua.");

	return exitCode;
}


