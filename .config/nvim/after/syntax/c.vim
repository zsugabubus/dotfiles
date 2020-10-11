syn match cType "\v<\k+_t>"
if exists("c_gnu")
	syn match Identifier "\v<__builtin_\k+>"

	syn keyword Keyword __restrict __restrict__
	syn keyword Identifier
		\ strrchr
		\ reallocarray
endif
syn keyword Identifier
	\ main exit _exit _Exit
	\ assert abort
	\ malloc free calloc realloc
	\ mmap munmap msync
	\ strcmp strdup strlen strnlen strchr strstr strcpy strncpy strsep strspn strcspn
	\ wcslen wcsspn wcscspn
	\ memcmp memcpy memmove memchr rawmemchr memmem memset
	\ signal sigaction
	\ sleep
	\ perror strerror
	\ setenv unsetenv getenv putenv clearenv
	\ fork vfork
	\ execl execlp execle execv execvp execvpe
	\ open creat close dup dup2
	\ read write readv writev
	\ openpty forkpty
	\ fcntl ioctl
syn keyword Identifier
	\ containerof container_of
	\ offsetof offset_of
syn match Identifier "\v<v?%(f|d|s|sn)?w?printf>"
syn match Identifier "\v<v?[fs]?w?scanf>"
syn match Identifier "\v<pthread_\k+>"
syn keyword cConstant
	\ __STDC_VERSION__ clang
	\ STDIN_FILENO STDOUT_FILENO STDERR_FILENO
	\ __cplusplus
