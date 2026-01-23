/// Termux 兼容的 wcwidth 实现
///
/// 基于 Termux 的 WcWidth.java，使用 Unicode 15 标准
/// 参考: https://github.com/termux/termux-app/blob/master/terminal-emulator/src/main/java/com/termux/terminal/WcWidth.java
///
/// 这个实现与 Termux 保持一致，确保终端显示与 shell 的字符宽度计算匹配

/// 零宽字符表 - 从 Termux WcWidth.java 复制
const List<List<int>> _zeroWidth = [
  [0x00300, 0x0036f], // Combining Grave Accent  ..Combining Latin Small Le
  [0x00483, 0x00489], // Combining Cyrillic Titlo..Combining Cyrillic Milli
  [0x00591, 0x005bd], // Hebrew Accent Etnahta   ..Hebrew Point Meteg
  [0x005bf, 0x005bf], // Hebrew Point Rafe
  [0x005c1, 0x005c2], // Hebrew Point Shin Dot   ..Hebrew Point Sin Dot
  [0x005c4, 0x005c5], // Hebrew Mark Upper Dot   ..Hebrew Mark Lower Dot
  [0x005c7, 0x005c7], // Hebrew Point Qamats Qata
  [0x00610, 0x0061a], // Arabic Sign Sallallahou ..Arabic Small Kasra
  [0x0064b, 0x0065f], // Arabic Fathatan         ..Arabic Wavy Hamza Below
  [0x00670, 0x00670], // Arabic Letter Superscript Alef
  [0x006d6, 0x006dc], // Arabic Small High Ligature Sad With Lam With Alef
  [0x006df, 0x006e4], // Arabic Small High Rounded Zero
  [0x006e7, 0x006e8], // Arabic Small High Yeh   ..Arabic Small High Noon
  [0x006ea, 0x006ed], // Arabic Empty Centre Low Stop
  [0x00711, 0x00711], // Syriac Letter Superscript Alaph
  [0x00730, 0x0074a], // Syriac Pthaha Above     ..Syriac Barrekh
  [0x007a6, 0x007b0], // Thaana Abafili          ..Thaana Sukun
  [0x007eb, 0x007f3], // Nko Combining Short High Tone
  [0x007fd, 0x007fd], // Nko Dantayalan
  [0x00816, 0x00819], // Samaritan Mark In       ..Samaritan Mark Dagesh
  [0x0081b, 0x00823], // Samaritan Mark Epenthetic Yut
  [0x00825, 0x00827], // Samaritan Vowel Sign Short A
  [0x00829, 0x0082d], // Samaritan Vowel Sign Long I
  [0x00859, 0x0085b], // Mandaic Affrication Mark
  [0x00898, 0x0089f], // Arabic Small High Word Al-juz
  [0x008ca, 0x008e1], // Arabic Small High Farsi Yeh
  [0x008e3, 0x00902], // Arabic Turned Damma Below
  [0x0093a, 0x0093a], // Devanagari Vowel Sign Oe
  [0x0093c, 0x0093c], // Devanagari Sign Nukta
  [0x00941, 0x00948], // Devanagari Vowel Sign U
  [0x0094d, 0x0094d], // Devanagari Sign Virama
  [0x00951, 0x00957], // Devanagari Stress Sign Udatta
  [0x00962, 0x00963], // Devanagari Vowel Sign Vocalic L
  [0x00981, 0x00981], // Bengali Sign Candrabindu
  [0x009bc, 0x009bc], // Bengali Sign Nukta
  [0x009c1, 0x009c4], // Bengali Vowel Sign U
  [0x009cd, 0x009cd], // Bengali Sign Virama
  [0x009e2, 0x009e3], // Bengali Vowel Sign Vocalic L
  [0x009fe, 0x009fe], // Bengali Sandhi Mark
  [0x00a01, 0x00a02], // Gurmukhi Sign Adak Bindi
  [0x00a3c, 0x00a3c], // Gurmukhi Sign Nukta
  [0x00a41, 0x00a42], // Gurmukhi Vowel Sign U
  [0x00a47, 0x00a48], // Gurmukhi Vowel Sign Ee
  [0x00a4b, 0x00a4d], // Gurmukhi Vowel Sign Oo
  [0x00a51, 0x00a51], // Gurmukhi Sign Udaat
  [0x00a70, 0x00a71], // Gurmukhi Tippi
  [0x00a75, 0x00a75], // Gurmukhi Sign Yakash
  [0x00a81, 0x00a82], // Gujarati Sign Candrabindu
  [0x00abc, 0x00abc], // Gujarati Sign Nukta
  [0x00ac1, 0x00ac5], // Gujarati Vowel Sign U
  [0x00ac7, 0x00ac8], // Gujarati Vowel Sign E
  [0x00acd, 0x00acd], // Gujarati Sign Virama
  [0x00ae2, 0x00ae3], // Gujarati Vowel Sign Vocalic L
  [0x00afa, 0x00aff], // Gujarati Sign Sukun
  [0x00b01, 0x00b01], // Oriya Sign Candrabindu
  [0x00b3c, 0x00b3c], // Oriya Sign Nukta
  [0x00b3f, 0x00b3f], // Oriya Vowel Sign I
  [0x00b41, 0x00b44], // Oriya Vowel Sign U
  [0x00b4d, 0x00b4d], // Oriya Sign Virama
  [0x00b55, 0x00b56], // Oriya Sign Overline
  [0x00b62, 0x00b63], // Oriya Vowel Sign Vocalic L
  [0x00b82, 0x00b82], // Tamil Sign Anusvara
  [0x00bc0, 0x00bc0], // Tamil Vowel Sign Ii
  [0x00bcd, 0x00bcd], // Tamil Sign Virama
  [0x00c00, 0x00c00], // Telugu Sign Combining Candrabindu Above
  [0x00c04, 0x00c04], // Telugu Sign Combining Anusvara Above
  [0x00c3c, 0x00c3c], // Telugu Sign Nukta
  [0x00c3e, 0x00c40], // Telugu Vowel Sign Aa
  [0x00c46, 0x00c48], // Telugu Vowel Sign E
  [0x00c4a, 0x00c4d], // Telugu Vowel Sign O
  [0x00c55, 0x00c56], // Telugu Length Mark
  [0x00c62, 0x00c63], // Telugu Vowel Sign Vocalic L
  [0x00c81, 0x00c81], // Kannada Sign Candrabindu
  [0x00cbc, 0x00cbc], // Kannada Sign Nukta
  [0x00cbf, 0x00cbf], // Kannada Vowel Sign I
  [0x00cc6, 0x00cc6], // Kannada Vowel Sign E
  [0x00ccc, 0x00ccd], // Kannada Vowel Sign Au
  [0x00ce2, 0x00ce3], // Kannada Vowel Sign Vocalic L
  [0x00d00, 0x00d01], // Malayalam Sign Combining Anusvara Above
  [0x00d3b, 0x00d3c], // Malayalam Sign Vertical Bar Virama
  [0x00d41, 0x00d44], // Malayalam Vowel Sign U
  [0x00d4d, 0x00d4d], // Malayalam Sign Virama
  [0x00d62, 0x00d63], // Malayalam Vowel Sign Vocalic L
  [0x00d81, 0x00d81], // Sinhala Sign Candrabindu
  [0x00dca, 0x00dca], // Sinhala Sign Al-lakuna
  [0x00dd2, 0x00dd4], // Sinhala Vowel Sign Ketti Is-pilla
  [0x00dd6, 0x00dd6], // Sinhala Vowel Sign Diga Paa-pilla
  [0x00e31, 0x00e31], // Thai Character Mai Han-akat
  [0x00e34, 0x00e3a], // Thai Character Sara I
  [0x00e47, 0x00e4e], // Thai Character Maitaikhu
  [0x00eb1, 0x00eb1], // Lao Vowel Sign Mai Kan
  [0x00eb4, 0x00ebc], // Lao Vowel Sign I
  [0x00ec8, 0x00ece], // Lao Tone Mai Ek
  [0x00f18, 0x00f19], // Tibetan Astrological Sign -khyud Pa
  [0x00f35, 0x00f35], // Tibetan Mark Ngas Bzung Nyi Zla
  [0x00f37, 0x00f37], // Tibetan Mark Ngas Bzung Sgor Rtags
  [0x00f39, 0x00f39], // Tibetan Mark Tsa -phru
  [0x00f71, 0x00f7e], // Tibetan Vowel Sign Aa
  [0x00f80, 0x00f84], // Tibetan Vowel Sign Reversed I
  [0x00f86, 0x00f87], // Tibetan Sign Lci Rtags
  [0x00f8d, 0x00f97], // Tibetan Subjoined Sign Lce Tsa Can
  [0x00f99, 0x00fbc], // Tibetan Subjoined Letter Ka
  [0x00fc6, 0x00fc6], // Tibetan Symbol Padma Gdan
  [0x0102d, 0x01030], // Myanmar Vowel Sign I
  [0x01032, 0x01037], // Myanmar Vowel Sign Ai
  [0x01039, 0x0103a], // Myanmar Sign Virama
  [0x0103d, 0x0103e], // Myanmar Consonant Sign Medial Wa
  [0x01058, 0x01059], // Myanmar Vowel Sign Vocalic L
  [0x0105e, 0x01060], // Myanmar Consonant Sign Mon Medial Na
  [0x01071, 0x01074], // Myanmar Vowel Sign Geba Karen I
  [0x01082, 0x01082], // Myanmar Consonant Sign Shan Medial Wa
  [0x01085, 0x01086], // Myanmar Vowel Sign Shan E Above
  [0x0108d, 0x0108d], // Myanmar Sign Shan Council Emphatic Tone
  [0x0109d, 0x0109d], // Myanmar Vowel Sign Aiton Ai
  [0x0135d, 0x0135f], // Ethiopic Combining Gemination And Vowel Length Mark
  [0x01712, 0x01714], // Tagalog Vowel Sign I
  [0x01732, 0x01733], // Hanunoo Vowel Sign I
  [0x01752, 0x01753], // Buhid Vowel Sign I
  [0x01772, 0x01773], // Tagbanwa Vowel Sign I
  [0x017b4, 0x017b5], // Khmer Vowel Inherent Aq
  [0x017b7, 0x017bd], // Khmer Vowel Sign I
  [0x017c6, 0x017c6], // Khmer Sign Nikahit
  [0x017c9, 0x017d3], // Khmer Sign Muusikatoan
  [0x017dd, 0x017dd], // Khmer Sign Atthacan
  [0x0180b, 0x0180d], // Mongolian Free Variation Selector One
  [0x0180f, 0x0180f], // Mongolian Free Variation Selector Four
  [0x01885, 0x01886], // Mongolian Letter Ali Gali Baluda
  [0x018a9, 0x018a9], // Mongolian Letter Ali Gali Dagalga
  [0x01920, 0x01922], // Limbu Vowel Sign A
  [0x01927, 0x01928], // Limbu Vowel Sign E
  [0x01932, 0x01932], // Limbu Small Letter Anusvara
  [0x01939, 0x0193b], // Limbu Sign Mukphreng
  [0x01a17, 0x01a18], // Buginese Vowel Sign I
  [0x01a1b, 0x01a1b], // Buginese Vowel Sign Ae
  [0x01a56, 0x01a56], // Tai Tham Consonant Sign Medial La
  [0x01a58, 0x01a5e], // Tai Tham Sign Mai Kang Lai
  [0x01a60, 0x01a60], // Tai Tham Sign Sakot
  [0x01a62, 0x01a62], // Tai Tham Vowel Sign Mai Sat
  [0x01a65, 0x01a6c], // Tai Tham Vowel Sign I
  [0x01a73, 0x01a7c], // Tai Tham Vowel Sign Oa Above
  [0x01a7f, 0x01a7f], // Tai Tham Combining Cryptogrammic Dot
  [0x01ab0, 0x01ace], // Combining Doubled Circumflex Accent
  [0x01b00, 0x01b03], // Balinese Sign Ulu Ricem
  [0x01b34, 0x01b34], // Balinese Sign Rerekan
  [0x01b36, 0x01b3a], // Balinese Vowel Sign Ulu
  [0x01b3c, 0x01b3c], // Balinese Vowel Sign La Lenga
  [0x01b42, 0x01b42], // Balinese Vowel Sign Pepet
  [0x01b6b, 0x01b73], // Balinese Musical Symbol Combining Tegeh
  [0x01b80, 0x01b81], // Sundanese Sign Panyecek
  [0x01ba2, 0x01ba5], // Sundanese Consonant Sign Panyakra
  [0x01ba8, 0x01ba9], // Sundanese Vowel Sign Pamepet
  [0x01bab, 0x01bad], // Sundanese Sign Virama
  [0x01be6, 0x01be6], // Batak Sign Tompi
  [0x01be8, 0x01be9], // Batak Vowel Sign Pakpak E
  [0x01bed, 0x01bed], // Batak Vowel Sign Karo O
  [0x01bef, 0x01bf1], // Batak Vowel Sign U For Simalungun Sa
  [0x01c2c, 0x01c33], // Lepcha Vowel Sign E
  [0x01c36, 0x01c37], // Lepcha Sign Ran
  [0x01cd0, 0x01cd2], // Vedic Tone Karshana
  [0x01cd4, 0x01ce0], // Vedic Sign Yajurvedic Midline Svarita
  [0x01ce2, 0x01ce8], // Vedic Sign Visarga Svarita
  [0x01ced, 0x01ced], // Vedic Sign Tiryak
  [0x01cf4, 0x01cf4], // Vedic Tone Candra Above
  [0x01cf8, 0x01cf9], // Vedic Tone Ring Above
  [0x01dc0, 0x01dff], // Combining Dotted Grave Accent
  [0x020d0, 0x020f0], // Combining Left Harpoon Above
  [0x02cef, 0x02cf1], // Coptic Combining Ni Above
  [0x02d7f, 0x02d7f], // Tifinagh Consonant Joiner
  [0x02de0, 0x02dff], // Combining Cyrillic Letter Be
  [0x0302a, 0x0302d], // Ideographic Level Tone Mark
  [0x03099, 0x0309a], // Combining Katakana-hiragana Voiced Sound Mark
  [0x0a66f, 0x0a672], // Combining Cyrillic Vzmet
  [0x0a674, 0x0a67d], // Combining Cyrillic Letter Ukrainian Ie
  [0x0a69e, 0x0a69f], // Combining Cyrillic Letter Ef
  [0x0a6f0, 0x0a6f1], // Bamum Combining Mark Koqndon
  [0x0a802, 0x0a802], // Syloti Nagri Sign Dvisvara
  [0x0a806, 0x0a806], // Syloti Nagri Sign Hasanta
  [0x0a80b, 0x0a80b], // Syloti Nagri Sign Anusvara
  [0x0a825, 0x0a826], // Syloti Nagri Vowel Sign U
  [0x0a82c, 0x0a82c], // Syloti Nagri Sign Alternate Hasanta
  [0x0a8c4, 0x0a8c5], // Saurashtra Sign Virama
  [0x0a8e0, 0x0a8f1], // Combining Devanagari Digit Zero
  [0x0a8ff, 0x0a8ff], // Devanagari Vowel Sign Ay
  [0x0a926, 0x0a92d], // Kayah Li Vowel Ue
  [0x0a947, 0x0a951], // Rejang Vowel Sign I
  [0x0a980, 0x0a982], // Javanese Sign Panyangga
  [0x0a9b3, 0x0a9b3], // Javanese Sign Cecak Telu
  [0x0a9b6, 0x0a9b9], // Javanese Vowel Sign Wulu
  [0x0a9bc, 0x0a9bd], // Javanese Vowel Sign Pepet
  [0x0a9e5, 0x0a9e5], // Myanmar Sign Shan Saw
  [0x0aa29, 0x0aa2e], // Cham Vowel Sign Aa
  [0x0aa31, 0x0aa32], // Cham Vowel Sign Au
  [0x0aa35, 0x0aa36], // Cham Consonant Sign La
  [0x0aa43, 0x0aa43], // Cham Consonant Sign Final Ng
  [0x0aa4c, 0x0aa4c], // Cham Consonant Sign Final M
  [0x0aa7c, 0x0aa7c], // Myanmar Sign Tai Laing Tone-2
  [0x0aab0, 0x0aab0], // Tai Viet Mai Kang
  [0x0aab2, 0x0aab4], // Tai Viet Vowel I
  [0x0aab7, 0x0aab8], // Tai Viet Mai Khit
  [0x0aabe, 0x0aabf], // Tai Viet Vowel Am
  [0x0aac1, 0x0aac1], // Tai Viet Tone Mai Tho
  [0x0aaec, 0x0aaed], // Meetei Mayek Vowel Sign Uu
  [0x0aaf6, 0x0aaf6], // Meetei Mayek Virama
  [0x0abe5, 0x0abe5], // Meetei Mayek Vowel Sign Anap
  [0x0abe8, 0x0abe8], // Meetei Mayek Vowel Sign Unap
  [0x0abed, 0x0abed], // Meetei Mayek Apun Iyek
  [0x0fb1e, 0x0fb1e], // Hebrew Point Judeo-spanish Varika
  [0x0fe00, 0x0fe0f], // Variation Selector-1
  [0x0fe20, 0x0fe2f], // Combining Ligature Left Half
  [0x101fd, 0x101fd], // Phaistos Disc Sign Combining Oblique Stroke
  [0x102e0, 0x102e0], // Coptic Epact Thousands Mark
  [0x10376, 0x1037a], // Combining Old Permic Letter An
  [0x10a01, 0x10a03], // Kharoshthi Vowel Sign I
  [0x10a05, 0x10a06], // Kharoshthi Vowel Sign E
  [0x10a0c, 0x10a0f], // Kharoshthi Vowel Length Mark
  [0x10a38, 0x10a3a], // Kharoshthi Sign Bar Above
  [0x10a3f, 0x10a3f], // Kharoshthi Virama
  [0x10ae5, 0x10ae6], // Manichaean Abbreviation Mark Above
  [0x10d24, 0x10d27], // Hanifi Rohingya Sign Harbahay
  [0x10eab, 0x10eac], // Yezidi Combining Hamza Mark
  [0x10efd, 0x10eff], // Arabic Small Low Word Sakta
  [0x10f46, 0x10f50], // Sogdian Combining Dot Below
  [0x10f82, 0x10f85], // Old Uyghur Combining Dot Above
  [0x11001, 0x11001], // Brahmi Sign Anusvara
  [0x11038, 0x11046], // Brahmi Vowel Sign Aa
  [0x11070, 0x11070], // Brahmi Sign Old Tamil Virama
  [0x11073, 0x11074], // Brahmi Vowel Sign Old Tamil Short E
  [0x1107f, 0x11081], // Brahmi Number Joiner
  [0x110b3, 0x110b6], // Kaithi Vowel Sign U
  [0x110b9, 0x110ba], // Kaithi Sign Virama
  [0x110c2, 0x110c2], // Kaithi Vowel Sign Vocalic R
  [0x11100, 0x11102], // Chakma Sign Candrabindu
  [0x11127, 0x1112b], // Chakma Vowel Sign A
  [0x1112d, 0x11134], // Chakma Vowel Sign Ai
  [0x11173, 0x11173], // Mahajani Sign Nukta
  [0x11180, 0x11181], // Sharada Sign Candrabindu
  [0x111b6, 0x111be], // Sharada Vowel Sign U
  [0x111c9, 0x111cc], // Sharada Sandhi Mark
  [0x111cf, 0x111cf], // Sharada Sign Inverted Candrabindu
  [0x1122f, 0x11231], // Khojki Vowel Sign U
  [0x11234, 0x11234], // Khojki Sign Anusvara
  [0x11236, 0x11237], // Khojki Sign Nukta
  [0x1123e, 0x1123e], // Khojki Sign Sukun
  [0x11241, 0x11241], // Khojki Vowel Sign Vocalic R
  [0x112df, 0x112df], // Khudawadi Sign Anusvara
  [0x112e3, 0x112ea], // Khudawadi Vowel Sign U
  [0x11300, 0x11301], // Grantha Sign Combining Anusvara Above
  [0x1133b, 0x1133c], // Combining Bindu Below
  [0x11340, 0x11340], // Grantha Vowel Sign Ii
  [0x11366, 0x1136c], // Combining Grantha Digit Zero
  [0x11370, 0x11374], // Combining Grantha Letter A
  [0x11438, 0x1143f], // Newa Vowel Sign U
  [0x11442, 0x11444], // Newa Sign Virama
  [0x11446, 0x11446], // Newa Sign Nukta
  [0x1145e, 0x1145e], // Newa Sandhi Mark
  [0x114b3, 0x114b8], // Tirhuta Vowel Sign U
  [0x114ba, 0x114ba], // Tirhuta Vowel Sign Short E
  [0x114bf, 0x114c0], // Tirhuta Sign Candrabindu
  [0x114c2, 0x114c3], // Tirhuta Sign Virama
  [0x115b2, 0x115b5], // Siddham Vowel Sign U
  [0x115bc, 0x115bd], // Siddham Sign Candrabindu
  [0x115bf, 0x115c0], // Siddham Sign Virama
  [0x115dc, 0x115dd], // Siddham Vowel Sign Alternate U
  [0x11633, 0x1163a], // Modi Vowel Sign U
  [0x1163d, 0x1163d], // Modi Sign Anusvara
  [0x1163f, 0x11640], // Modi Sign Virama
  [0x116ab, 0x116ab], // Takri Sign Anusvara
  [0x116ad, 0x116ad], // Takri Vowel Sign Aa
  [0x116b0, 0x116b5], // Takri Vowel Sign U
  [0x116b7, 0x116b7], // Takri Sign Nukta
  [0x1171d, 0x1171f], // Ahom Consonant Sign Medial La
  [0x11722, 0x11725], // Ahom Vowel Sign I
  [0x11727, 0x1172b], // Ahom Vowel Sign Aw
  [0x1182f, 0x11837], // Dogra Vowel Sign U
  [0x11839, 0x1183a], // Dogra Sign Virama
  [0x1193b, 0x1193c], // Dives Akuru Sign Anusvara
  [0x1193e, 0x1193e], // Dives Akuru Virama
  [0x11943, 0x11943], // Dives Akuru Sign Nukta
  [0x119d4, 0x119d7], // Nandinagari Vowel Sign U
  [0x119da, 0x119db], // Nandinagari Vowel Sign E
  [0x119e0, 0x119e0], // Nandinagari Sign Virama
  [0x11a01, 0x11a0a], // Zanabazar Square Vowel Sign I
  [0x11a33, 0x11a38], // Zanabazar Square Final Consonant Mark
  [0x11a3b, 0x11a3e], // Zanabazar Square Cluster-final Letter Ya
  [0x11a47, 0x11a47], // Zanabazar Square Subjoiner
  [0x11a51, 0x11a56], // Soyombo Vowel Sign I
  [0x11a59, 0x11a5b], // Soyombo Vowel Sign Vocalic R
  [0x11a8a, 0x11a96], // Soyombo Final Consonant Sign G
  [0x11a98, 0x11a99], // Soyombo Gemination Mark
  [0x11c30, 0x11c36], // Bhaiksuki Vowel Sign I
  [0x11c38, 0x11c3d], // Bhaiksuki Vowel Sign E
  [0x11c3f, 0x11c3f], // Bhaiksuki Sign Virama
  [0x11c92, 0x11ca7], // Marchen Subjoined Letter Ka
  [0x11caa, 0x11cb0], // Marchen Subjoined Letter Ra
  [0x11cb2, 0x11cb3], // Marchen Vowel Sign U
  [0x11cb5, 0x11cb6], // Marchen Sign Anusvara
  [0x11d31, 0x11d36], // Masaram Gondi Vowel Sign Aa
  [0x11d3a, 0x11d3a], // Masaram Gondi Vowel Sign E
  [0x11d3c, 0x11d3d], // Masaram Gondi Vowel Sign Ai
  [0x11d3f, 0x11d45], // Masaram Gondi Vowel Sign Au
  [0x11d47, 0x11d47], // Masaram Gondi Ra-kara
  [0x11d90, 0x11d91], // Gunjala Gondi Vowel Sign Ee
  [0x11d95, 0x11d95], // Gunjala Gondi Sign Anusvara
  [0x11d97, 0x11d97], // Gunjala Gondi Virama
  [0x11ef3, 0x11ef4], // Makasar Vowel Sign I
  [0x11f00, 0x11f01], // Kawi Sign Candrabindu
  [0x11f36, 0x11f3a], // Kawi Vowel Sign I
  [0x11f40, 0x11f40], // Kawi Vowel Sign Eu
  [0x11f42, 0x11f42], // Kawi Conjoiner
  [0x13440, 0x13440], // Egyptian Hieroglyph Mirror Horizontally
  [0x13447, 0x13455], // Egyptian Hieroglyph Modifier Damaged At Top Start
  [0x16af0, 0x16af4], // Bassa Vah Combining High Tone
  [0x16b30, 0x16b36], // Pahawh Hmong Mark Cim Tub
  [0x16f4f, 0x16f4f], // Miao Sign Consonant Modifier Bar
  [0x16f8f, 0x16f92], // Miao Tone Right
  [0x16fe4, 0x16fe4], // Khitan Small Script Filler
  [0x1bc9d, 0x1bc9e], // Duployan Thick Letter Selector
  [0x1cf00, 0x1cf2d], // Znamenny Combining Mark Gorazdo Nizko S Kryzhem On Left
  [0x1cf30, 0x1cf46], // Znamenny Combining Tonal Range Mark Mrachno
  [0x1d167, 0x1d169], // Musical Symbol Combining Tremolo-1
  [0x1d17b, 0x1d182], // Musical Symbol Combining Accent
  [0x1d185, 0x1d18b], // Musical Symbol Combining Doit
  [0x1d1aa, 0x1d1ad], // Musical Symbol Combining Down Bow
  [0x1d242, 0x1d244], // Combining Greek Musical Triseme
  [0x1da00, 0x1da36], // Signwriting Head Rim
  [0x1da3b, 0x1da6c], // Signwriting Mouth Closed Neutral
  [0x1da75, 0x1da75], // Signwriting Upper Body Tilting From Hip Joints
  [0x1da84, 0x1da84], // Signwriting Location Head Neck
  [0x1da9b, 0x1da9f], // Signwriting Fill Modifier-2
  [0x1daa1, 0x1daaf], // Signwriting Rotation Modifier-2
  [0x1e000, 0x1e006], // Combining Glagolitic Letter Azu
  [0x1e008, 0x1e018], // Combining Glagolitic Letter Zemlja
  [0x1e01b, 0x1e021], // Combining Glagolitic Letter Shta
  [0x1e023, 0x1e024], // Combining Glagolitic Letter Yu
  [0x1e026, 0x1e02a], // Combining Glagolitic Letter Yo
  [0x1e08f, 0x1e08f], // Combining Cyrillic Small Letter Byelorussian-ukrainian I
  [0x1e130, 0x1e136], // Nyiakeng Puachue Hmong Tone-b
  [0x1e2ae, 0x1e2ae], // Toto Sign Rising Tone
  [0x1e2ec, 0x1e2ef], // Wancho Tone Tup
  [0x1e4ec, 0x1e4ef], // Nag Mundari Sign Muhor
  [0x1e8d0, 0x1e8d6], // Mende Kikakui Combining Number Teens
  [0x1e944, 0x1e94a], // Adlam Alif Lengthener
  [0xe0100, 0xe01ef], // Variation Selector-17
];

/// 宽字符表 - 从 Termux WcWidth.java 复制
const List<List<int>> _wideEastAsian = [
  [0x01100, 0x0115f], // Hangul Choseong Kiyeok
  [0x0231a, 0x0231b], // Watch..Hourglass
  [0x02329, 0x0232a], // Left-pointing Angle Bracket
  [0x023e9, 0x023ec], // Black Right-pointing Double Triangle
  [0x023f0, 0x023f0], // Alarm Clock
  [0x023f3, 0x023f3], // Hourglass With Flowing Sand
  [0x025fd, 0x025fe], // White Medium Small Square
  [0x02614, 0x02615], // Umbrella With Rain Drops
  [0x02648, 0x02653], // Aries
  [0x0267f, 0x0267f], // Wheelchair Symbol
  [0x02693, 0x02693], // Anchor
  [0x026a1, 0x026a1], // High Voltage Sign
  [0x026aa, 0x026ab], // Medium White Circle
  [0x026bd, 0x026be], // Soccer Ball
  [0x026c4, 0x026c5], // Snowman Without Snow
  [0x026ce, 0x026ce], // Ophiuchus
  [0x026d4, 0x026d4], // No Entry
  [0x026ea, 0x026ea], // Church
  [0x026f2, 0x026f3], // Fountain
  [0x026f5, 0x026f5], // Sailboat
  [0x026fa, 0x026fa], // Tent
  [0x026fd, 0x026fd], // Fuel Pump
  [0x02705, 0x02705], // White Heavy Check Mark
  [0x0270a, 0x0270b], // Raised Fist
  [0x02728, 0x02728], // Sparkles
  [0x0274c, 0x0274c], // Cross Mark
  [0x0274e, 0x0274e], // Negative Squared Cross Mark
  [0x02753, 0x02755], // Black Question Mark Ornament
  [0x02757, 0x02757], // Heavy Exclamation Mark Symbol
  [0x02795, 0x02797], // Heavy Plus Sign
  [0x027b0, 0x027b0], // Curly Loop
  [0x027bf, 0x027bf], // Double Curly Loop
  [0x02b1b, 0x02b1c], // Black Large Square
  [0x02b50, 0x02b50], // White Medium Star
  [0x02b55, 0x02b55], // Heavy Large Circle
  [0x02e80, 0x02e99], // Cjk Radical Repeat
  [0x02e9b, 0x02ef3], // Cjk Radical Choke
  [0x02f00, 0x02fd5], // Kangxi Radical One
  [0x02ff0, 0x02ffb], // Ideographic Description Character Left To Right
  [0x03000, 0x0303e], // Ideographic Space
  [0x03041, 0x03096], // Hiragana Letter Small A
  [0x03099, 0x030ff], // Combining Katakana-hiragana Voiced Sound Mark
  [0x03105, 0x0312f], // Bopomofo Letter B
  [0x03131, 0x0318e], // Hangul Letter Kiyeok
  [0x03190, 0x031e3], // Ideographic Annotation Linking Mark
  [0x031f0, 0x0321e], // Katakana Letter Small Ku
  [0x03220, 0x03247], // Parenthesized Ideograph One
  [0x03250, 0x04dbf], // Partnership Sign
  [0x04e00, 0x0a48c], // Cjk Unified Ideograph-4e00
  [0x0a490, 0x0a4c6], // Yi Radical Qot
  [0x0a960, 0x0a97c], // Hangul Choseong Tikeut-mieum
  [0x0ac00, 0x0d7a3], // Hangul Syllable Ga
  [0x0f900, 0x0faff], // Cjk Compatibility Ideograph-f900
  [0x0fe10, 0x0fe19], // Presentation Form For Vertical Comma
  [0x0fe30, 0x0fe52], // Presentation Form For Vertical Two Dot Leader
  [0x0fe54, 0x0fe66], // Small Semicolon
  [0x0fe68, 0x0fe6b], // Small Reverse Solidus
  [0x0ff01, 0x0ff60], // Fullwidth Exclamation Mark
  [0x0ffe0, 0x0ffe6], // Fullwidth Cent Sign
  [0x16fe0, 0x16fe4], // Tangut Iteration Mark
  [0x16ff0, 0x16ff1], // Vietnamese Alternate Reading Mark Ca
  [0x17000, 0x187f7], // Tangut Ideograph
  [0x18800, 0x18cd5], // Tangut Component-001
  [0x18d00, 0x18d08], // Tangut Ideograph
  [0x1aff0, 0x1aff3], // Katakana Letter Minnan Tone-2
  [0x1aff5, 0x1affb], // Katakana Letter Minnan Tone-7
  [0x1affd, 0x1affe], // Katakana Letter Minnan Nasalized Tone-7
  [0x1b000, 0x1b122], // Katakana Letter Archaic E
  [0x1b132, 0x1b132], // Hiragana Letter Small Ko
  [0x1b150, 0x1b152], // Hiragana Letter Small Wi
  [0x1b155, 0x1b155], // Katakana Letter Small Ko
  [0x1b164, 0x1b167], // Katakana Letter Small Wi
  [0x1b170, 0x1b2fb], // Nushu Character-1b170
  [0x1f004, 0x1f004], // Mahjong Tile Red Dragon
  [0x1f0cf, 0x1f0cf], // Playing Card Black Joker
  [0x1f18e, 0x1f18e], // Negative Squared Ab
  [0x1f191, 0x1f19a], // Squared Cl
  [0x1f200, 0x1f202], // Square Hiragana Hoka
  [0x1f210, 0x1f23b], // Squared Cjk Unified Ideograph-624b
  [0x1f240, 0x1f248], // Tortoise Shell Bracketed Cjk Unified Ideograph-672c
  [0x1f250, 0x1f251], // Circled Ideograph Advantage
  [0x1f260, 0x1f265], // Rounded Symbol For Fu
  [0x1f300, 0x1f320], // Cyclone
  [0x1f32d, 0x1f335], // Hot Dog
  [0x1f337, 0x1f37c], // Tulip
  [0x1f37e, 0x1f393], // Bottle With Popping Cork
  [0x1f3a0, 0x1f3ca], // Carousel Horse
  [0x1f3cf, 0x1f3d3], // Cricket Bat And Ball
  [0x1f3e0, 0x1f3f0], // House Building
  [0x1f3f4, 0x1f3f4], // Waving Black Flag
  [0x1f3f8, 0x1f43e], // Badminton Racquet And Shuttlecock
  [0x1f440, 0x1f440], // Eyes
  [0x1f442, 0x1f4fc], // Ear
  [0x1f4ff, 0x1f53d], // Prayer Beads
  [0x1f54b, 0x1f54e], // Kaaba
  [0x1f550, 0x1f567], // Clock Face One Oclock
  [0x1f57a, 0x1f57a], // Man Dancing
  [0x1f595, 0x1f596], // Reversed Hand With Middle Finger Extended
  [0x1f5a4, 0x1f5a4], // Black Heart
  [0x1f5fb, 0x1f64f], // Mount Fuji
  [0x1f680, 0x1f6c5], // Rocket
  [0x1f6cc, 0x1f6cc], // Sleeping Accommodation
  [0x1f6d0, 0x1f6d2], // Place Of Worship
  [0x1f6d5, 0x1f6d7], // Hindu Temple
  [0x1f6dc, 0x1f6df], // Wireless
  [0x1f6eb, 0x1f6ec], // Airplane Departure
  [0x1f6f4, 0x1f6fc], // Scooter
  [0x1f7e0, 0x1f7eb], // Large Orange Circle
  [0x1f7f0, 0x1f7f0], // Heavy Equals Sign
  [0x1f90c, 0x1f93a], // Pinched Fingers
  [0x1f93c, 0x1f945], // Wrestlers
  [0x1f947, 0x1f9ff], // First Place Medal
  [0x1fa70, 0x1fa7c], // Ballet Shoes
  [0x1fa80, 0x1fa88], // Yo-yo
  [0x1fa90, 0x1fabd], // Ringed Planet
  [0x1fabf, 0x1fac5], // Wing
  [0x1face, 0x1fadb], // Moose
  [0x1fae0, 0x1fae8], // Melting Face
  [0x1faf0, 0x1faf8], // Hand With Index Finger And Thumb Crossed
  [0x20000, 0x2fffd], // Cjk Unified Ideograph-20000
  [0x30000, 0x3fffd], // Cjk Unified Ideograph-30000
];

/// 二分查找
bool _inTable(List<List<int>> table, int c) {
  if (c < table[0][0]) return false;

  int bot = 0;
  int top = table.length - 1;
  while (top >= bot) {
    int mid = (bot + top) ~/ 2;
    if (table[mid][1] < c) {
      bot = mid + 1;
    } else if (table[mid][0] > c) {
      top = mid - 1;
    } else {
      return true;
    }
  }
  return false;
}

/// 计算字符的终端显示宽度: 0, 1 或 2
///
/// 与 Termux 的 WcWidth.java 保持一致
int termuxWcwidth(int ucs) {
  // 特殊零宽字符
  if (ucs == 0 ||
      ucs == 0x034F ||
      (0x200B <= ucs && ucs <= 0x200F) ||
      ucs == 0x2028 ||
      ucs == 0x2029 ||
      (0x202A <= ucs && ucs <= 0x202E) ||
      (0x2060 <= ucs && ucs <= 0x2063)) {
    return 0;
  }

  // C0/C1 控制字符 - Termux 返回 0
  if (ucs < 32 || (0x07F <= ucs && ucs < 0x0A0)) return 0;

  // 组合字符 - 宽度 0
  if (_inTable(_zeroWidth, ucs)) return 0;

  // 东亚宽字符 - 宽度 2，否则宽度 1
  return _inTable(_wideEastAsian, ucs) ? 2 : 1;
}
