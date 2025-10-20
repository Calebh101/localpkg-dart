import 'dart:async';
import 'dart:typed_data';

import 'package:localpkg/src/platform_detect.dart';

/// Mode used to format time in [TimeFormatter].
enum FormatTimeMode {
  /// `hh:mm:ss`
  hhmmss,

  /// `hh:mm`
  hhmm,

  /// `mm:ss`
  mmss,
}

/// Mode used to format duration in [TimeFormatter].
enum FormatDurationMode {
  /// Hour will always be present.
  hourRequired,

  /// Hour might not be present.
  hourOptional,
}

/// Formats times, dates, and durations.
class TimeFormatter {
  /// Formats a [DateTime].
  static String formatTime(DateTime time, {
    FormatTimeMode output = FormatTimeMode.hhmm,
    bool army = false,
  }) {
    int hour = time.hour;
    int minute = time.minute;
    int second = time.second;
    int roundedHour = hour;

    if (army == false) {
      if (hour == 0) roundedHour = 12;
      if (hour > 12) roundedHour = hour - 12;
    }

    String formatted = "$roundedHour:${minute.toString().padLeft(2, '0')}${output == FormatTimeMode.hhmmss || output == FormatTimeMode.mmss ? (":${second.toString().padLeft(2, '0')}"): ""}${!army ? (" ${hour >= 12 ? "PM" : "AM"}") : ""}";
    return formatted;
  }

  /// Formats a [Duration].
  static String formatDuration(Duration duration, {FormatDurationMode mode = FormatDurationMode.hourRequired}) {
    int ms = duration.inMilliseconds;
    int hours = (ms ~/ 3600000);
    int minutes = (ms % 3600000) ~/ 60000;
    int seconds = (ms % 60000) ~/ 1000;
    int remainingms = ms % 1000;

    if (mode == FormatDurationMode.hourRequired) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${remainingms.toString().padLeft(3, '0')}';
    } else if (mode == FormatDurationMode.hourOptional) {
      return '${hours > 0 ? "${hours.toString().padLeft(2, '0')}:" : ""}${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${remainingms.toString().padLeft(3, '0')}';
    } else {
      throw Exception("Invalid mode: $mode");
    }
  }
}

/// Extension for manipulating numbers.
extension NumberManager on num {
  /// Gets if the number is a whole number.
  bool isWhole() => this % 1 == 0;

  /// Returns a clean number. If this is a double but is a whole number, it is converted to an integer.
  String clean() {
    if (this is double && isWhole()) {
      return "${toInt()}";
    } else {
      return "$this";
    }
  }
}

/// Manages opening and manipulating URLs.
class UrlManager {
  /// Adds a prefix like `protocol://`.
  static String addHttpPrefix(String url, {String defaultPrefix = "http"}) {
    if (!url.startsWith('http://') && !url.startsWith('https://') && !url.startsWith('ws://') && !url.startsWith('wss://')) return '$defaultPrefix://$url';
    return url;
  }

  /// Removes `http://` and `https://`, and optionally WebSocket and other protocols.
  static String removeHttpPrefix(String url, {bool removeWebsocket = true, List<String> otherProtocols = const []}) {
    List<String> protocols = ["http", "https", if (removeWebsocket) ...["ws", "wss"], ...otherProtocols];
    for (String protocol in protocols) url = url.replaceFirst("$protocol://", "");
    return url;
  }
}

/// Manages capitalizations.
extension CaseManager on String {
  /// Capitalizes the first character of the string.
  String toSentenceCase() {
    if (isEmpty) return this;
    return [this[0].toUpperCase(), substring(1)].join("");
  }

  /// Capitalizes the first letter of every word.
  String toTitleCase() {
    return capitalizeByDelim(this, " ");
  }

  /// Capitalizes the first letter of every word, based on a delimiter ([delim]).
  static String capitalizeByDelim(String input, Pattern delim) {
    if (input.isEmpty) return input;

    return input.split(delim).map((x) => x.trim()).map((word) => word.isNotEmpty
      ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
      : word).join(' ');
  }
}

/// Extension to format [StackTrace]s.
extension StackTraceFormatter on StackTrace {
  static String _format(String input, {int? end}) {
    end ??= 16;
    assert(end > 0, "end must be greater than 0.");
    List<String> lines = input.split("\n");
    bool expands = false;
    if (lines.length > end) expands = true;
    if (lines.length < end) end = lines.length;
    return [...lines.sublist(0, end), if (expands) "And ${lines.length - end} more..."].join("\n");
  }

  /// Formats [StackTrace]s
  String format({int? end}) {
    return _format(toString(), end: end);
  }
}

/// Extension to parse integers from raw bytes.
extension IntParser on List<int> {
  /// Default endianness for parsing.
  static const Endian defaultEndian = Endian.big;

  /// Contains instance of byte data.
  ByteData get _byteData => ByteData.sublistView(Uint8List(length)..setAll(0, this));

  /// To unsigned 8-bit integer.
  int toUint8() {
    return _byteData.getUint8(0);
  }

  /// To unsigned 16-bit integer.
  int toUint16([Endian endianness = defaultEndian]) {
    return _byteData.getUint16(0, endianness);
  }

  /// To unsigned 24-bit integer.
  int toUint24([Endian endianness = defaultEndian]) {
    if (endianness == Endian.big) {
      return (this[0] << 16) | (this[1] << 8) | this[2];
    } else {
      return (this[2] << 16) | (this[1] << 8) | this[0];
    }
  }

  /// To unsigned 32-bit integer.
  int toUint32([Endian endianness = defaultEndian]) {
    return _byteData.getUint32(0, endianness);
  }

  /// To unsigned 64-bit integer.
  int toUint64([Endian endianness = defaultEndian]) {
    if (!isWeb) return _byteData.getUint64(0, endianness);

    int low = _byteData.getUint32(0, endianness);
    int high = _byteData.getUint32(4, endianness);
    return endianness == Endian.little ? (high << 32) | low : ((low << 32) | high);
  }

  /// To signed 8-bit integer.
  int toInt8() {
    return _byteData.getInt8(0);
  }

  /// To signed 16-bit integer.
  int toInt16([Endian endianness = defaultEndian]) {
    return _byteData.getInt16(0, endianness);
  }

  /// To signed 24-bit integer.
  int toInt24([Endian endianness = defaultEndian]) {
    int value;

    if (endianness == Endian.big) {
      value = (this[0] << 16) | (this[1] << 8) | this[2];
    } else {
      value = (this[2] << 16) | (this[1] << 8) | this[0];
    }

    if (value & 0x800000 != 0) {
      value |= ~0xFFFFFF;
    }

    return value;
  }

  /// To signed 32-bit integer.
  int toInt32([Endian endianness = defaultEndian]) {
    return _byteData.getInt32(0, endianness);
  }

  /// To signed 64-bit integer.
  int toInt64([Endian endianness = defaultEndian]) {
    if (!isWeb) return _byteData.getInt64(0, endianness);

    int low = _byteData.getUint32(0, endianness);
    int high = _byteData.getInt32(4, endianness);
    return endianness == Endian.little ? (high << 32) | low : ((low << 32) | high);
  }

  /// To 32-bit floating-point number.
  double toFloat32([Endian endianness = defaultEndian]) {
    return _byteData.getFloat32(0, endianness);
  }

  /// To 64-bit floating-point number.
  double toFloat64([Endian endianness = defaultEndian]) {
    return _byteData.getFloat64(0, endianness);
  }
}

/// Some extra addons on [ByteData] objects.
extension ByteDataExtensions on ByteData {
  /// Return the buffer as a [Uint8List].
  Uint8List toUint8List() {
    return buffer.asUint8List();
  }

  /// Sets the four bytes starting at the specified [byteOffset] in this object
  /// to the unsigned binary representation of the specified [value],
  /// which must fit in three bytes.
  ///
  /// In other words, [value] must be between
  /// 0 and 2<sup>24</sup> - 1, inclusive.
  ///
  /// The [byteOffset] must be non-negative, and
  /// `byteOffset + 3` must be less than or equal to the length of this object.
  void setUint24(int byteOffset, int value, [Endian endian = Endian.big]) {
    if (value < 0 || value > 0xFFFFFF) {
      throw RangeError.range(value, 0, 0xFFFFFF, 'value');
    }

    if (endian == Endian.big) {
      setUint8(byteOffset, (value >> 16) & 0xFF);
      setUint8(byteOffset + 1, (value >> 8) & 0xFF);
      setUint8(byteOffset + 2, value & 0xFF);
    } else {
      setUint8(byteOffset, value & 0xFF);
      setUint8(byteOffset + 1, (value >> 8) & 0xFF);
      setUint8(byteOffset + 2, (value >> 16) & 0xFF);
    }
  }

  /// Sets the four bytes starting at the specified [byteOffset] in this
  /// object to the two's complement binary representation of the specified
  /// [value], which must fit in three bytes.
  ///
  /// In other words, [value] must lie
  /// between -2<sup>23</sup> and 2<sup>23</sup> - 1, inclusive.
  ///
  /// The [byteOffset] must be non-negative, and
  /// `byteOffset + 3` must be less than or equal to the length of this object.
  void setInt24(int byteOffset, int value, [Endian endian = Endian.big]) {
    if (value < -0x800000 || value > 0x7FFFFF) {
      throw RangeError.range(value, -0x800000, 0x7FFFFF, 'value');
    }

    int unsignedValue = value & 0xFFFFFF;
    setUint24(byteOffset, unsignedValue, endian);
  }

  void _setInt64(bool signed, int byteOffset, int value, Endian endian) {
    if (!isWeb) return setUint64(byteOffset, value, endian);
    int low = value & 0xFFFFFFFF;
    int high = (value >> 32) & 0xFFFFFFFF;

    if (endian == Endian.little) {
      setUint32(byteOffset, low, endian);
      if (signed) setInt32(byteOffset + 4, high, endian); else setUint32(byteOffset + 4, high, endian);
    } else {
      if (signed) setInt32(byteOffset, high, endian); else setUint32(byteOffset, high, endian);
      setUint32(byteOffset + 4, low, endian);
    }
  }

  /// Sets the eight bytes starting at the specified [byteOffset] in this object
  /// to the unsigned binary representation of the specified [value],
  /// which must fit in eight bytes.
  ///
  /// In other words, [value] must be between
  /// 0 and 2<sup>64</sup> - 1, inclusive.
  ///
  /// The [byteOffset] must be non-negative, and
  /// `byteOffset + 8` must be less than or equal to the length of this object.
  ///
  /// This function is designed to work on web safely.
  void setUint64Safe(int byteOffset, int value, [Endian endian = Endian.big]) {
    return _setInt64(false, byteOffset, value, endian);
  }

  /// Sets the eight bytes starting at the specified [byteOffset] in this
  /// object to the two's complement binary representation of the specified
  /// [value], which must fit in eight bytes.
  ///
  /// In other words, [value] must lie
  /// between -2<sup>63</sup> and 2<sup>63</sup> - 1, inclusive.
  ///
  /// The [byteOffset] must be non-negative, and
  /// `byteOffset + 8` must be less than or equal to the length of this object.
  ///
  /// This function is designed to work on web safely.
  void setInt64Safe(int byteOffset, int value, [Endian endian = Endian.big]) {
    return _setInt64(true, byteOffset, value, endian);
  }
}

/// Formats a list of bytes into a string.
extension ByteFormatter on List<int> {
  /// Formats a list of bytes into a string. If there's more than the maximum allowed, it will be shortened.
  String formatBytes({String delim = ", ", int max = 10}) {
    List<int> values = this;
    bool moreThanMax = false;

    if (values.length > max) {
      values = values.sublist(0, max);
      moreThanMax = true;
    }

    return [...values.map((x) => "0x${x.toRadixString(16).toUpperCase().padLeft(2, 0.toString())}"), if (moreThanMax) ...["${length - max} more..."]].join(delim);
  }

  /// Format the inputted list of bytes as a singular hex string.
  String formatHex() {
    List<int> values = this;
    return "0x${values.map((x) => x.toRadixString(16).toUpperCase().padLeft(2, 0.toString())).join("")}";
  }
}

/// Formats a singular integer as a byte.
extension ByteFormatterSingular on int {
  /// Formats a singular integer as a byte.
  String formatByte() {
    return [this].formatBytes();
  }
}

/// Addons for every object.
extension ObjectAddons on Object? {
  /// Literally just returns nothing. This is helpful for one-line return statements.
  void toVoid() {
    return;
  }

  /// Returns the value you put in. This is helpful for one-line return statements.
  T thenReturn<T>(T value) {
    return value;
  }
}

/// Some nice addons to [Future]s.
extension FutureAddons<T> on Future<T> {
  /// Returns a `Future<bool>` that represents if the future will equal the inputted [value] when it completes.
  Future<bool> willEqual(T value) async {
    return (await this) == value;
  }

  /// Returns a `Future<bool>` that represents if the future will be null when it completes.
  Future<bool> willBeNull() async {
    return (await this) == null;
  }

  /// Returns a `Future<bool>` that represents if the future will be non-null when it completes.
  Future<bool> willBeNonNull() async {
    return (await this) != null;
  }
}

/// Addons for lists of functions.
extension FunctionListAddons<T extends Function> on Iterable<T> {
  /// Calls every single function in this list.
  ///
  /// Note that this will not wait for futures.
  void chain() {
    for (T function in this) {
      function.call();
    }
  }

  /// Calls every single function in this list.
  ///
  /// This function will wait for each function, whether future or not.
  FutureOr<void> chainFutures() async {
    for (T function in this) {
      dynamic result = function.call();
      if (result is Future) await result;
    }
  }
}

/// Addons for enums.
extension EnumAddons on Enum {
  /// Attempts to get the enum value from a string.
  ///
  /// This will return null if not found.
  static T? fromStringOrNull<T extends Enum>(List<T> values, String target, {bool caseSensitive = true}) {
    if (caseSensitive == false) target = target.toLowerCase();
    for (T value in values) if ((caseSensitive ? value.name : value.name.toLowerCase()) == target) return value;
    return null;
  }

  /// Attempts to get the enum value from a string.
  ///
  /// This will throw a [StateError] if not found.
  static T fromString<T extends Enum>(List<T> values, String target, {bool caseSensitive = true}) {
    return fromStringOrNull(values, target, caseSensitive: caseSensitive) ?? (throw StateError("No value of '$T' matched '$target'."));
  }
}

/// Pads lists to make them a set length.
extension ListPadder<T> on List<T> {
  /// Fills the list with the provided [value] until it reaches [amount] length, starting from the left. Note that the provided list is not mutated; instead, a copy is returned.
  ///
  /// If the list length is greater than [amount], then the list is returned unchanged.
  List<T> padLeft(int amount, T value) {
    List<T> list = List.from(this);
    if (list.length >= amount) return list;
    list.insertAll(0, List.filled(amount - length, value));
    return list;
  }

  /// Fills the list with the provided [value] until it reaches [amount] length, starting from the right. Note that the provided list is mutated; instead, a copy is returned.
  ///
  /// If the list length is greater than [amount], then the list is returned unchanged.
  List<T> padRight(int amount, T value) {
    List<T> list = List.from(this);
    if (list.length >= amount) return list;
    list.addAll(List.filled(amount - length, value));
    return list;
  }
}