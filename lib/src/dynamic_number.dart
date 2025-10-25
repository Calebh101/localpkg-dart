import 'dart:typed_data';

import 'package:localpkg/functions.dart';

/// Different types of numbers, with their respective IDs.
///
/// If you are planning on adding to this, *do not* edit current numbers' IDs, as this can break existing implentations.
enum DynamicNumberMode {
  /// Signed 8-bit integer. ID: 0
  int8(0, 0, 8),
  /// Signed 16-bit integer. ID: 1
  int16(0, 1, 16),
  /// Signed 24-bit integer. ID: 2
  int24(0, 2, 24),
  /// Signed 32-bit integer. ID: 3
  int32(0, 3, 32),
  /// Signed 64-bit integer. ID: 4
  int64(0, 4, 64),

  /// Unsigned 8-bit integer. ID: 5
  uint8(1, 5, 8),
  /// Unsigned 16-bit integer. ID: 6
  uint16(1, 6, 16),
  /// Unsigned 24-bit integer. ID: 7
  uint24(1, 7, 24),
  /// Unsigned 32-bit integer. ID: 8
  uint32(1, 8, 32),
  /// Unsigned 64-bit integer. ID: 9
  uint64(1, 9, 64),

  /// 32-bit floating point number. ID: 10
  float32(2, 10, 32),
  /// 64-bit floating point number. ID: 11
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