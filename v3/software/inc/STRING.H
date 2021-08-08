/* string.h standard header */
#ifndef _STRING
#define _STRING
#ifndef _YVALS
#include <yvals.h>
#endif
		/* macros */
#define NULL	_NULL
		/* type definitions */
#ifndef _SIZET
#define _SIZET
typedef _Sizet size_t;
#endif
		/* declarations */
void *memchr(register const void *, register int, register size_t);
void *memchrB(register const void *, register int, register size_t);
void *memchrW(register const void *, register int, register size_t);
void *memchrT(register const void *, register int, register size_t);
void *memchrO(register const void *, register int, register size_t);
int memcmp(register const void *, register const void *, register size_t);
int memcmpB(register const void *, register const void *, register size_t);
int memcmpW(register const void *, register const void *, register size_t);
int memcmpT(register const void *, register const void *, register size_t);
int memcmpO(register const void *, register const void *, register size_t);
void *memcpy(register void *, register const void *, register size_t);
void *memcpyB(register void *, register const void *, register size_t);
void *memcpyW(register void *, register const void *, register size_t);
void *memcpyT(register void *, register const void *, register size_t);
void *memcpyO(register void *, register const void *, register size_t);
void *memmove(register void *, register const void *, register size_t);
void *memmoveB(register void *, register const void *, register size_t);
void *memmoveW(register void *, register const void *, register size_t);
void *memmoveT(register void *, register const void *, register size_t);
void *memmoveO(register void *, register const void *, register size_t);
void *memset(register void *, register int, register size_t);
void *memsetB(register void *, register int, register size_t);
void *memsetW(register void *, register int, register size_t);
void *memsetT(register void *, register int, register size_t);
void *memsetO(register void *, register int, register size_t);
char *strcat(register char *, register const char *);
byte *strcatB(register byte *, register const byte *);
int:16 *strcatW(register int:16 *, register const int:16 *);
int:32 *strcatT(register int:32 *, register const int:32 *);
char *strchr(const char *, int);
int strcmp(const char *, const char *);
int strcoll(const char *, const char *);
char *strcpy(char *, const char *);
size_t strcspn(const char *, const char *);
char *strerror(int);
size_t strlen(const char *);
char *strncat(char *, const char *, size_t);
int strncmp(const char *, const char *, size_t);
char *strncpy(char *, const char *, size_t);
char *strpbrk(const char *, const char *);
char *strrchr(const char *, int);
size_t strspn(const char *, const char *);
char *strstr(const char *, const char *);
char *strtok(char *, const char *);
size_t strxfrm(char *, const char *, size_t);
char *_Strerror(int, char *);
/* macros */
#define ZeroMemoryB(a,b)	memsetB((a), 0, (b))
#define ZeroMemoryW(a,b)	memsetW((a), 0, (b))
#define ZeroMemoryT(a,b)	memsetT((a), 0, (b))
#define ZeroMemoryO(a,b)	memsetO((a), 0, (b))

		/* macro overrides */
#define strerror(errcode)	_Strerror(errcode, _NULL)
#endif
