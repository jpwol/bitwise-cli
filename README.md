# bitline

**bitline** is a _cli interpreter_ for arithmetic and bitwise expressions.

#### Usage

```bash
$> ./bitline

>>> x = 1 + 2
3
>>> x
3
>>> x = x << 1
6
```

It can handle

- Variable assignment
- Parenthesis
- Operator precedence
- `+,-,*,/` operators
- `>` and `<` expressions
- bitwise operators `(&, |, <<, >>, ~, ^)`

#### Building

---

##### Linux

Either use `cmake` or `gcc`

```bash
git clone https://github.ocm/jpwol/bitline.git
cd bitline
cmake -B build
make -B build
cd bin
./bitline
```

or

```bash
git clone https://github.ocm/jpwol/bitline.git
cd bitline
mkdir bin
gcc -o bin/bitline src/main.c src/parse.c -I include
cd bin
./bitline
```

##### Windows

> [!NOTE] Ensure you have `libc` and `gcc` installed

```bash
git clone https://github.ocm/jpwol/bitline.git
cd bitline
mkdir bin
gcc -o bin/bitline src/main.c src/parse.c -I include
cd bin
./bitline
```
