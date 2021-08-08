/* memchr function */
#include <string.h>

void *(memchr)(register const void *s, register int c, register size_t n)
	{	/* find first occurrence of c in s[n] */
	int m;
	const unsigned int:8 uc = c;
	const unsigned int:8 *su = (const unsigned int:8 *)s;

  while ((su & 7) && 0 < n) {
		if (*su == uc)
			return ((void *)su);
    su++;
    --n;            
  }
  if (n >= 8) {
    while (n >= 8) {
      if ((m = __bytendx(*(int *)su, uc)) >= 0) {
        return ((void *)((int:8*)su + m));
      }
      su += 8;
      n -= 8;
    }
  }
  else
	for (; 0 < n; ++su, --n)
		if (*su == uc)
			return ((void *)su);
	return (NULL);
	}
