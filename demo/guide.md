# tally

A small command line tool that counts things in text: words,
lines, headings, links, and anything else a pattern can match. It
reads files or standard input and prints a table, or JSON when
another program is reading.

> Counting is the first step of every report. tally makes it the
> only step you have to think about.

## Install

With a package manager:

```sh
brew install tally
cargo install tally
```

Or download a release binary and put it on your `$PATH`.

## Usage

Count the words and lines in every markdown file of a project:

```sh
tally words lines -- docs/**/*.md
```

Counters are named on the command line, each one a column:

| Counter    | What it counts                      |
| ---------- | ----------------------------------- |
| `words`    | runs of letters and digits          |
| `lines`    | newline characters                  |
| `headings` | markdown and rst section titles     |
| `links`    | URLs and reference links            |
| `match`    | a regular expression, after an `=`  |

### Output

tally prints a table when the output is a terminal, and one JSON
object per file otherwise, so the same command works at a prompt
and in a pipeline:

```sh
tally words -- README.md | jq '.words'
```

### Configuration

Defaults live in `~/.config/tally/config.toml`:

```toml
[defaults]
counters = ["words", "lines"]
format = "table"

[match.todo]
pattern = "TODO|FIXME"
ignore_case = true
```

A named match becomes a counter of its own, so `tally todo` works
after the configuration above.

## Why another counter

`wc` counts bytes, words and lines, and it is everywhere. tally
exists for the questions `wc` cannot answer without a pipeline:

1. How many headings does each chapter have?
2. Which files still carry a `TODO`?
3. How many links point outside the project?

Each of those is one word to tally, and the answers line up in
**one table**.

## Roadmap

- [x] Counters for words, lines, headings and links
- [x] JSON output
- [ ] Counting inside archives
- [ ] A watch mode that re-counts on save

## Contributing

Issues and pull requests are welcome. Run the checks before
sending one:

```sh
make test
make lint
```

Every counter is a single file under `src/counters/`, so a new
counter is a new file and one line in the registry.

## License

MIT. See `LICENSE` for the full text.
