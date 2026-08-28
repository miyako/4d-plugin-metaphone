# Safe fixes applied

## Correctness and stability

- Fixed undefined behavior in `MakeUpper()` by converting bytes to `unsigned char` before calling `std::toupper()`.
- Corrected the MacRoman `ﬁ` uppercase mapping so it remains `ﬁ` rather than being incorrectly changed to `ﬂ`.
- Fixed the variadic `StringAt()` helper to retrieve string-literal arguments as `const char *`, matching the actual C++ argument type.
- Added null checks for the returned 4D collection and input unistring before dereferencing/using them.
- Made conversion buffers zero-initialized and explicitly NUL/UTF-16 terminated before constructing/returning strings.
- Preserved the existing 4D command interface and result order.

## Performance

- Evaluated the Slavo-Germanic condition once per input instead of repeatedly scanning the entire input from inside the main processing loop. This removes the previous avoidable O(n²) behavior.
- Replaced ineffective in-string NUL writes used for output limiting with `std::string::resize()`, so the 999-character output limit is actually enforced.

## Deliberately unchanged

- The plugin's exposed command remains `DoubleMetaphone(&T):C` and remains marked thread-safe in `manifest.json`.
- The MacRoman conversion model is retained to avoid changing the established Double Metaphone behavior or introducing an unverified Unicode implementation change.
- The existing exception boundary is retained because no verified 4D SDK error-reporting API is present in the supplied source; exceptions are not allowed to escape the plug-in entry point.
