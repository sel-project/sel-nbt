sel-nbt
=======

[![DUB Package](https://img.shields.io/dub/v/sel-nbt.svg)](https://code.dlang.org/packages/sel-nbt)
[![Build Status](https://travis-ci.org/sel-project/sel-nbt.svg?branch=master)](https://travis-ci.org/sel-project/sel-nbt)

The **Named Binary Tag** format is used by Minecraft for the various files in which it saves data.
The format is designed to store data in a tree structure made up of various *tags*, each one with an ID and a name.

More on NBT can be found on [Minecraft Wiki](https://minecraft.gamepedia.com/NBT_format).

Usage
-----
Jump to: [Tags](#Tags), [Encoding and Decoding](#Encoding_and_Decoding), [JSON Conversion](#JSON_Conversion)

### Tags

All 12 tags are provided in the module `sel.nbt.tags` and publicly imported in the module `sel.nbt`.
Every tag is a class that extends the class `Tag` and may contain extra methods for working with the type, as documented below.

Jump to: [Tag](#Tag), [Named](#Named), [Simple Tags](#Simple_Tags), [Array tags](#Array_Tags), [List](#List), [Compound](#Compound)

#### Tag
`Tag` is the base abstract class for every tag and provides the basic properties and methods:
- The property `type` can be used to retrieve the type of the tag. It returns a type of the enum `NBT_TYPE`.
- The property `name` can be used to retrieve the name of the tag, if there is one.
- The method `rename(string)` can be used to rename the tag. A new instance of the tag is created by this method.
- `encode(Stream)` and `decode(Stream)` are used to encode and decode the tag from a stream of bytes. See the [Encoding and decoding](#Encoding_and_decoding) section for more informations about the tag's serialisation.
- `toJSON()` converts the tag to a `JSONValue`.
- `toString()` converts the tag to a human-readable string.

#### Named
`Named` is a templated that can be used to create named tags, adding a string before the other constructor arguments of the tag.
Example:
```d
Tag a = new Byte(12);
Tag b = new Named!Byte("name", 12);

assert(a.name == "");
assert(b.name == "name");
assert(a == b);
```

#### Simple Tags
Simple tags are `Byte`, `Short`, `Int`, `Long`, `Float`, `Double` and `String`, they can be compared between each others and with their basic type. Operations are also supported.
Example:
```d
Tag a = new Short(44);
assert(a == 44);
assert(a == new Short(44));
assert(a > 40);

a /= 2;
a += 5;
assert(++a == 28);
```

#### Array Tags
Array tags are `ByteArray`, `IntArray` and `LongArray`, they can be compared with their respective tag and with their basic array type. All array operations are supported and concatenation to create a new tag can also be done.
Example:
```d
Tag a = new IntArray(1, 2, 3);
assert(a == [1, 2, 3]);
assert(a[0] == 1);
assert(a.length == 3);

a ~= [4, 5];
assert(a == [1, 2, 3, 4, 5]);
```

#### List

#### Compound

### Encoding and Decoding

### JSON Conversion
