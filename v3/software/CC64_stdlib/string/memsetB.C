/* memset function */
#include <string.h>

void *(memsetB)(register void *s, register int c, register size_t n)
	{	/* store c throughout unsigned char s[n] */
	const unsigned int:8 uc = c;
	unsigned int:8 *su = (unsigned int:8 *)s;

	for (; n > 0; ++su, --n)
		*su = uc;
	return (s);
	}
