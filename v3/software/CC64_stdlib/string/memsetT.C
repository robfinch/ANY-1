/* memset function */
#include <string.h>

void *(memsetT)(register void *s, register int c, register size_t n)
	{	/* store c throughout unsigned char s[n] */
	const unsigned int:32 uc = c;
	unsigned int:32 *su = (unsigned int:32 *)s;

	for (; n > 0; ++su, --n)
		*su = uc;
	return (s);
	}
