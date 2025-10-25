## What is this?

This is like my other project, `localpkg-flutter-2`, but it's a version for only Dart. This will be used as the base for `localpkg-flutter-2` as well.

## How to import

In your `pubspec.yaml`:

```yaml
dependencies:
    localpkg:
        git:
            url: https://github.com/Calebh101/localpkg-dart.git
            ref: main
```

## How to use

For using the global analysis template, add this to your `analysis_options.yaml`:

```yaml
include: package:localpkg/lints/default.yaml
```

There are also some scripts that can be used with `dart run <script>`:

- `localpkg:update`: Update localpkg in the Flutter project.

### Dynamic Numbers

Dynamic numbers are my own custom implementation of numbers that can be stored in binary in the most compact way possible. Well, this isn't *as* compact as some solutions, but it's pretty good in my (humble) opinion.

Basically, the first byte is the signature. This is just an 8-bit unsigned integer, corresponding to one of [these types](https://github.com/Calebh101/localpkg-dart/blob/main/lib/src/dynamic_number.dart#L9-L34). New types may be added over time, but existing types will never change ID.

You can then use the bits/bytes from this type to know many bytes the number is (excluding the signature), and how to parse it (unsigned 8-bit integer, signed 32-bit integer, 64-bit float, etcetera).