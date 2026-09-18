# Implementation research notes

Google's Gboard help explains that users add a language and then choose a layout; Google's product article states that Gboard supports native scripts and a QWERTY layout for transliteration. The implementation therefore keeps separate Roman/QWERTY and native-script modes and exposes native characters over multiple pages rather than forcing every character onto one crowded page.

Sources:
- https://support.google.com/gboard/answer/7068494?hl=en&co=GENIE.Platform%3DAndroid
- https://blog.google/products-and-platforms/products/search/gboard-android-gets-new-languages-and-tools/
- https://play.google.com/store/apps/details?id=com.google.android.inputmethod.latin&hl=en_US

Sticker assets in this change are original transparent PNG illustrations generated for this app, not copied Google/Gboard assets. The Android media bridge already sends PNG/GIF content through a content URI so host apps can share/download/edit it instead of receiving a URL string.
