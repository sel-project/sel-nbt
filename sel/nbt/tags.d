/*
 * Copyright (c) 2017-2018 sel-project
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */
/**
 * Copyright: Copyright (c) sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/sel-nbt/sel/nbt/tags.d, sel/nbt/tags.d)
 */
module sel.nbt.tags;

import std.algorithm : canFind;
import std.conv : to;
import std.json : JSONValue;
import std.string : capitalize, join;
import std.traits : isAbstractClass, isNumeric;
import std.typetuple : TypeTuple;

import sel.nbt.stream;

/**
 * NBT's ids, as unsigned bytes, used by for client-server
 * and generic io communication.
 */
enum NBT_TYPE : ubyte {
	
	END = 0,
	BYTE = 1,
	SHORT = 2,
	INT = 3,
	LONG = 4,
	FLOAT = 5,
	DOUBLE = 6,
	BYTE_ARRAY = 7,
	STRING = 8,
	LIST = 9,
	COMPOUND = 10,
	INT_ARRAY = 11,
	LONG_ARRAY = 12,
	
}

alias Tags = TypeTuple!(null, Byte, Short, Int, Long, Float, Double, ByteArray, String, List, Compound, IntArray, LongArray);

private string format(string str) {
	import std.string : replace;
	return "\"" ~ str.replace("\"", "\\\"") ~ "\"";
}

/**
 * Base class for every NBT that contains id and encoding
 * functions (the endianness may vary from a Minecraft version
 * to another and the purpose of the tags in the game).
 */
class Tag {

	protected bool _named;
	protected string _name;

	/**
	 * Gets the tag's type.
	 * Returns: a value in the NBT_TYPE enum
	 * Example:
	 * ---
	 * assert(new Byte().type == NBT_TYPE.BYTE);
	 * assert(new List().type == NB_TYPE.LIST);
	 * assert(new Tags[NBT_TYPE.INT]().type == NBT_TYPE.INT);
	 * ---
	 */
	public @property NBT_TYPE type() pure nothrow @safe @nogc;

	/**
	 * Indicates whether the tag has a name.
	 */
	public final bool named() pure nothrow @safe @nogc {
		return _named;
	}

	/**
	 * Gets the tag's name, if there's one.
	 */
	public string name() pure nothrow @safe @nogc {
		return _name;
	}

	/**
	 * Creates a NamedTag maintaing the tag's properties.
	 * Example:
	 * ---
	 * auto t = new Float(22);
	 * auto named = t.rename("float");
	 * assert(cast(NamedTag)named);
	 * assert(named.name == "float");
	 * assert(named == 22);
	 * ---
	 */
	public abstract Tag rename(string) pure nothrow @safe;

	/**
	 * Encodes the tag's body.
	 */
	public abstract void encode(Stream) pure nothrow @safe @nogc;

	/**
	 * Decodes the tag's body.
	 */
	public abstract void decode(Stream) pure @safe;
	
	/**
	 * Encodes the tag's value as json.
	 */
	public abstract JSONValue toJSON();

	/**
	 * Encodes the tag a human-readable string.
	 */
	public override abstract string toString();
	
}

/**
 * Creates a named tag. The first argument of the constructor becomes a string
 * (the name) and rest doesn't change.
 * Example:
 * ---
 * auto tag = new Named!Int("name", 12);
 * assert(tag.named);
 * assert(tag.name == "name");
 * assert(tag.value == 12);
 * assert(tag == new Int(12));
 * ---
 */
template Named(T:Tag) {

	class Named : T {

		public this(E...)(string name, E args) {
			super(args);
			this._named = true;
			this._name = name;
		}

	}

}

/**
 * Simple tag with a value of type T, if T is a primitive type
 * or it can be written in the buffer.
 * Example:
 * ---
 * assert(new Short(1) == 1);
 * assert(new SimpleTag!(char, 12)('c') == 'c');
 * ---
 */
class SimpleTag(T, NBT_TYPE _type) : Tag {
	
	public T value;

	public this(T value=T.init) {
		this.value = value;
	}

	public override @property NBT_TYPE type() {
		return _type;
	}

	public override Tag rename(string name) {
		return new Named!(SimpleTag!(T, _type))(name, this.value);
	}

	public override void encode(Stream stream) {
		mixin("stream.write" ~ capitalize(T.stringof))(this.value);
	}

	public override void decode(Stream stream) {
		this.value = mixin("stream.read" ~ capitalize(T.stringof))();
	}
	
	public override bool opEquals(Object o) {
		auto c = cast(typeof(this))o;
		return c !is null && this.opEquals(c.value);
	}
	
	public bool opEquals(T value) {
		return this.value == value;
	}

	public override int opCmp(Object o) {
		auto c = cast(typeof(this))o;
		return c is null ? -1 : this.opCmp(c.value);
	}

	public int opCmp(T value) {
		return this.value == value ? 0 : (this.value < value ? -1 : 1);
	}

	public override JSONValue toJSON() {
		return JSONValue(this.value);
	}
	
	public override string toString() {
		static if(is(T : string)) {
			return format(this.value);
		} else {
			return to!string(this.value);
		}
	}
	
	alias value this;
	
}

/**
 * Tag with a signed byte, usually used to store small
 * values like the progress of an action or the type of
 * an entity.
 * An unsigned version of the tag can be obtained doing a
 * cast to ubyte.
 * <a href="#ByteArray">Byte Array</a> is a tag with an array
 * of unsigned bytes.
 * Example:
 * ---
 * assert(cast(ubyte)(new Byte(-1)) == 255);
 * ---
 */
alias Byte = SimpleTag!(byte, NBT_TYPE.BYTE);

/**
 * Byte tag that only uses the values 1 and 0 to indicate
 * respectively true and false.
 * It's usually used by SEL to store boolean values instead
 * of a byte tag.
 * Example:
 * ---
 * assert(new Byte(1) == new Bool(true));
 * ---
 */
alias Bool = Byte;

/**
 * Tag with a signed short, used when the 255 bytes (or 127
 * if only the positive part is counted) is not enough.
 * This tag can also be converted to its unsigned version
 * doing a simple cast to ushort.
 */
alias Short = SimpleTag!(short, NBT_TYPE.SHORT);

/**
 * Tag with a signed integer, used to store values that
 * don't usually fit in the short tag, like entity's ids.
 * This tag can aslo be converted to its unsigned version
 * (uint) with a simple cast to it.
 * <a href="#IntArray">Int Array</a> is a tag with an array
 * of signed integers.
 */
alias Int = SimpleTag!(int, NBT_TYPE.INT);

/**
 * Tag with a signed long.
 */
alias Long = SimpleTag!(long, NBT_TYPE.LONG);

/**
 * Tag with a 4-bytes floating point value, usually used to
 * store non-blocks coordinates or points in the world.
 * The float.nan value can be used and recognized by the
 * SEL-derived systems, but couldn't be recognized by other
 * softwares based on different programming languages that
 * doesn't support the not-a-number value.
 * More informations about the NaN value and its encoding
 * can be found on <a href="#https://en.wikipedia.org/wiki/NaN">Wikipedia</a>.
 */
alias Float = SimpleTag!(float, NBT_TYPE.FLOAT);

/**
 * Tag with an 8-bytes float point value used instead of the
 * Float tag if the precision or the available number's range
 * must be higher.
 * See <a href="#Float">Float</a>'s documentation for informations
 * about the NaN value and its support inside and outside SEL.
 */
alias Double = SimpleTag!(double, NBT_TYPE.DOUBLE);

/**
 * Tag with an UTF-8 string encoded as its length as short and
 * its content casted to btyes.
 * Example:
 * ---
 * assert(new String("test") == "");
 * assert(new String("", "test") == "test");
 * ---
 */
alias String = SimpleTag!(string, NBT_TYPE.STRING);

unittest {
	
	assert(new Byte(1) == new Bool(true));
	assert(new Named!Int("", 1).named);
	assert(new Named!Int("", 1).name == "");
	assert(new Named!Int("test", 12) == new Named!Int("test", 12));
	assert(new Named!Long("test", 44) == 44);
	assert(new Named!Double("test", 0) == new Named!Double("test!", 0));
	assert(new Named!Float("test", 0) != 1);
	assert(12f == new Float(12f));

	auto t = new Int(22);
	t += 44;
	assert(t == 66);
	assert(t > 22);
	t /= 2;
	assert(t == 33);
	assert(t <= 33);
	assert(t > new Int(0));
	t = 100;
	assert(t == 100);

	Tag tag = new Byte(1);
	assert(tag > new Byte(0));

	assert(new Long(44).toString() == "44"); // format may change

	import std.system : Endian;
	Stream stream = new ClassicStream!(Endian.bigEndian)();

	new Byte(1).encode(stream);
	new Short(5).encode(stream);
	new Bool(false).encode(stream);
	assert(stream.data == [1, 0, 5, 0]);

	auto i = new Int();
	i.decode(stream);
	assert(i == 16778496);

	stream.data = [1, 1];
	auto b = stream.readNamelessTag();
	assert(cast(Byte)b && cast(Byte)b == 1);

	stream.writeNamelessTag(new Short(12));
	assert(stream.data == [2, 0, 12]);
	
}

/**
 * Simple tag with array-related functions.
 * Example:
 * ---
 * assert(new ByteArray([2, 3, 4]).length == new IntArray([9, 0, 12]).length);
 * 
 * auto b = new ByteArray();
 * assert(b.empty);
 * b ~= 14;
 * assert(b.length == 1 && b[0] == 14);
 * ---
 */
class ArrayTag(T, NBT_TYPE _type) : Tag {

	public T[] value;

	public this(T[] value...) {
		if(value !is null) {
			this.value = value;
		}
	}

	public override @property NBT_TYPE type() {
		return _type;
	}

	public override abstract Tag rename(string);
	
	/**
	 * Concatenates T, an array of T or a NBT array of T to the tag.
	 * Example:
	 * ---
	 * auto array = new IntArray([1]);
	 * 
	 * array ~= 1;
	 * assert(array == [1, 1]);
	 * 
	 * array ~= [1, 2, 3];
	 * assert(array == [1, 1, 1, 2, 3]);
	 *
	 * array ~= new IntArray([100, 99]);
	 * assert(array == [1, 1, 1, 2, 3, 100, 99]);
	 * ---
	 */
	public @safe void opOpAssign(string op : "~", G)(G value) if(is(G == T) || is(G == T[])) {
		this.value ~= value;
	}
	
	/**
	 * Does the same job opOpAssign does, but creates a new instance
	 * of typeof(this) with the same name of the tag and returns it.
	 * Example:
	 * ---
	 * auto array = new IntArray([1, 2, 3]);
	 * assert(array ~ [2, 1] == [1, 2, 3, 2, 1] && array == [1, 2, 3]);
	 * ---
	 */
	public @safe typeof(this) opBinary(string op : "~", G)(G value) if(is(G == T) || is(G == T[])) {
		return new typeof(this)(this.name, this.value ~ value);
	}
	
	/**
	 * Removes the element at the given index from the array.
	 * Throws: RangeError if index is higher or equals than the array's length
	 * Example:
	 * ---
	 * auto array = new IntArray([1, 2, 3]);
	 * array.remove(0);
	 * assert(array == [2, 3]);
	 * ---
	 */
	public @safe void remove(size_t index) {
		this.value = this.value[0..index] ~ this.value[index+1..$];
	}
	
	/**
	 * Checks whether or not the array's length is equals to 0.
	 */
	public final @property bool empty() pure nothrow @safe @nogc {
		return this.value.length == 0;
	}

	public override abstract void encode(Stream);

	public override abstract void decode(Stream);

	public override abstract JSONValue toJSON();
	
	public override string toString() {
		string[] ret;
		foreach(tag ; this.value) {
			ret ~= tag.to!string;
		}
		return "[" ~ ret.join(",") ~ "]";
	}
	
}

/// ditto
class NumericArrayTag(T, NBT_TYPE _type) : ArrayTag!(T, _type) if(isNumeric!T) {

	public this(T[] value...) {
		super(value);
	}
	
	public override Tag rename(string name) {
		return new Named!(NumericArrayTag!(T, _type))(name, this.value);
	}
	
	public override void encode(Stream stream) {
		stream.writeLength(this.value.length);
		foreach(v ; this.value) {
			mixin("stream.write" ~ capitalize(T.stringof) ~ "(v);");
		}
	}
	
	public override void decode(Stream stream) {
		this.value.length = stream.readLength();
		foreach(ref v ; this.value) {
			mixin("v = stream.read" ~ capitalize(T.stringof) ~ "();");
		}
	}
	
	public override bool opEquals(Object o) {
		auto c = cast(typeof(this))o;
		return c !is null && this.value == c.value;
	}
	
	public bool opEquals(T[] value) {
		return this.value == value;
	}
	
	public bool opEquals(T value) {
		if(this.value.length == 0) return false;
		foreach(v ; this.value) {
			if(v != value) return false;
		}
		return true;
	}

	public override JSONValue toJSON() {
		return JSONValue(this.value);
	}

	alias value this;

}

/**
 * Array of unsigned bytes (clients and other softwares may
 * interpret the bytes as signed due to limitations of the
 * programming language).
 * The tag is usually used by Minecraft's worlds to store
 * blocks' ids and metas.
 * 
 * If a signed byte is needed a cast operation can be done.
 * Example:
 * ---
 * auto unsigned = new ByteArray([0, 1, 255]);
 * auto signed = cast(byte[])unsigned;
 * assert(signed == [0, 1, -1]);
 * ---
 */
alias ByteArray = NumericArrayTag!(byte, NBT_TYPE.BYTE_ARRAY);

/**
 * Array of signed integers, introduced in the last version
 * of the NBT format. Used by anvil worlds.
 * 
 * The same cast rules also apply for this tag's values.
 * Example:
 * ---
 * auto signed = new IntArray([-1]);
 * assert(cast(uint[])signed == [uint.max]);
 * ---
 */
alias IntArray = NumericArrayTag!(int, NBT_TYPE.INT_ARRAY);

/**
 * Array of signed longs, introduced in Minecraft: Java Edition 1.13
 * and not yet in the other versions of Minecraft.
 */
alias LongArray = NumericArrayTag!(long, NBT_TYPE.LONG_ARRAY);

unittest {

	assert(new IntArray(1) == new IntArray(1));
	assert(new IntArray(1, 2, 3) == [1, 2, 3]);
	assert(new ByteArray([4]).length == 1);
	assert(new IntArray(0, 1)[1] == 1);
	assert(new IntArray(1, 1) == 1);
	assert(new LongArray(long.max, 0, -1) == [long.max, 0, -1]);

	assert(new ByteArray(1, 2, 3).toString() == "[1,2,3]");

	auto list = new IntArray(0);
	list[0] = 14;
	assert(list[0] == 14);
	list ~= 100;
	list ~= [1, 2];
	list.remove(0);
	assert(list == [100, 1, 2]);
	assert(!list.empty);
	assert(list.toJSON() == JSONValue([100, 1, 2]));
	assert(cast(IntArray)list.rename("test") == [100, 1, 2]);

	import std.system : Endian;
	Stream stream = new ClassicStream!(Endian.bigEndian);
	new ByteArray(1, 2, 3).encode(stream);
	assert(stream.data == [0, 0, 0, 3, 1, 2, 3]);

	stream = new ClassicStream!(Endian.littleEndian)([NBT_TYPE.INT_ARRAY, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0]);
	auto tag = cast(IntArray)stream.readTag();
	assert(tag !is null);
	assert(tag.name == "");
	assert(tag == [1, 2]);

	stream = new NetworkStream!(Endian.bigEndian)();
	new ByteArray(1, 2, 3).encode(stream);
	assert(stream.data == [3, 1, 2, 3]);

	stream.buffer.reset();
	new IntArray(1, 200, -2).encode(stream);
	assert(stream.data == [3, 2, 144, 3, 3]);
	auto ia = new IntArray();
	ia.decode(stream);
	assert(ia == [1, 200, -2], ia.toString());

	stream = new ClassicStream!(Endian.bigEndian);
	new LongArray(1, long.min).encode(stream);
	assert(stream.data == [0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 1, 128, 0, 0, 0, 0, 0, 0, 0]);

}

interface IList {
	
	public @property ubyte childType() pure nothrow @safe @nogc;
	
	public @property Tag[] tags() @safe;

	public @property size_t length() pure nothrow @safe @nogc;
	
}

class ListImpl(T:Tag) : ArrayTag!(T, NBT_TYPE.LIST), IList {

	public this(T[] value) @safe {
		foreach(ref v ; value) {
			v._named = false;
			v._name = "";
		}
		super(value);
	}

	public override abstract @property ubyte childType();

	public @property Tag[] tags() @trusted {
		static if(is(T == Tag)) {
			return this.value;
		} else {
			Tag[] ret = new Tag[this.value.length];
			foreach(i, v; this.value) {
				ret[i] = v;
			}
			return ret;
		}
	}

	public final override @property size_t length() {
		return this.value.length;
	}

	public override void encode(Stream stream) {
		stream.writeByte(this.childType);
		stream.writeLength(this.value.length);
		foreach(v ; this.value) {
			v.encode(stream);
		}
	}

	public override abstract void decode(Stream stream);

	public override bool opEquals(Object o) {
		auto l = cast(IList)o;
		return l !is null && this.tags == l.tags;
	}

	public E opCast(E)() if(is(E == List)) {
		return new List(this.tags);
	}

	public E opCast(E)() if(is(E == class) && is(E.Type) && is(typeof(E.tagType))) {
		if(this.childType == E.tagType) {
			E.Type[] ret;
			foreach(v ; this.value) {
				ret ~= cast(E.Type)v;
			}
			return new E(ret);
		} else {
			return null;
		}
	}

	public override JSONValue toJSON() {
		JSONValue[] json;
		foreach(v ; this.value) {
			json ~= v.toJSON();
		}
		return JSONValue(json);
	}

}

class List : ListImpl!Tag {

	private static immutable Tag function() pure nothrow @safe[ubyte] constructors;

	public static this() @safe {
		foreach(i, T; Tags) {
			static if(is(T : Tag)) {
				constructors[i] = () pure nothrow @safe { return new T(); };
			}
		}
	}

	private ubyte child_type = 0;
	
	public this(Tag[] tags...) pure nothrow @safe {
		super(tags);
	}

	public override Tag rename(string name) {
		return new Named!List(name, this.value);
	}

	public @property bool valid() pure nothrow @safe @nogc {
		ubyte type;
		if(this.child_type) {
			type = this.child_type;
		} else {
			if(this.value.length == 0) return false;
			type = this.value[0].type;
		}
		foreach(v ; this.value) {
			if(v.type != type) return false;
		}
		return true;
	}
	
	public final override @property ubyte childType() {
		return this.child_type != 0 ? this.child_type : (this.length == 0 ? NBT_TYPE.END : this.value[0].type);
	}

	public override void decode(Stream stream) {
		this.child_type = stream.readByte();
		immutable length = stream.readLength();
		auto ctor_ptr = this.child_type in constructors;
		if(ctor_ptr) {
			auto ctor = *ctor_ptr;
			foreach(i ; 0..length) {
				Tag tag = ctor();
				tag.decode(stream);
				this.value ~= tag;
			}
		}
	}
	
	alias value this;
	
}

unittest {

	assert(!new List().valid);

	auto list = new List(new Int(2), new Named!Int("3", 3));
	assert(list.valid);
	assert(list.childType == NBT_TYPE.INT);
	assert(list[1].name == "");
	assert(cast(ListOf!Byte)list is null);
	assert(cast(ListOf!Int)list !is null);

	import std.system : Endian;

	auto stream = new ClassicStream!(Endian.littleEndian)();
	list.encode(stream);
	assert(stream.data == [NBT_TYPE.INT, 2, 0, 0, 0, 2, 0, 0, 0, 3, 0, 0, 0]);

	list.value.length = 0;
	list.decode(stream);
	assert(list.valid);
	assert(list.length == 2);
	assert(list == new List([new Int(2), new Int(3)]));

}

/// ditto
class ListOf(T:Tag) : ListImpl!T if(!isAbstractClass!T) {

	public alias Type = T;

	public static immutable ubyte tagType;

	public static this() {
		tagType = new T().type;
	}
	
	public this(E=T)(E[] tags...) if(is(E == T) || is(E : typeof(T.value))) {
		static if(is(E == T)) {
			super(tags);
		} else {
			T[] nt;
			foreach(t ; tags) {
				nt ~= new T(t);
			}
			this(nt);
		}
	}

	public override Tag rename(string name) {
		return new Named!(ListOf!T)(name, this.value);
	}
	
	public final override @property ubyte childType() {
		return tagType;
	}

	public override void decode(Stream stream) {
		// shouldn't be called
	}
	
	alias value this;
	
}

unittest {
	
	auto list = new ListOf!Byte();
	assert(cast(List)list !is null);
	list ~= new Byte(1);
	list ~= new Byte(2);
	assert(list.length == 2);
	assert(list[0] == 1 && list[1] == 2);
	assert(list.childType == NBT_TYPE.BYTE);
	assert(list.rename("test").name == "test");

	assert(new ListOf!Int(1, 2, 3).tags == [new Int(1), new Int(2), new Int(3)]);
	
}

/**
 * Associative array of named tags (that can be of different types).
 * Example:
 * ---
 * auto compound = new Compound();
 * compound["string"] = new String("test");
 * compound["byte"] = new Byte(18);
 * ---
 */
class Compound : Tag {

	private Tag[] value;
	private string[] n_names; // to mantain order and avoid the use of associative array's opApply
	
	public this(Tag[] tags...) pure nothrow @safe {
		if(tags !is null) {
			foreach(tag ; tags) {
				assert(tag.named);
				if(!this.n_names.canFind(tag.name)) {
					this.value ~= tag;
					this.n_names ~= tag.name;
				}
			}
		}
	}

	public override @property NBT_TYPE type() {
		return NBT_TYPE.COMPOUND;
	}

	public override Tag rename(string name) {
		return new Named!Compound(name, this.value);
	}

	protected ptrdiff_t search(string cmp) pure nothrow @safe {
		foreach(i, name; this.n_names) {
			if(name == cmp) return i;
		}
		return -1;
	}
	
	/**
	 * Checks whether or not a value is in the associative array.
	 * Returns: true if the key is found, false otherwise
	 */
	public bool has(string name) pure nothrow @safe {
		return this.search(name) >= 0;
	}
	
	/**
	 * Checks if the key is associated to a value and that the value
	 * is of the same type of T.
	 * Returns: true if the value is found and is of the type T, false otherwise
	 */
	public bool has(T:Tag)(string name) pure nothrow @trusted {
		auto index = this.search(name);
		if(index < 0) return false;
		static if(is(T : IList) && !is(T == List)) {
			// special cast
			return cast(T)cast(List)this.value[index] !is null;
		} else {
			return cast(T)this.value[index] !is null;
		}
	}
	
	/**
	 * Gets a pointer to the element at the given index.
	 * Example:
	 * ---
	 * auto test = "test" in compound;
	 * if(test && cast(String)*test) {
	 *    assert(*test == "test");
	 * }
	 * ---
	 */
	public Tag* opBinaryRight(string op : "in")(string name) pure nothrow @safe {
		auto index = this.search(name);
		return index >= 0 ? &this.value[index] : null;
	}
	
	/**
	 * Gets the array of named tags (without the keys).
	 * To get the associative array of named tags use the
	 * property value.
	 * Example:
	 * ---
	 * Compound compound = new Compound([new Byte(1), new Int(2)]);
	 * assert(compound[] == compound.value.values);
	 * ---
	 */
	public Tag[] opIndex() pure nothrow @safe {
		return this.value;
	}
	
	/**
	 * Gets the element at the given index.
	 * Throws: RangeError if the given index is not in the array
	 * Example:
	 * ---
	 * assert(new Compound(new Named!String("0", "test"))["0"] == "test");
	 * ---
	 */
	public Tag opIndex(string name) pure nothrow @safe {
		return this.value[this.search(name)];
	}
	
	/**
	 * Gets the element at the given index, if exists and can be casted to T.
	 * Otherwise evaluates and returns defaultValue.
	 * Returns: the named tag of type T or defaultValue if the conversion fails
	 * Example:
	 * ---
	 * auto compound = new Compound(new Named!String("test", "value"));
	 * assert(is(typeof(compound["test"]) == NamedTag));
	 * assert(is(typeof(compound.get!String("test", null)) == String));
	 * assert(compound.get!String("failed", new String("failed")) == new String("failed"));
	 * assert(compound.get!String("?", "string") == new String("string"));
	 * ---
	 */
	public T get(T:Tag)(string name, lazy T defaultValue) pure @safe {
		T ret = null;
		immutable index = this.search(name);
		if(index >= 0) {
			static if(is(T : IList) && !is(T == List)) {
				// special cast
				ret = cast(T)cast(List)this.value[index];
			} else {
				ret = cast(T)this.value[index];
			}
		}
		if(ret !is null) return ret;
		else return defaultValue;
	}

	/// ditto
	public T get(T:Tag, E)(string name, E defaultValue) pure @safe if(!is(T == E) && __traits(compiles, new T(defaultValue))) {
		return this.get!T(name, new T(defaultValue));
	}

	/**
	 * Gets the tag's value at the given index, if it exists and can be
	 * casted to T. Otherwise returns defaultValue.
	 * Example:
	 * ---
	 * auto compound = new Compound(new Named!String("test", "value"));
	 * assert(compound.getValue!String("test", "") == "value");
	 * assert(compound.getValue!Int("test", 0) == 0);
	 * assert(compound.getValue!String("miss", "miss") == "miss");
	 * ---
	 */
	public typeof(T.value) getValue(T:Tag)(string name, lazy typeof(T.value) defaultValue) pure @safe if(__traits(hasMember, T, "value")) {
		T ret = null;
		immutable index = this.search(name);
		if(index >= 0) {
			static if(is(T : IList) && !is(T == List)) {
				// special cast
				ret = cast(T)cast(List)this.value[index];
			} else {
				ret = cast(T)this.value[index];
			}
		}
		if(ret !is null) return ret.value;
		else return defaultValue;
	}
	
	/**
	 * Sets the value at the given index.
	 * If the tag's name is different from the given index, the tag's
	 * name will be changed to the given index's one.
	 * Example:
	 * ---
	 * compound["string"] = new String("test", "test");
	 * assert(compound["string"].name == "string");
	 * compound["int"] = 12;
	 * compound["string"] = "Another string";
	 * ---
	 */
	public void opIndexAssign(T)(T value, string name) pure nothrow @safe if(is(T : Tag) || isNumeric!T || is(T == bool) || is(T == string) || is(T == ubyte[]) || is(T == byte[]) || is(T == int[])) {
		Tag tag;
		static if(is(T : Tag)) {
			value._named = true;
			value._name = name;
			tag = value;
		} else {
			static if(is(T == bool) || is(T == byte) || is(T == ubyte)) tag = new Named!Byte(name, value);
			else static if(is(T == short) || is(T == ushort)) tag = new Named!Short(name, value);
			else static if(is(T == int) || is(T == uint)) tag = new Named!Int(name, value);
			else static if(is(T == long) || is(T == ulong)) tag = new Named!Long(name, value);
			else static if(is(T == float)) tag = new Named!Float(name, value);
			else static if(is(T == double)) tag = new Named!Double(name, value);
			else static if(is(T == string)) tag = new Named!String(name, value);
			else static if(is(T == ubyte[]) || is(T == byte[])) tag = new Named!ByteArray(name, value);
			else tag = new Named!IntArray(name, value);
		}
		this[] = tag;
	}
	
	/**
	 * Sets the value using the named tag's name as the index.
	 * Example:
	 * ---
	 * auto compound = new Compound("");
	 * compound[] = new String("test", "value");
	 * assert(compound["test"] == "value");
	 * ---
	 */
	public void opIndexAssign(Tag tag) pure nothrow @safe {
		assert(tag.named);
		auto i = this.search(tag.name);
		if(i >= 0) {
			this.value[i] = tag;
		} else {
			this.value ~= tag;
			this.n_names ~= tag.name;
		}
	}
	
	/**
	 * Removed the given index from the array, if set.
	 * Example:
	 * ---
	 * auto compound = new Compound("", ["string", new String("test")]);
	 * assert("string" in compound);
	 * compound.remove("string");
	 * assert("string" !in compound);
	 * ---
	 */
	public void remove(string name) @safe {
		auto index = this.search(name);
		if(index >= 0) {
			this.value = this.value[0..index] ~ this.value[index+1..$];
			this.n_names = this.n_names[0..index] ~ this.n_names[index+1..$];
		}
	}
	
	/// Gets the length of the array (or the number of NamedTags in it).
	public final @property size_t length() pure nothrow @safe @nogc {
		return this.value.length;
	}
	
	/// Checks whether or not the array is empty (its length is equal to 0).
	public final @property bool empty() pure nothrow @safe @nogc {
		return this.length == 0;
	}
	
	/**
	 * Gets the keys (indexes of the array).
	 * Example:
	 * ---
	 * assert(new Compound("", ["a": new String("a"), "b": new String("b")]).keys == ["a", "b"]);
	 * ---
	 */
	public @property string[] names() pure nothrow @safe @nogc {
		return this.n_names;
	}
	
	/**
	 * Creates an exact duplicate of the tag.
	 */
	public @property Compound dup() {
		auto ret = new Compound();
		ret.value = this.value.dup;
		ret.n_names = this.n_names.dup;
		return ret;
	}

	public override void encode(Stream stream) {
		foreach(tag ; this.value) {
			stream.writeTag(tag);
		}
		stream.writeByte(NBT_TYPE.END);
	}

	public override void decode(Stream stream) {
		Tag next;
		while((next = stream.readTag()) !is null) {
			this[] = next;
		}
	}

	public override JSONValue toJSON() {
		JSONValue[string] json;
		foreach(tag ; this.value) {
			json[tag.name] = tag.toJSON();
		}
		return JSONValue(json);
	}
	
	public override bool opEquals(Object object) {
		auto c = cast(Compound)object;
		return c !is null && this.cmpTags(c.value);
	}
	
	public bool opEquals(Tag[] tags) {
		return this.cmpTags(tags);
	}

	private bool cmpTags(Tag[] tags) {
		if(this.length != tags.length) return false;
		foreach(i, tag; tags) {
			auto ptr = tag.name in this;
			if(ptr is null || *ptr != tag) return false;
		}
		return true;
	}
	
	public override string toString() {
		string[] ret;
		foreach(tag ; this.value) {
			ret ~= format(tag.name) ~ ":" ~ tag.toString();
		}
		return "{" ~ ret.join(",") ~ "}";
	}
	
}

unittest {

	Compound compound = new Compound();

	compound["0"] = "string";
	compound[] = new Named!Int("int", 44);
	compound["c"] = new Compound();
	assert(cast(String)compound["0"]);
	assert(cast(Int)compound["int"]);
	assert(compound.has!Compound("c"));
	assert(compound.get!String("0", null) == "string");
	assert(compound.get!Int("int", null) == 44);
	assert(compound.get!Long("miss", new Long(44)) == new Long(44));
	assert(compound.get!Short("miss", short(12)) == new Short(12));
	assert(compound.getValue!String("0", "") == "string");
	assert(compound.getValue!Int("int", 0) == 44);
	assert(compound.getValue!Short("int", short(12)) == 12);
	assert(compound.getValue!Long("miss", 100) == 100);

	Tag tag = new Compound(new Named!String("a", "b"));
	assert(tag == cast(Tag)new Compound(new Named!String("a", "b")));

	auto s = "0" in compound;
	assert(s && cast(String)*s);
	assert(cast(String)*s == "string");
	assert(*s == new String("string"));

	assert(compound == new Compound(new Named!Int("int", 44), new Named!String("0", "string"), new Named!Compound("c")));
	compound.remove("c");
	assert(compound.length == 2);
	assert(compound.names == ["0", "int"]);
	assert(compound.toString() == "{\"0\":\"string\",\"int\":44}", compound.toString());
	assert(!compound.empty);
	assert(compound.dup == [new Named!Int("int", 44), new Named!String("0", "string")]);
	compound.remove("int");
	compound.remove("0");
	assert(compound.empty);

	compound["test"] = new Named!String("test", "test");
	auto test = "Test" in compound;
	assert(test is null);
	assert(!compound.has("Test"));
	compound["test"] = new String("test");
	assert(compound[] == [new Named!String("test", "test")]);

	assert(new Compound(new Named!Int("1", 1), new Named!Int("2", 2)) == [new Named!Int("2", 2), new Named!Int("1", 1)]);

	import std.system : Endian;

	Stream stream = new ClassicStream!(Endian.littleEndian)([NBT_TYPE.COMPOUND, 0, 0, 0]);
	compound = cast(Compound)stream.readTag();
	assert(compound.name == "");
	assert(compound.empty);

	stream = new NetworkStream!(Endian.littleEndian)([NBT_TYPE.COMPOUND, 0, NBT_TYPE.LIST, 1, 'a', NBT_TYPE.INT, 2, 1, 2, NBT_TYPE.END]);
	compound = cast(Compound)stream.readTag();
	assert(compound);
	assert(compound.has!List("a"));
	assert(compound.has!(ListOf!Int)("a"));
	//assert(!compound.has!(ListOf!(ListOf!Int))("a"));
	auto list = compound.get!(ListOf!Int)("a", null);
	assert(list == new List([new Int(-1), new Int(1)]));

}
