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
 * Source: $(HTTP github.com/sel-project/sel-nbt/sel/nbt/stream.d, sel/nbt/stream.d)
 */
module sel.nbt.stream;

import std.string : capitalize;
import std.system : Endian;

import sel.nbt.tags : Tags, Tag, Named;

import xbuffer.buffer : Buffer;

class Stream {
	
	public Buffer buffer;
	
	public this(Buffer buffer) pure nothrow @safe @nogc {
		this.buffer = buffer;
	}
	
	public this(ubyte[] buffer) pure nothrow @safe {
		this(new Buffer(buffer));
	}
	
	public this() pure nothrow @safe {
		this(new Buffer(512));
	}
	
	public @property ubyte[] data() pure nothrow @trusted @nogc {
		return this.buffer.data!ubyte();
	}

	public @property ubyte[] data(ubyte[] data) pure nothrow @trusted @nogc {
		return this.buffer.data = data;
	}
	
	public void writeNamelessTag(Tag tag) pure nothrow @safe @nogc {
		this.writeByte(tag.type);
		tag.encode(this);
	}
	
	public void writeTag(Tag tag) pure nothrow @safe @nogc {
		this.writeByte(tag.type);
		this.writeString(tag.name);
		tag.encode(this);
	}
	
	public abstract void writeByte(byte value) pure nothrow @safe @nogc;
	
	public abstract void writeShort(short value) pure nothrow @safe @nogc;
	
	public abstract void writeInt(int value) pure nothrow @safe @nogc;
	
	public abstract void writeLong(long value) pure nothrow @safe @nogc;
	
	public abstract void writeFloat(float value) pure nothrow @safe @nogc;
	
	public abstract void writeDouble(double value) pure nothrow @safe @nogc;
	
	public abstract void writeString(string value) pure nothrow @safe @nogc;
	
	public abstract void writeLength(size_t value) pure nothrow @safe @nogc;
	
	public Tag readNamelessTag() pure @safe {
		switch(this.readByte()) {
			foreach(i, T; Tags) {
				static if(is(T : Tag)) {
					case i: return this.decodeTagImpl(new T());
				}
			}
			default: return null;
		}
	}
	
	public Tag readTag() pure @safe {
		switch(this.readByte()) {
			foreach(i, T; Tags) {
				static if(is(T : Tag)) {
					case i: return this.decodeTagImpl(new Named!T(this.readString()));
				}
			}
			default: return null;
		}
	}
	
	public T decodeTagImpl(T:Tag)(T tag) pure @safe {
		tag.decode(this);
		return tag;
	}
	
	public abstract byte readByte() pure @safe;
	
	public abstract short readShort() pure @safe;

	public abstract int readInt() pure @safe;
	
	public abstract long readLong() pure @safe;
	
	public abstract float readFloat() pure @safe;
	
	public abstract double readDouble() pure @safe;
	
	public abstract string readString() pure @safe;
	
	public abstract size_t readLength() pure @safe;
	
}

class ClassicStream(Endian endianness) : Stream {
	
	public this(Buffer buffer) pure nothrow @safe @nogc {
		super(buffer);
	}

	public this(ubyte[] buffer) pure nothrow @safe {
		super(buffer);
	}

	public this() pure nothrow @safe {
		super();
	}
	
	private mixin template Impl(T) {
		
		mixin("override void write" ~ capitalize(T.stringof) ~ "(T value){ this.buffer.write!(endianness, T)(value); }");
		
		mixin("override T read" ~ capitalize(T.stringof) ~ "(){ return this.buffer.read!(endianness, T)(); }");
		
	}
	
	mixin Impl!byte;
	
	mixin Impl!short;
	
	mixin Impl!int;
	
	mixin Impl!long;
	
	mixin Impl!float;
	
	mixin Impl!double;
	
	public override void writeString(string value) {
		this.writeStringLength(value.length);
		this.buffer.write!string(value);
	}
	
	protected void writeStringLength(size_t value) pure nothrow @safe @nogc {
		this.writeShort(value & short.max);
	}
	
	public override void writeLength(size_t value) {
		this.writeInt(value & int.max);
	}
	
	public override string readString() {
		return this.buffer.read!string(this.readStringLength());
	}
	
	protected size_t readStringLength() pure @safe {
		return this.readShort();
	}
	
	public override size_t readLength() {
		return this.readInt();
	}
	
}

class NetworkStream(Endian endianness) : ClassicStream!(endianness) {
	
	public this(Buffer buffer) pure nothrow @safe @nogc {
		super(buffer);
	}
	
	public this(ubyte[] buffer) pure nothrow @safe {
		super(buffer);
	}
	
	public this() pure nothrow @safe {
		super();
	}
	
	public override void writeInt(int value) {
		this.buffer.writeVar(value);
	}
	
	protected override void writeStringLength(size_t value) {
		this.writeLength(value);
	}
	
	public override void writeLength(size_t value) {
		this.buffer.writeVar(value & uint.max);
	}
	
	public override int readInt() {
		return this.buffer.readVar!int();
	}
	
	protected override size_t readStringLength() {
		return this.readLength();
	}
	
	public override size_t readLength() {
		return this.buffer.readVar!uint();
	}
	
}
