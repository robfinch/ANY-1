/* memset function */
#include <string.h>

void *(memsetH)(void *s, __int32 c, size_t n)
	{	/* store c throughout unsigned char s[n] */
	const unsigned __int32 uc = c;
	unsigned __int32 *su = (unsigned __int32 *)s;

	for (; 0 < n; ++su, --n)
		*su = uc;
	return (s);
	}
