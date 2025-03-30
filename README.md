# bitline

**bitline** is a _cli interpreter_ for arithmetic and bitwise expressions.

#### Usage

Variables are supported, but only `a-z`. No multi-character variable names or uppercase letters.

All variables are **initialized to 0** at runtime.

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

Currently NOT supported

- Input in binary notation
- Output in binary notation

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

> [!NOTE]
> Ensure you have `libc` and `gcc` installed

```bash
git clone https://github.ocm/jpwol/bitline.git
cd bitline
mkdir bin
gcc -o bin/bitline src/main.c src/parse.c -I include
cd bin
./bitline
```

#### How it works

---

This program makes heavy use of the **shunting-yard** algorithm.
It takes user input as a string and splits it up into **tokens**.

These tokens can be a **number**, **operator**, **variable**, **left parenthesis**, or **right parenthesis**.
It then creates an array of these tokens in the format they're inputted, usually _infix_ notation.

To compute the results easier, it takes that input and converts it to _postfix_ notation (reverse-polish notation) which is much easier for computers to understand.

Then it simply allocates a stack and pops/pushes the values based on if they're an operator or number.

Operator precedence is calculated in the shunting-yard phase, and operators get pushed to the output stack based on their precedence.
