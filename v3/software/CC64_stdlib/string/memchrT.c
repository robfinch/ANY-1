/* memchr function */
#include <string.h>

void *(memchrT)(register const void *s, register int c, register size_t n)
	{	/* find first occurrence of c in s[n] */
	int m;
	const unsigned int:32 uc = c;
	const unsigned int:32 *su = (const unsigned int:32 *)s;

	for (; n > 0; ++su, --n)
		if (*su == uc)
			return ((void *)su);
	return (NULL);
	}
