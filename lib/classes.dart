import 'dart:convert';
import 'dart:typed_data';

import 'package:localpkg/functions.dart';

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

/// Different types of numbers, with their respective IDs.
///
/// If you are planning on adding to this, *do not* edit current numbers' IDs, as this can break existing implentations.
enum DynamicNumberMode {
  /// Signed 8-bit integer.
  int8(0, 0, 8),
  /// Signed 16-bit integer.
  int16(0, 1, 16),
  /// Signed 24-bit integer.
  int24(0, 2, 24),
  /// Signed 32-bit integer.
  int32(0, 3, 32),
  /// Signed 64-bit integer.
  int64(0, 4, 64),

  /// Unsigned 8-bit integer.
  uint8(1, 5, 8),
  /// Unsigned 16-bit integer.
  uint16(1, 6, 16),
  /// Unsigned 24-bit integer.
  uint24(1, 7, 24),
  /// Unsigned 32-bit integer.
  uint32(1, 8, 32),
  /// Unsigned 64-bit integer.
  uint64(1, 9, 64),

  /// 32-bit floating point number.
  float32(2, 10, 32),
  /// 64-bit floating point number.
  float64(2, 11, 64);

  /// The type, or category, of a mode. This is used to filter certain modes.
  final int type;

  /// The identifier of a mode. This is actually used in the binary implementation.
  final int id;

  /// How many bits a mode's number will use.
  final int bits;

  const DynamicNumberMode(this.type, this.id, this.bits);

  /// How many bytes a mode's number will use.
  int get bytes => (bits / 8).ceil();
}

/// This class aims at providing a good way to store numbers in binary, while using the smallest amount of bytes possible.
class DynamicNumber {
  /// The mode of this [DynamicNumber].
  final DynamicNumberMode mode;

  /// The actual numeric value of this [DynamicNumber].
  final num value;

  /// The raw byte data of this [DynamicNumber], including the signature.
  final Uint8List data;

  const DynamicNumber._(this.mode, this.value, this.data);

  /// How many bytes this [DynamicNumber] will use, excluding signature. Add one to include the signature.
  int get bytes => mode.bytes;

  /// The signature byte.
  int get signature => data.first;

  /// Parse the signature from a byte.
  static DynamicNumberMode parseSignature(int byte) {
    int id = byte;
    DynamicNumberMode mode = DynamicNumberMode.values.firstWhere((x) => x.id == id);
    return mode;
  }

  /// Get the length of an entire [DynamicNumber] just from its signature. This does not include the signature.
  static int getLength(int signature) {
    return parseSignature(signature).bytes;
  }

  /// Get the signature of a [DynamicNumber] from a [num].
  static (ByteData data, DynamicNumberMode mode) getSignature(num number) {
    List<DynamicNumberMode> getModes(int type) {
      return DynamicNumberMode.values.where((x) => x.type == type).toList()..sort((a, b) => a.bits.compareTo(b.bits));
    }

    DynamicNumberMode getMode(int type, int bits) {
      return getModes(type).firstWhere((x) => x.bits >= bits, orElse: () => throw RangeError('No matching mode for type $type for $bits bits.'));
    }

    int getFractionBits(double x, {int maxPrecision = 52}) {
      const double epsilon = 1e-15;
      double fraction = x.abs() - x.abs().floor();
      if (fraction == 0) return 0;

      int bits = 0;
      double power = 0.5;

      while (fraction > epsilon && bits < maxPrecision) {
        if (fraction >= power) {
          fraction -= power;
        }

        bits++;
        power /= 2;
      }

      return bits;
    }

    if (number is int) {
      int bits = number == 0 ? 1 : number.bitLength + (number < 0 ? 1 : 0);
      DynamicNumberMode mode = getMode(number < 0 ? 0 : 1, bits);
      return (ByteData(1)..setUint8(0, mode.id), mode);
    } else if (number is double) {
      int intBits = number.abs().floor().bitLength;
      int bits = intBits + getFractionBits(number) + 1;
      DynamicNumberMode mode = getMode(2, bits);
      return (ByteData(1)..setUint8(0, mode.id), mode);
    } else {
      throw UnimplementedError("Invalid number type: ${number.runtimeType}");
    }
  }

  /// Get the full [DynamicNumber] from a list of bytes. This list of bytes does not need to be exactly the same length as the [DynamicNumber] data.
  static DynamicNumber fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) throw ArgumentError("Too few bytes: Need > 0");
    int signature = bytes.first;
    var mode = parseSignature(signature);
    int length = mode.bytes;
    if (bytes.length < length + 1) throw ArgumentError("Too few bytes: Need > $length + 1");

    Uint8List content = bytes.sublist(1, length + 1);
    late num result;

    switch (mode) {
      case DynamicNumberMode.int8: result = content.toInt8(); break;
      case DynamicNumberMode.int16: result = content.toInt16(); break;
      case DynamicNumberMode.int24: result = content.toInt24(); break;
      case DynamicNumberMode.int32: result = content.toInt32(); break;
      case DynamicNumberMode.int64: result = content.toInt64(); break;
      case DynamicNumberMode.uint8: result = content.toUint8(); break;
      case DynamicNumberMode.uint16: result = content.toUint16(); break;
      case DynamicNumberMode.uint24: result = content.toUint24(); break;
      case DynamicNumberMode.uint32: result = content.toUint32(); break;
      case DynamicNumberMode.uint64: result = content.toUint64(); break;
      case DynamicNumberMode.float32: result = content.toFloat32(); break;
      case DynamicNumberMode.float64: result = content.toFloat64(); break;
    }

    return DynamicNumber._(mode, result, bytes.sublist(0, length + 1));
  }

  /// Convert a [num] to a [DynamicNumber].
  static DynamicNumber fromNumber(num number) {
    var signature = getSignature(number);
    Uint8List data = Uint8List(signature.$2.bytes + 1);
    data.first = signature.$1.toUint8List().first;
    ByteData binary = ByteData(signature.$2.bytes);

    switch (signature.$2) {
      case DynamicNumberMode.int8: binary.setInt8(0, number as int); break;
      case DynamicNumberMode.int16: binary.setInt16(0, number as int); break;
      case DynamicNumberMode.int24: binary.setInt24(0, number as int); break;
      case DynamicNumberMode.int32: binary.setInt32(0, number as int); break;
      case DynamicNumberMode.int64: binary.setInt64Safe(0, number as int); break;
      case DynamicNumberMode.uint8: binary.setUint8(0, number as int); break;
      case DynamicNumberMode.uint16: binary.setUint16(0, number as int); break;
      case DynamicNumberMode.uint24: binary.setUint24(0, number as int); break;
      case DynamicNumberMode.uint32: binary.setUint32(0, number as int); break;
      case DynamicNumberMode.uint64: binary.setUint64Safe(0, number as int); break;
      case DynamicNumberMode.float32: binary.setFloat32(0, number as double); break;
      case DynamicNumberMode.float64: binary.setFloat64(0, number as double); break;
    }

    data.setRange(1, data.length, binary.toUint8List());
    return DynamicNumber._(signature.$2, number, data);
  }
}