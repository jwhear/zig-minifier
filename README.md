# Code Golf Minifier for Zig
This program is a simple minifier for the Zig language.  It's small and simple thanks to Zig putting many parts of the compiler into the standard library.  This minifier only leverages tokenization so it unable to perform a number of more complex minifications.

## Supported optimizations

* Stripping unnecessary whitespace
* Stripping of comments
* Renaming of identifiers
* Translating character literals to decimal equivalents (e.g. `'A'` to `65`; 3 characters to 2)

## Unsupported optimizations
Because no AST generation or semantic analysis is performed some optimizations are still the domain of the coder:

* Introducing shorter names for commonly used types
* Inlining functions where it would be more efficient
* Loop rewriting
* and plenty of others

## Recommended Usage
This program will enable to retain your code golf solutions locally in a nice readable form and condense them at the last possible moment.  Here's a recommended workflow on Linux:

* Edit code in your favorite editor, save
* Run `zig-minifier <code.zig | xsel -ib`
* Paste the result into the textarea on code.golf
