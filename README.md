## bitwise-cli

**bitwise-cli** is a _command-line interpreter_ for arithmetic and bitwise expressions.

- Written in **Zig** (blazing fast)
- Supports:
  - Variable assignment
  - Certain _builtin_ functions
  - Parenthesis
  - Arithmetic operators (\*, /, +, -)
  - `>` and `<` expressions
  - Bitwise operators (&, |, <<, >>, ~, ^)

Currently NOT supported

- Float representation
  - All input must be integers (of size i64)
- Input in binary notation
- Output in binary notation

#### Usage

Variable names are now fully supported. Use **_any_** alphabetical character or string as a variable name, as long as it's not reserved for a function name

All variables are **initialized to 0** at runtime.

> [!NOTE]
> to exit the program, either use `<CTRL-D>` for _EOF_ or use the builtin exit function, `exit(return_value)`

```bash
$> ./bitwise

>>> x
0
>>> x = 5
5
>>> y = 10
10
>>> foo = x + y
15
>>> foo
15
>>> exit(0)
```

#### Building

---

> [!NOTE]
> Zig version 0.14.0 or higher is required

```bash
git clone https://github.com/jpwol/bitwise-cli.git
cd bitwise-cli
zig build
cd bin
./bitwise
```

Optionally, specify one of `Debug, ReleaseSafe, ReleaseFast, ReleaseSmall` for `-Doptimize`:

```bash
zig build -Doptimize=ReleaseFast
```

#### How it works

---

The previous version of this program, which can be found under the `legacy` branch, made use of the **shunting yard** algorithm, and a **stack-based** approach to parsing and evaluating.

The weakness of this stack-based approach is the difficulty in parsing variables, as well as assigning the correct values to them based on expressions.

This new version uses an **Abstract Syntax Tree** and **recursive descent parsing** to easily and quickly parse the tokens of any given expression and make sure all variable and function names are evaluated correctly.
