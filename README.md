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