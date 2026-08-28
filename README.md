![version](https://img.shields.io/badge/version-17%2B-3E8B93)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-32%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-metaphone)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-metaphone/total)

# 4d-plugin-metaphone

The Metaphone plug-in adds **Double Metaphone** phonetic encoding to 4D. It accepts a text value and returns a 4D collection containing the two Double Metaphone codes generated for that value:

1. **Primary code**
2. **Secondary code**

Double Metaphone is useful when you want to compare words or names by approximate pronunciation rather than exact spelling. A name such as `SMITH` and a similarly pronounced spelling can therefore be compared using their phonetic codes.

**Platforms:** macOS and Windows, subject to the platforms supported by the supplied 4D plug-in build.

---

## Requirements & platform notes

- The plug-in exposes one command: `DoubleMetaphone`.
- The command takes **one mandatory Text parameter**.
- The command returns a **Collection** containing two text elements.
- Element 0 is the **primary** Double Metaphone code.
- Element 1 is the **secondary** Double Metaphone code.
- The plug-in's implementation uses an internal MacRoman representation before running the phonetic algorithm. This is an implementation detail that can affect characters that are not representable in MacRoman; ordinary Latin names and text are the primary intended use case.
- The plug-in does not expose optional parameters.
- The source limits each returned code to a maximum of 999 characters.
- For an empty input string, the command returns a collection containing two empty strings.

## DoubleMetaphone

**DoubleMetaphone ( text ) → Collection**

### Syntax

```4d
DoubleMetaphone ( text ) : Collection
```

### Parameters

| Parameter | Type | Description |
|---|---|---|
| `text` | Text | Text to convert to Double Metaphone phonetic codes. This parameter is mandatory. |
| `Result` | Collection | A collection containing exactly two text values in normal operation: the primary code at index 0 and the secondary code at index 1. |

### Description

`DoubleMetaphone` converts the supplied text into phonetic representations using the Double Metaphone algorithm.

The result is a 4D collection with two entries:

```text
index 0 → primary code
index 1 → secondary code
```

The primary code is the algorithm's main pronunciation. The secondary code represents an alternative pronunciation when Double Metaphone identifies one.

The two codes are deliberately returned together. When comparing names, applications can compare the primary codes first and use the secondary codes when an alternative pronunciation needs to be considered.

The command performs its work synchronously. The implementation has been adjusted so that the Slavo-Germanic detection is calculated once per input rather than repeatedly scanning the complete input during character processing.

### Result handling

The returned collection can be assigned directly to a 4D collection variable:

```4d
$codes:=DoubleMetaphone("SMITH")
```

Access the two codes by their collection indexes:

```4d
$primary:=$codes[0]
$secondary:=$codes[1]
```

### Example

The plug-in's supplied test file contains:

```4d
$codes:=DoubleMetaphone("SMITH")
$codes:=DoubleMetaphone("SMIHT")
```

A practical comparison can be written as:

```4d
$codes1:=DoubleMetaphone("SMITH")
$codes2:=DoubleMetaphone("SMYTH")

$match:=($codes1[0]=$codes2[0]) | ($codes1[0]=$codes2[1]) | ($codes1[1]=$codes2[0]) | ($codes1[1]=$codes2[1])
```

This treats either primary or secondary code as a possible phonetic match.

For inspecting the returned values during development, a simple 4D alert is also useful:

```4d
$codes:=DoubleMetaphone("WASHINGTON")
ALERT($codes[0]+Char(13)+$codes[1])
```

## Typical usage patterns

### Store the two codes

```4d
$codes:=DoubleMetaphone($name)
$primary:=$codes[0]
$secondary:=$codes[1]
```

### Compare two names phonetically

```4d
$a:=DoubleMetaphone($nameA)
$b:=DoubleMetaphone($nameB)

If (($a[0]=$b[0]) | ($a[0]=$b[1]) | ($a[1]=$b[0]) | ($a[1]=$b[1]))
	// Treat as a phonetic match.
End if
```

### Process several names

```4d
For each ($name;$names)
	$codes:=DoubleMetaphone($name)
	// $codes[0] = primary
	// $codes[1] = secondary
End for each
```

## Error and edge-case behavior

The plug-in does not define a custom 4D error code or an error-return value for this command.

An empty text value is valid and produces two empty result strings.

The implementation performs defensive checks around the 4D collection and string parameter. If an internal allocation cannot be completed, the command cannot produce its normal collection result; this is an exceptional resource-exhaustion condition rather than a normal input-validation result.

## Output length

Each returned phonetic code is limited to 999 characters. Normal names and words are far below this limit. The limit is intended to prevent unbounded growth of the result strings for unusually large inputs.

## Unicode and character handling

The 4D parameter is a Unicode text value, but the supplied implementation converts it to MacRoman internally before applying the Double Metaphone rules. Consequently, characters that cannot be represented by MacRoman may not produce the same phonetic result as a fully Unicode-native implementation.

For best interoperability with this version of the plug-in, use ordinary Latin-alphabet names and text compatible with MacRoman.

## Summary

| Command | Returns | Purpose |
|---|---|---|
| [DoubleMetaphone](#doublemetaphone) | Collection | Returns the primary and secondary Double Metaphone codes for a text value. |
