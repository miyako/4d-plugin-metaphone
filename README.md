![version](https://img.shields.io/badge/version-17%2B-3E8B93)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-32%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-metaphone)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-metaphone/total)

# 4d-plugin-metaphone

## Manual versioning and publication

**Bump version** and **Build** are independent manual Actions. Neither runs on
pushes, tags, or pull requests. Run **Bump version** on a branch with `patch`,
`minor`, or `major`; it commits only source version metadata, without building,
tagging, releasing, or dispatching another workflow. Run **Build** separately:
it has **zero inputs**, only GitHub's branch selector. Every checkout pins the
selected `github.sha`; the version and `vX.Y.Z` tag come from that commit's
validated source, never an entered tag.

### Version authority

The original Bump header, introduced in `bbcbc4a18a131be0341770d4621118c20efbbf67`,
explicitly coordinates `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` with
`CFBundleShortVersionString` and an existing `CFBundleVersion`. Its marketing-first
body failed to implement that contract. The later
`4cd2f57322e36cf85201bfe677297db5bbf6fccf` commit message explicitly reaffirmed
coordination; this is not an independent build-number policy.

The source authority is `Metaphone.xcodeproj/project.pbxproj` (six assignments
of each version key), `Info.plist`, and `English.lproj/InfoPlist.strings`.
Versions must be consistent, strict `X.Y.Z` without leading zeroes or suffixes.
Supported `$(MARKETING_VERSION)`, `${MARKETING_VERSION}`,
`$(CURRENT_PROJECT_VERSION)`, and `${CURRENT_PROJECT_VERSION}` plist references
are preserved; current-project settings may reference marketing, never themselves.
An absent optional `CFBundleVersion` stays absent. Duplicate plist/localized keys
and project assignments, including inline quoted duplicates, fail before writes.
Bumps preserve source modes, BOM, each individual line ending, references, and
unrelated bytes.

Migration does **not** increment the existing `1.0.5` source version. It repairs
only six stale source `CURRENT_PROJECT_VERSION = 1.0.3` assignments and the two
source localization `1.0.0` tokens to that existing authority. Committed binaries,
bundles (including copied localization), archives, dependencies, native project
settings, manifests, and 4D database/catalog counters are not version authorities
and are not rewritten.

Bump requires a clean selected commit and an unchanged remote branch, then checks
the new commit is exactly one direct child changing a nonempty metadata-only path
set. Its mandatory executable pre-push hook checks Git's advertised old SHA,
exact branch and literal new SHA; zero or multiple updates fail. Hook availability
is checked initially and immediately before the explicit non-force branch push.
Both `push.followTags=false` and `--no-follow-tags` prevent unrelated tags following.
Generated commits include the Copilot App co-author trailer.

### Build and failure recovery

Build retains Windows Release/x64 with the v143/Windows SDK 10.0 overrides and
macOS Default/arm64+x86_64 with the original **11.0 CI deployment override**.
It preserves committed bundle resources and dependencies, invalidates only rebuilt
outputs, requires the exact Windows project output and downloaded filename, and
checks the rebuilt plist/localization against source (including UTF-16 and compiled
binary localization). Exact required `arm64` and `x86_64` slices are checked;
no previously absent no-i386 or dependency-architecture gate is introduced.
Signing and strict verification remain mandatory. Both notarization commands must
succeed **and** return JSON `Accepted`, followed by successful DMG stapling.

A repository-wide constant publication concurrency group serializes Build across
branches without cancellation. Before native work and again after all native,
signing, notarization and stapling gates, authenticated, paginated API requests check
all releases, including drafts, and exact remote tag absence. Authentication,
network, 404, malformed responses, and errors on any page fail closed.

Publication creates a new tag with `POST git/refs` at the selected SHA and verifies
it remotely. A separate `POST releases` explicitly creates a new public,
non-prerelease with the original empty body and matching tag/name/target SHA.
Assets upload only to that newly returned release ID. Existing tags or releases
are never reused, overwritten, patched, deleted, retried, or rolled back, including
same-SHA races.

**On failure, any created tag, release, and earlier uploaded assets remain.**
Stop and inspect the Actions error and remote state manually. A rerun intentionally
fails if the version's tag or any draft/public release already exists. An authorized
maintainer must decide how to recover retained partial publication; the workflow
will not repair it automatically. For a new release, bump source to a new version
and dispatch Build separately after that decision.

### Offline regression checks and prior art

Run `actionlint .github/workflows/*.yml` and
`python3 -B -m unittest discover -s .github/tests -v` (Python 3.10+ and PowerShell
required for the complete suite). Tests use disposable real Git repositories and
bare origins, mocked API transport, closed-PATH native stubs, and PowerShell
fixtures. They never perform real builds, signing, notarization, 4D execution,
or production publication. Run the full suite both live and in a disposable copy
after a genuine helper-driven bump; fixtures derive the source version.

The implementation was adapted, not path/count/policy-copied, from these exact
`miyako/4d-plugin-` snapshots:

| Repository suffix | Pinned commit |
|---|---|
| native-encoding-detection | `c42ca565857f674bde5ea6ed3435c87375eda4a7` |
| file-information | `19848973601acfd3a2b5070230fa40cdc7e4edb2` |
| common-string-algorithm | `2606a68201866ec9fcbb38b51462d79215f504ef` |
| window-button | `3f14facb9aaaaff0e22eeb8e07531163680c3a8a` |
| raw-picture-data | `8144537fdc8dcc3d0c053dfe97aff0a8c0c3a6f9` |

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

## Native string ownership maintenance

The ownership audit baseline is `5d625793a808eaa202d6accf7a206161edf68930`.
Source and bundled resource manifests both declare only `DoubleMetaphone(&T):C`;
selector 1 calls the synchronous scalar-input/collection-output implementation.
Neither manifest declares a text array. Inventory includes tracked helpers, not
just indexed command declarations:

| First-party surface | Native project reachability | Ownership result |
|---|---|---|
| `4DPlugin-Metaphone.cpp` | Windows and macOS | Borrowed parameter is converted before return; independent scalar strings are copied into two collection elements. Start temporary variables Undefined before assigning their owning descriptors, avoiding loss of an SDK-created empty string. Preserve collection return ownership. |
| `Classes/C_TEXT.*` | macOS compiled, no command call site; Windows not compiled | Copies borrowed parameter content into a C++ string; engine content setter updates output. |
| `Classes/ARRAY_TEXT.*` | Dormant in both projects | Copies borrowed array elements; creates independent strings for accepted array transfers without disposing transferred aliases. Tested for replacement, shrink, final clear and SDK rejection semantics; allocation/resize failure recovery is not certified. |
| `support/4DPlugin-JSON.*` | Dormant in both projects | Four string setters now start Undefined. String/boolean/number property readers clear owning results after copying, including mismatches. Collection reader clears mismatches but preserves the successful owning-reference handoff. Stringify copies output before clearing its returned variable. |
| `Classes/C_BLOB.*`, `Classes/C_LONGINT.*`, `Classes/C_TYPES.h` | Dormant helpers/types | No additional `PA_Unistring` owner/transfer path. No `CPicture` or `C_POINTER` wrapper is present. Non-string resource behavior is outside this audit. |

Third-party jsoncpp headers and static libraries, archived distributions and
prebuilt native binaries are not modified or certified. Compiled/bundled
metadata agreement does not prove that prebuilt binaries match this source.

The unchanged bundled SDK's header says `rev: v14`, **not** a verified upstream
release identity. Its `PA_CreateVariable(eVK_Unistring)` creates an initial empty
string, while `PA_SetStringVariable` shallow-overwrites the descriptor without
disposing the old allocation. The initial allocation can be lost even when its
length is zero. Starting Undefined avoids that allocation and retains final
`PA_ClearVariable` cleanup of the newly assigned owner.

`PA_GetObjectProperty` explicitly requires clearing its returned variable.
`PA_GetCollectionVariable` extracts its reference: `ob_get_c` transfers that
existing owner to its caller, who must eventually dispose it. Do not clear the
successful local alias. `PA_SetStringInArray` disposes the old element and
shallow-transfers only for Unicode arrays with non-null data, non-null input and
indexes zero through the inclusive element count; rejected calls retain caller
ownership. `PA_GetStringInArray` is borrowed. Scalar `PA_SetUnistring` is an
engine-backed content operation, not that array descriptor transfer.

Run the non-release macOS regression independently:

```sh
python3 -B -m unittest discover -s .github/tests -p test_ownership.py -v
```

It compiles actual command/helper sources and the **full unchanged SDK**, with an
engine-boundary shim, ASan/UBSan, and explicit string/handle/reference accounting.
No native project build phases, signing, packaging or publication run. LeakSanitizer
is disabled on macOS; accounting catches lost descriptors under allocated-empty
and null-empty representations. Cases cover dispatcher output, repeated cleanup,
independent collection copies, all four string setter overloads, property
matches/mismatches and successful object/collection owning handoffs, borrowed
scalar/array copies, array replacement/shrink/clear and rejected type/index/data.
ASCII, BMP, supplementary pairs and empty fixtures assert exact content and
lengths; the charset boundary uses byte capacities/returned lengths, excluding
termination, as documented by this SDK.

Set `METAPHONE_SOURCE_ROOT` to an extracted immutable baseline to run the same
final harness against original source. Allocated-empty command/output/setter
cases and property-result leak cases fail on the baseline and pass after the
fix. Engine callbacks model deep string copies and owning property results;
the string-valued `PA_GetStringVariable` callback is modeled as borrowed, not a
claim about non-string conversion results. The actual engine is not bundled.
This is **not** real-4D execution or Windows certification; engine allocation
failure behavior, other SDK revisions and prebuilt distributions remain untested.

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
