/* memcpy function */
#include <string.h>

void *(memcpyW)(register void *s1, register const void *s2, register size_t n)
	{	/* copy char s2[n] to s1[n] in any order */
	int:16 *su1 = (int:16 *)s1;
	const int:16 *su2 = (const int:16 *)s2;

	for (; n > 0; ++su1, ++su2, --n)
		*su1 = *su2;
	return (s1);
	}
