/* memset function */
#include <string.h>

void *(memsetW)(register void *s, register int c, register size_t n)
	{	/* store c throughout unsigned char s[n] */
	const unsigned int:16 uc = c;
	unsigned int:16 *su = (unsigned int:16 *)s;

	for (; n > 0; ++su, --n)
		*su = uc;
	return (s);
	}
