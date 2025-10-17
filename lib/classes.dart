import 'dart:convert';
import 'dart:typed_data';

/// Manages versions and version parsing.
class Version implements Comparable<Version> {
  /// `a` in `a.b.c`.
  final int major;

  /// `b` in `a.b.c`.
  final int intermediate;

  /// `c` in `a.b.c`.
  final int minor;

  /// Letter identifier (`A` in `1.0.0A`), in range 0-25 inclusive.
  final int patch;

  /// Optional revision (`1` in `1.0.0A-R1`).
  final int release;

  // If this version represents a beta version.
  final bool _isBeta;

  /// [major], [intermediate], and [minor] are required. [letter] and [release] have defaults.
  /// 
  /// [isBeta] signifies if the current release is beta or not. If this is not provided, then [isBeta] will automatically be true if [major] is less than 1.
  Version(this.major, this.intermediate, this.minor, [String letter = "A", this.release = 0]) : patch = _letterToPatch(letter), _isBeta = _doesQualifyForBeta(major, intermediate, minor, _letterToPatch(letter), release), assert(release >= 0, "Release cannot be negative.");

  /// All five parameters are required integers.
  Version.raw(this.major, this.intermediate, this.minor, this.patch, this.release) : _isBeta = _doesQualifyForBeta(major, intermediate, minor, patch, release);

  /// Returns a [Version] from the provided `Map<String, dynamic>`.
  /// 
  /// This will throw an [ArgumentError] if one of the required properties was not present.
  static Version fromJson(Map<String, dynamic> input) {
    for ((String name, Type type) property in [
      ("major", int),
      ("intermediate", int),
      ("minor", int),
      ("patch", int),
      ("release", int),
    ]) {
      if (input[property.$1].runtimeType != property.$2) {
        throw ArgumentError("Property '${property.$1}' was invalid type ${input[property.$1].runtimeType}, expected ${property.$2}.", property.$1);
      }
    }

    int major = input["major"];
    int intermediate = input["intermediate"];
    int minor = input["minor"];
    int patch = input["patch"];
    int release = input["release"];

    return Version.raw(major, intermediate, minor, patch, release);
  }

  @override
  int compareTo(Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (intermediate != other.intermediate) return intermediate.compareTo(other.intermediate);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    return release.compareTo(other.release);
  }

  @override
  int get hashCode => major.hashCode ^ intermediate.hashCode ^ minor.hashCode ^ patch.hashCode ^ release.hashCode;

  /// Returns true if this [Version] object signifies a beta version.
  bool get isBeta => _isBeta;

  String get _patchToLetter => String.fromCharCode(patch + 'A'.codeUnitAt(0));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Version &&
      major == other.major &&
      intermediate == other.intermediate &&
      minor == other.minor &&
      patch == other.patch &&
      release == other.release;
  }

  /// This [Version] is greater than the other [Version].
  bool operator >(Version other) => compareTo(other) > 0;

  /// This [Version] is lesser than the other [Version].
  bool operator <(Version other) => compareTo(other) < 0;

  /// This [Version] is greater than or equal to the other [Version].
  bool operator >=(Version other) => compareTo(other) >= 0;

  /// This [Version] is lesser than or equal to the other [Version].
  bool operator <=(Version other) => compareTo(other) <= 0;

  /// Returns the raw version string. [release] is only included if it is non-zero.
  @override
  String toString() {
    final core = '$major.$intermediate.$minor$_patchToLetter';
    return release > 0 ? '$core-R$release' : core;
  }

  /// Convert this [Version] object to a `Map<String, Object>`.
  Map<String, Object> toJson() {
    return {
      "raw": toString(),
      "major": major,
      "intermediate": intermediate,
      "minor": minor,
      "patch": patch,
      "release": release,
    };
  }

  /// Turn this [Version] object into a small [Uint8List].
  /// 
  /// Note that the bytes are signed 16-bit integers.
  Uint8List toBinary() {
    ByteData data = ByteData(10);
    for (int i = 0; i < 5; i++) data.setInt16(i * 2, [major, intermediate, minor, patch, release][i], Endian.little);
    return data.buffer.asUint8List();
  }

  /// Attempt to parse the version string. Possible values include:
  /// 
  /// - `0.0.0A`
  /// - `2.14.5G-R2`
  /// - `23.0.1`
  static Version? tryParse(String input) {
    RegExp regex = RegExp(r'^(\d+)\.(\d+)\.(\d+)([A-Z])?(?:-R(\d+))?$');
    RegExpMatch? match = regex.firstMatch(input);
    if (match == null) return null;

    List<int> chars = match.groups([1, 2, 3]).map((x) => int.parse(x!)).toList();
    String letter = match.group(4) ?? "A";
    int release = int.tryParse(match.group(5) ?? "") ?? 0;
    return Version(chars[0], chars[1], chars[2], letter, release);
  }

  /// Same as [tryParse], but throws an exception if it can't be parsed.
  static Version parse(String input) {
    Version? result = tryParse(input);
    if (result == null) throw ArgumentError("Version could not be parsed: $input");
    return result;
  }

  /// Try to parse a [Version] object from a list of bytes. Returns null on exception.
  static Version? tryParseBinary(Uint8List input) {
    try {
      return parseBinary(input);
    } catch (e) {
      return null;
    }
  }

  /// Parse a [Version] object from a list of bytes. Any exceptions thrown are uncaught.
  /// 
  /// Note that the binary is parsed as signed 16-bit integers.
  static Version parseBinary(Uint8List input) {
    ByteData data = input.buffer.asByteData();

    int a = data.getInt16(0, Endian.little);
    int b = data.getInt16(2, Endian.little);
    int c = data.getInt16(4, Endian.little);
    int d = data.getInt16(6, Endian.little);
    int e = data.getInt16(8, Endian.little);

    return Version.raw(a, b, c, d, e);
  }

  static bool _doesQualifyForBeta(int major, int intermediate, int minor, int patch, int release) {
    return major < 1 || release != 0;
  }

  static int _letterToPatch(String letter) {
    int result = letter.toUpperCase().codeUnitAt(0) - 'A'.codeUnitAt(0);
    if (result < 0 || result > 25) throw ArgumentError("Invalid letter for patch: $letter");
    return result;
  }
}

/// A class that represents singular characters.
class Char implements Comparable<Char> {
  final int _character;

  /// From raw character code.
  Char(int character) : _character = character;

  /// From raw [String] to character code.
  Char.from(String character) : _character = character.codeUnitAt(0);

  /// Character as string.
  String get string => String.fromCharCode(code);

  /// Character code.
  int get code => _character;

  @override
  String toString() {
    return "Char($code, $string)";
  }

  @override
  int compareTo(Char other) {
    return code.compareTo(other.code);
  }

  @override
  int get hashCode => code.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Char) return false;
    return other.code == code;
  }

  /// This [Char] is greater than the other [Char].
  bool operator >(Char other) => compareTo(other) > 0;

  /// This [Char] is lesser than the other [Char].
  bool operator <(Char other) => compareTo(other) < 0;

  /// This [Char] is greater than or equal to the other [Char].
  bool operator >=(Char other) => compareTo(other) >= 0;

  /// This [Char] is lesser than or equal to the other [Char].
  bool operator <=(Char other) => compareTo(other) <= 0;
}

/// A class to manage words 
class Word implements Comparable<Word> {
  final List<Char> _chars;

  /// Get [Word] from [String].
  Word(String string) : _chars = string.split("").map((x) => Char.from(x)).toList();

  /// Get [Word] from a list of [Char]s.
  Word.fromChars(List<Char> chars) : _chars = chars;

  /// Get [Word] from a list of UTF8 bytes, ignoring nulls.
  Word.fromBytes(List<int> bytes) : _chars = utf8.decode(bytes.where((x) => x > 0).toList()).split('').map((x) => Char.from(x)).toList();

  /// Get the characters of the word.
  List<Char> get chars => _chars;

  /// Get the string from the characters.
  String get word => _chars.map((x) => x.string).join("");

  /// Get the length of the characters.
  int get length => _chars.length;

  @override
  String toString() {
    return word;
  }

  @override
  int compareTo(Word other) => word.compareTo(other.word);

  /// This [Word] is greater than the other [Word].
  bool operator >(Word other) => compareTo(other) > 0;

  /// This [Word] is less than the other [Word].
  bool operator <(Word other) => compareTo(other) < 0;

  /// This [Word] is greater than or equal to the other [Word].
  bool operator >=(Word other) => compareTo(other) >= 0;

  /// This [Word] is less than or equal to the other [Word].
  bool operator <=(Word other) => compareTo(other) <= 0;

  /// Combine the two words.
  Word operator +(Word other) => Word.fromChars([..._chars, ...other._chars]);

  /// Choose a word based on the inputted count.
  static Word fromCount(num count, {required Word singular, Word? plural}) {
    plural ??= Word("${singular.word}s");
    return count == 1 || count == 1.0 ? singular : plural;
  }
}