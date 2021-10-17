" let c_no_cformat=''
" syn match cFormat display \"%.\" contained

if exists("c_gnu")
	syn keyword Keyword __restrict __restrict__ _Pragma
	syn keyword Identifier
		\ strrchr
		\ reallocarray
endif
syn keyword Identifier
	\ main exit _exit _Exit
	\ assert abort
	\ malloc free calloc realloc
	\ mmap munmap msync
	\ strcmp strncmp strcasecmp strncasecmp strdup strlen strnlen strchr strchrnul strstr strcasestr strcpy strncpy strsep strspn strcspn strcat strncat
	\ wcslen wcsspn wcscspn
	\ ppoll
	\ errno
	\ memcmp memcpy memmove memchr memrchr rawmemchr memmem memset
	\ signal sigaction sigemptyset sigaddset
	\ usleep sleep
	\ perror strerror
	\ setenv unsetenv getenv putenv clearenv
	\ fork vfork link linkat rename renameat fstat fstatat mkdir mkdirat
	\ execl execlp execle execv execvp execvpe
	\ open openat creat close dup dup2
	\ read write readv writev
	\ openpty forkpty
	\ setsid
	\ fopen fdopen freopen opendir fdopendir closedir rewinddir readdir setbuf setbuffer setlinebuf setvbuf ferror fclose flock flockfile funlockfile fputc fputs putc ftruncate fseek ftell rewind putchar puts fflush fileno fsync fgetc fgets getc getchar ungetc getline getdelim fwrite fread
	\ gettid getpid
	\ pipe
	\ atexit
	\ va_arg
	\ strtod strtol strtoll strtoull strtoul
	\ setlocale newlocale uselocale
	\ fcntl ioctl
	\ regcomp regexec regerror regfree
syn keyword Identifier
	\ containerof container_of
	\ offsetof offset_of
	\ likely unlikely
syn match Identifier display "\v<v?%(f|d|s|sn)?w?printf>"
syn match Identifier display "\v<v?[fs]?w?scanf>"
syn match Identifier display "\v<U?INT%(8|16|32|64|MAX)_C>"
syn match Identifier display "\v<pthread_%(testcancel|self|%(mutex_%(%(un|try)?lock|init|destroy)|rwlock%(attr_%(init|destroy)|_%(%(timed)?%(rd|wr|un)lock|try%(rd|wr)lock|init|destroy))|cleanup_%(push|pop)|join|cancel|setcancel%(type|state)|cond_%(init|destroy|wait|signal|broadcast))|create|detach|sigmask|exit|attr_%(init|setdetachstate))>"
syn match cConstant display "\v<%(PRI|SCN)[diouxX]%(%(LEAST|FAST)?%(8|16|32|64)|MAX|PTR)>"
syn match cConstant display "\v<%(%([US]?CHAR)|U?%(SHRT|INT%(%(_LEAST|_FAST)?%(8|16|32|64)?|PTR|MAX)|L?LONG)|SIZE|W%(CHAR|INT)|PTRDIFF|SIG_ATOMIC)_WIDTH>"
syn match cConstant display "\v<S_I%([RWX]%(USR|GRP|OTH)|RWX[UGO]|SVTX)>"
syn match cConstant display "\v<PTHREAD_%(%(COND|MUTEX|RWLOCK)_INITIALIZER|CANCEL_%(%(DIS|EN)ABLE|DEFERRED|ASYNCHRONOUS))>"
syn keyword cConstant
	\ ATOMIC_FLAG_INIT
syn match cConstant display "\v<[RWXF]_OK>"
syn match cConstant display "\v<F_[GS]ETF[DL]>"
syn match cConstant display "\v<O_%(RDONLY|WRONLY|RDWR|CREAT|EXCL|CLOEXEC|TRUNC|APPEND|NONBLOCK|PATH|DIRECTORY|EXCL|NOFOLLOW)>"
syn match cConstant display "\v<FD_%(CLOEXEC)>"
syn match cConstant display "\v<LOCK_%(EX|NB)>"
syn match cConstant display "\v<REG_%(EXTENDED|ICASE|NOSUB|NEWLINE|NOTBOL|NOTEOL|STARTEND)>"
syn keyword cType __m128i locale_t sigset_t regex_t pid_t dev_t ino_t
syn match Identifier display "\v<sigfillset>"
syn match cConstant display "\v<SA_%(NOCLDSTOP|NOCLDWAIT|NODEFER|ONSTACK|RESETHAND|RESTART|RESTORER|SIGINFO)>"
syn match cConstant display "\v<LC_%(GLOBAL_LOCALE|%(ADDRESS|CTYPE|COLLATE|IDENTIFICATION|MEASUREMENT|MESSAGES|MONETARY|NUMERIC|NAME|PAPER|TELEPHONE|TIME|ALL)_MASK)>"
syn keyword cConstant
	\ __STDC_VERSION__ __linux__ clang __cplusplus
	\ stdtty
	\ SIGRTMIN SIGRTMAX PATH_MAX NAME_MAX SIG_BLOCK SIG_UNBLOCK SIG_SETMASK
	\ STDIN_FILENO STDOUT_FILENO STDERR_FILENO
	\ POLLIN POLLPRI POLLOUT POLLERR POLLHUP POLLNVAL
	\ AT_FDCWD AT_EMPTY_PATH
syn match cType display "\v<pthread%(_%(cond|mutex|rwlock%(attr)?|attr)|)_t>"
syn keyword cType
	\ atomic_flag
syn keyword	cTodo contained WTF

syn match cPreProcStringify display "[^#]#\s*[A-Za-z][A-Za-z0-9]*" containedin=cPreProcGroup
syn match cPreProcTokenPaste display "##" containedin=cPreProcGroup

hi def link cPreProcStringify String
hi def link cPreProcTokenPaste Keyword
