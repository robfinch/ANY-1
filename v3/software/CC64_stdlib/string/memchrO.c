/* memchr function */
#include <string.h>

void *(memchrO)(register const void *s, register int c, register size_t n)
	{	/* find first occurrence of c in s[n] */
	int m;
	const unsigned int:64 uc = c;
	const unsigned int:64 *su = (const unsigned int:64 *)s;

	for (; n > 0; ++su, --n)
		if (*su == uc)
			return ((void *)su);
	return (NULL);
	}
