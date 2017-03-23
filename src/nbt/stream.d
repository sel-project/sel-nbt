module nbt.stream;

import std.bitmanip : read, write;
import std.string : capitalize;
import std.system : Endian;

import nbt.tags;

class Stream {

	ubyte[] buffer;

	public void writeTag(Tag tag) {
		this.writeByte(tag.id);
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
			case NBT.BYTE: return this.readTagImpl!Byte();
			case NBT.SHORT: return this.readTagImpl!Short();
			case NBT.INT: return this.readTagImpl!Int();
			case NBT.LONG: return this.readTagImpl!Long();
			case NBT.FLOAT: return this.readTagImpl!Float();
			case NBT.DOUBLE: return this.readTagImpl!Double();
			case NBT.BYTE_ARRAY: return this.readTagImpl!ByteArray();
			case NBT.STRING: return this.readTagImpl!String();
			case NBT.LIST: return this.readTagImpl!List();
			case NBT.COMPOUND: return this.readTagImpl!Compound();
			case NBT.INT_ARRAY: return this.readTagImpl!IntArray();
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
		this.writeShort(value.length & short.max);
		this.buffer ~= cast(ubyte[])value;
	}

	public override string readString() {
		immutable length = this.readShort();
		if(this.buffer.length < length) this.buffer.length = length;
		auto ret = this.buffer[0..length];
		this.buffer = this.buffer[length..$];
		return cast(string)ret;
	}

	public override void writeLength(size_t value) {
		this.writeInt(value & int.max);
	}

	public override size_t readLength() {
		return this.readInt();
	}

}

class NetworkStream : EndianStream!(Endian.littleEndian) {}
