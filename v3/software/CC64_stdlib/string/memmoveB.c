/* memmove function */
#include <string.h>

void *(memmoveB)(register void *s1, register const void *s2, register size_t n)
{	/* copy char s2[n] to s1[n] safely */
	int:8 *sc1 = (int:8 *)s1;
	const int:8 *sc2 = (const int:8 *)s2;

	if (sc2 < sc1 &&& sc1 < sc2 + n) {
	  if (n >= 8) {
  		for (sc1 += n, sc2 += n; 0 < n; n = n - 8) {
  			sc1 -= 8/sizeof(int:8);
  			sc2 -= 8/sizeof(int:8);
  			*(int *)sc1 = *(int *)sc2;	/*copy backwards */
  		}
	  }
	  else
		for (sc1 += n, sc2 += n; 0 < n; --n) {
			--sc1;
			--sc2;
			*sc1 = *sc2;	/*copy backwards */
		}
	}
	else {
	  if (n >= 8) {
	    for (; 0 < n; n -= 8) {
	      *(int *)sc1 = *(int *)sc2;
	      sc1 += 8/sizeof(int:8);
	      sc2 += 8/sizeof(int:8);
	    }
	  }
	  else
		for (; 0 < n; --n) {
			*sc1 = *sc2;
			sc1++;
			sc2++;	/* copy forwards */
		}
	  return (s1);
  }	
}
