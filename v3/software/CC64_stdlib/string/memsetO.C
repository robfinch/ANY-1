/* memset function */
#include <string.h>

void *(memsetO)(register void *s, register int c, register size_t n)
	{	/* store c throughout unsigned char s[n] */
	const unsigned int:64 uc = c;
	unsigned int:64 *su;

	su = (unsigned int:64 *)s;
	for (; n > 0; ++su, --n)
		*su = uc;
	return (s);
	}
