import gmp

proc myfact(n: int): GmpInt =
  result = 1.initGmpInt
  for i in 2..n:
    result = result * i

doAssert fact(1000) == myfact(1000)
#echo myfact(100000)

for i in 1..100:
  doAssert isOdd(i.initGmpInt ^ 314) != isEven(i ^ 2718)

doAssert binom(314, 99) == fact(314) div (fact(99) * fact(314-99))
let z = 24 ^ 100
doAssert 0 == (z and not z)
let z2 = 42 ^ 99
doAssert(z * z2 div gcd(z, z2) == lcm(z, z2))
doAssert divmod(z2, z) == (z2 div z, z2 mod z)
doAssert z2 > z
doAssert z * z >= z2
doAssert ((-10).initGmpInt ^ 100 > 0)

echo "2345298238947789177389172432978748914".initGmpInt * 163341

