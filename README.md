## bitwise-cli

**bitwise-cli** is a _command-line interpreter_ for arithmetic and bitwise expressions.

- Written in **Zig** (blazing fast)

### Features

---

> [NEW!]
>
> This program now runs in _non-canonical_ mode, allowing features such as input manipulation and input history! Like in
> the shell, use the `UP` and `DOWN` arrow keys to cycle through input history, and `LEFT` and `RIGHT` arrow keys to seek
> through the current buffer string.

- Supports:

  - Variable assignment (`foo = 20`)
  - Certain _builtin_ functions
    - `sqrt(x)`
    - `sin(x)`
    - `cos(x)`
    - `pow(x, y)`
    - `exit()` _or_ `exit(x)`
  - Parenthesis
  - Arithmetic operators (\*, /, +, -)
  - `>` and `<` expressions
  - Bitwise operators (&, |, <<, >>, ~, ^)

  All numbers are read as **floats** (f64), and coerced to **integers** (i64) for operations that require it (mainly bit operations)

#### Usage

Variable names are now fully supported. Use **_any_** alphabetical character or string as a variable name, as long as it's not reserved for a function name

> [!IMPORTANT]
>
> Variable names are NO LONGER initialized to 0 at runtime. Instead, the program will print an error if the user does not initialize the variable with a value.

> [!NOTE]
> to exit the program, either use `<CTRL-D>` for _EOF_ or use the builtin exit function, `exit(return_value)`

```bash
$> ./bitwise

>>> x = 6
6
>>> y = 10
10
>>> foo = sqrt(x + y)
4
>>> bar = pow(foo, 2)
16
>>> exit()
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
