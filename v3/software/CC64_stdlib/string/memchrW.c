/* memchr function */
#include <string.h>

void *(memchrW)(register const void *s, register int c, register size_t n)
	{	/* find first occurrence of c in s[n] */
	int m;
	const unsigned int:16 uc = c;
	const unsigned int:16 *su = (const unsigned int:16 *)s;

  while ((su & 3) && n > 0) {
		if (*su == uc)
			return ((void *)su);
    su++;
    --n;            
  }
  if (n >= 4) {
    while (n >= 4) {
      if ((m = __wydendx(*(int *)su, uc)) >= 0) {
        return ((void *)((int:16*)su + m));
      }
      su += 4;
      n -= 4;
    }
  }
  else
	for (; n > 0; ++su, --n)
		if (*su == uc)
			return ((void *)su);
	return (NULL);
	}
