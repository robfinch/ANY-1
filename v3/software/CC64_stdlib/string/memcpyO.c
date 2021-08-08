/* memcpy function */
#include <string.h>

void *(memcpyO)(register void *s1, register const void *s2, register size_t n)
	{	/* copy char s2[n] to s1[n] in any order */
	int:64 *su1 = (int:64 *)s1;
	const int:64 *su2 = (const int:64 *)s2;

	for (; n > 0; ++su1, ++su2, --n)
		*su1 = *su2;
	return (s1);
	}
