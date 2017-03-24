module nbt.stream;

import std.bitmanip : littleEndianToNative, bigEndianToNative, nativeToLittleEndian, nativeToBigEndian;
import std.string : capitalize, toUpper;
import std.system : Endian;

import nbt.tags;

private pure nothrow @safe ubyte[] write(T, Endian endianness)(T value) {
	mixin("return nativeTo" ~ endianString(endianness)[0..1].toUpper ~ endianString(endianness)[1..$] ~ "!T(value).dup;");
}

private pure nothrow @safe T read(T, Endian endianness)(ref ubyte[] buffer) {
	if(buffer.length >= T.sizeof) {
		ubyte[T.sizeof] b = buffer[0..T.sizeof];
		buffer = buffer[T.sizeof..$];
		mixin("return " ~ endianString(endianness) ~ "ToNative!T(b);");
	} else if(buffer.length) {
		buffer.length = T.sizeof;
		return read!(T, endianness)(buffer);
	} else {
		return T.init;
	}
}

private pure nothrow @safe string endianString(Endian endianness) {
	return endianness == Endian.littleEndian ? "littleEndian" : "bigEndian";
}

class Stream {

	public ubyte[] buffer;
	
	public pure nothrow @safe @nogc this(ubyte[] buffer=[]) {
		this.buffer = buffer;
	}

	public pure nothrow @safe void writeTag(Tag tag) {
		this.writeByte(tag.type);
		tag.encode(this);
	}

	public pure nothrow @safe void writeNamedTag(string name, Tag tag) {
		this.writeByte(tag.type);
		this.writeString(name);
		tag.encode(this);
	}

	public pure nothrow @safe void writeNamedTag(NamedTag tag) {
		this.writeNamedTag(tag.name, tag);
	}

	public abstract pure nothrow @safe void writeByte(byte value);

	public abstract pure nothrow @safe void writeShort(short value);

	public abstract pure nothrow @safe void writeInt(int value);

	public abstract pure nothrow @safe void writeLong(long value);

	public abstract pure nothrow @safe void writeFloat(float value);

	public abstract pure nothrow @safe void writeDouble(double value);

	public abstract pure nothrow @safe void writeString(string value);

	public abstract pure nothrow @safe void writeLength(size_t value);

	public pure nothrow @safe Tag readTag() {
		switch(this.readByte()) {
			foreach(i, T; Tags) {
				static if(is(T : Tag)) {
					case i: return this.decodeTagImpl(new T());
				}
			}
			default: return null;
		}
	}

	public pure nothrow @safe NamedTag readNamedTag() {
		switch(this.readByte()) {
			foreach(i, T; Tags) {
				static if(is(T : Tag)) {
					case i: return this.decodeTagImpl(new Named!T(this.readString()));
				}
			}
			default: return null;
		}
	}

	public pure nothrow @safe T decodeTagImpl(T:Tag)(T tag) {
		tag.decode(this);
		return tag;
	}

	public abstract pure nothrow @safe byte readByte();

	public abstract pure nothrow @safe short readShort();

	public abstract pure nothrow @safe int readInt();

	public abstract pure nothrow @safe long readLong();

	public abstract pure nothrow @safe float readFloat();

	public abstract pure nothrow @safe double readDouble();

	public abstract pure nothrow @safe string readString();

	public abstract pure nothrow @safe size_t readLength();

}

class EndianStream(Endian endianness) : Stream {
	
	public pure nothrow @safe @nogc this(ubyte[] buffer=[]) {
		super(buffer);
	}

	private mixin template Impl(T) {

		mixin("public override pure nothrow @safe void write" ~ capitalize(T.stringof) ~ "(T value){ this.buffer ~= write!(T, endianness)(value); }");

		mixin("public override pure nothrow @safe T read" ~ capitalize(T.stringof) ~ "(){ return read!(T, endianness)(this.buffer); }");

	}

	mixin Impl!byte;

	mixin Impl!short;

	mixin Impl!int;

	mixin Impl!long;

	mixin Impl!float;

	mixin Impl!double;

	public override pure nothrow @trusted void writeString(string value) {
		this.writeStringLength(value.length);
		this.buffer ~= cast(ubyte[])value;
	}

	protected pure nothrow @safe void writeStringLength(size_t value) {
		this.writeShort(value & short.max);
	}

	public override pure nothrow @safe void writeLength(size_t value) {
		this.writeInt(value & int.max);
	}
	
	public override pure nothrow @trusted string readString() {
		immutable length = this.readStringLength();
		if(this.buffer.length < length) this.buffer.length = length;
		auto ret = this.buffer[0..length];
		this.buffer = this.buffer[length..$];
		return cast(string)ret;
	}

	protected pure nothrow @safe size_t readStringLength() {
		return this.readShort();
	}

	public override pure nothrow @safe size_t readLength() {
		return this.readInt();
	}

}

class NetworkStream(Endian endianness) : EndianStream!(endianness) {

	public pure nothrow @safe @nogc this(ubyte[] buffer=[]) {
		super(buffer);
	}

	public override pure nothrow @safe void writeInt(int value) {
		//TODO write signed varint
	}

	protected override pure nothrow @safe void writeStringLength(size_t value) {
		this.writeLength(value);
	}
	
	public override pure nothrow @safe void writeLength(size_t value) {
		//TODO write unsigned varint
	}

	public override pure nothrow @safe int readInt() {
		//TODO read signed varint
	}

	protected override pure nothrow @safe size_t readStringLength() {
		return this.readLength();
	}

	public override pure nothrow @safe size_t readLength() {
		//TODO read unsigned varint
	}

}
