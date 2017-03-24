module nbt.stream;

import std.bitmanip : read, write;
import std.string : capitalize;
import std.system : Endian;

import nbt.tags;

class Stream {

	public ubyte[] buffer;
	
	public pure nothrow @safe @nogc this(ubyte[] buffer=[]) {
		this.buffer = buffer;
	}

	public void writeTag(Tag tag) {
		this.writeByte(tag.type);
		auto named = cast(NamedTag)tag;
		if(named !is null) {
			this.writeString(named.name);
			named.encode(this);
		}
	}

	public abstract void writeByte(byte value);

	public abstract void writeShort(short value);

	public abstract void writeInt(int value);

	public abstract void writeLong(long value);

	public abstract void writeFloat(float value);

	public abstract void writeDouble(double value);

	public abstract void writeString(string value);

	public abstract void writeLength(size_t value);

	public Tag readTag() {
		switch(this.readByte()) {
			case NBT_TYPE.BYTE: return this.readTagImpl!Byte();
			case NBT_TYPE.SHORT: return this.readTagImpl!Short();
			case NBT_TYPE.INT: return this.readTagImpl!Int();
			case NBT_TYPE.LONG: return this.readTagImpl!Long();
			case NBT_TYPE.FLOAT: return this.readTagImpl!Float();
			case NBT_TYPE.DOUBLE: return this.readTagImpl!Double();
			case NBT_TYPE.BYTE_ARRAY: return this.readTagImpl!ByteArray();
			case NBT_TYPE.STRING: return this.readTagImpl!String();
			case NBT_TYPE.LIST: return this.readTagImpl!List();
			case NBT_TYPE.COMPOUND: return this.readTagImpl!Compound();
			case NBT_TYPE.INT_ARRAY: return this.readTagImpl!IntArray();
			default: return new End();
		}
	}

	public T readTagImpl(T:NamedTag, bool readName=true)() {
		static if(readName) {
			T ret = new T(this.readString());
		} else {
			T ret = new T();
		}
		ret.decode(this);
		return ret;
	}

	public abstract byte readByte();

	public abstract short readShort();

	public abstract int readInt();

	public abstract long readLong();

	public abstract float readFloat();

	public abstract double readDouble();

	public abstract string readString();

	public abstract size_t readLength();

}

class EndianStream(Endian endianness) : Stream {
	
	public pure nothrow @safe @nogc this(ubyte[] buffer=[]) {
		super(buffer);
	}

	private mixin template Impl(T) {

		mixin("public override void write" ~ capitalize(T.stringof) ~ "(T value){ this.buffer.length += T.sizeof; write!(T, endianness)(this.buffer, value, this.buffer.length - T.sizeof); }");

		mixin("public override T read" ~ capitalize(T.stringof) ~ "(){ if(this.buffer.length < T.sizeof){ this.buffer.length=T.sizeof; } return read!(T, endianness)(this.buffer); }");

	}

	mixin Impl!byte;

	mixin Impl!short;

	mixin Impl!int;

	mixin Impl!long;

	mixin Impl!float;

	mixin Impl!double;

	public override void writeString(string value) {
		this.writeStringLength(value.length);
		this.buffer ~= cast(ubyte[])value;
	}

	protected void writeStringLength(size_t value) {
		this.writeShort(value & short.max);
	}

	public override void writeLength(size_t value) {
		this.writeInt(value & int.max);
	}
	
	public override string readString() {
		immutable length = this.readStringLength();
		if(this.buffer.length < length) this.buffer.length = length;
		auto ret = this.buffer[0..length];
		this.buffer = this.buffer[length..$];
		return cast(string)ret;
	}

	protected size_t readStringLength() {
		return this.readShort();
	}

	public override size_t readLength() {
		return this.readInt();
	}

}

class NetworkStream(Endian endianness) : EndianStream!(endianness) {

	public pure nothrow @safe @nogc this(ubyte[] buffer=[]) {
		super(buffer);
	}

	public override void writeInt(int value) {
		//TODO write signed varint
	}

	protected override void writeStringLength(size_t value) {
		this.writeLength(value);
	}
	
	public override void writeLength(size_t value) {
		//TODO write unsigned varint
	}

	public override int readInt() {
		//TODO read signed varint
	}

	protected override size_t readStringLength() {
		return this.readLength();
	}

	public override size_t readLength() {
		//TODO read unsigned varint
	}

}
