# raku-tap2codewars

Transforms piped TAP to Codewars output.

## Usage

```bash
# Redirect diagnostics from stderr to stdout
$ raku 2>&1 t/example.t | tap2codewars
```

```bash
raku 2>&1 <<TEST | tap2codewars
use v6;
use Test;

is(1 - 1, 2, "intentional failure");

subtest 'tests', {
  is(1 - 1, 2, "another failure");
}

done-testing;
TEST
```

```text
<IT::>intentional failure

<FAILED::>expected: '2'<:LF:>     got: '0'

<COMPLETEDIN::>

<DESCRIBE::>tests

<IT::>another failure

<FAILED::>expected: '2'<:LF:>     got: '0'

<COMPLETEDIN::>

<COMPLETEDIN::>
```
