=====
tally
=====

A small command line tool that counts things in text: words,
lines, headings, links, and anything else a pattern can match.

.. note::

   tally reads files or standard input, and prints a table at a
   terminal or JSON in a pipeline.

Install
=======

With a package manager:

.. code-block:: sh

   brew install tally
   cargo install tally

Usage
=====

Counters are named on the command line, each one a column.

========== ================================
Counter    What it counts
========== ================================
words      runs of letters and digits
lines      newline characters
headings   markdown and rst section titles
links      URLs and reference links
========== ================================

Output
------

tally prints a table when the output is a terminal, and one JSON
object per file otherwise:

.. code-block:: sh

   tally words -- README.md | jq '.words'

Configuration
-------------

Defaults live in ``~/.config/tally/config.toml``. A named match
becomes a counter of its own:

.. code-block:: toml

   [match.todo]
   pattern = "TODO|FIXME"
   ignore_case = true

Why another counter
===================

``wc`` counts bytes, words and lines, and it is everywhere. tally
exists for the questions ``wc`` cannot answer without a pipeline:

#. How many headings does each chapter have?
#. Which files still carry a ``TODO``?
#. How many links point outside the project?

*Each of those is one word to tally*, and the answers line up in
**one table**.

Contributing
============

Issues and pull requests are welcome. Every counter is a single
file under ``src/counters/``, so a new counter is a new file and
one line in the registry.
