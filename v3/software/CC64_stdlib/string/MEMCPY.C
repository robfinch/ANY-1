/* memcpy function */
#include <string.h>

void *(memcpy)(register void *s1, register const void *s2, register size_t n)
	{	/* copy char s2[n] to s1[n] in any order */
	byte *su1 = (byte *)s1;
	const byte *su2 = (const byte *)s2;

	for (; n > 0; ++su1, ++su2, --n)
		*su1 = *su2;
	return (s1);
	}
