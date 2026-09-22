# Implementation research notes

Google's Gboard help explains that users add a language and then choose a layout; Google's product article states that Gboard supports native scripts and a QWERTY layout for transliteration. The implementation therefore keeps separate Roman/QWERTY and native-script modes and exposes native characters over multiple pages rather than forcing every character onto one crowded page.

The native keyboard inventory is kept in language-specific sequence: vowels,
consonants, script signs, and digits, split into compact pages. This matches
the Gboard principle of choosing a language and layout while keeping native
script and QWERTY/transliteration layouts separate. It is not a Unicode-block
scan, so unassigned code points and arbitrary page ordering are avoided.

Sarvam's current translation documentation confirms that
`sarvam-translate:v1` covers all 22 scheduled Indian languages but does not
support `output_script=roman`; Roman output is supported by the smaller
Mayura language set. Accordingly, Auto speech uses Sarvam realtime
`language_code=auto` plus `transcribe`/`translit`, while all-language text
translation uses Sarvam Translate's native-script output where Roman
transliteration is not supported by the upstream model.

Sources:
- https://support.google.com/gboard/answer/7068494?hl=en&co=GENIE.Platform%3DAndroid
- https://blog.google/products-and-platforms/products/search/gboard-android-gets-new-languages-and-tools/
- https://play.google.com/store/apps/details?id=com.google.android.inputmethod.latin&hl=en_US
- https://docs.sarvam.ai/api-reference/text/translate-text
- https://docs.sarvam.ai/api/getting-started/models/sarvam-translate

Sticker assets in this change are original transparent PNG illustrations generated for this app, not copied Google/Gboard assets. The Android media bridge already sends PNG/GIF content through a content URI so host apps can share/download/edit it instead of receiving a URL string.
