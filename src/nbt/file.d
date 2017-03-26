/*
 * Copyright (c) 2017
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU Lesser General Public License for more details.
 * 
 */
module nbt.file;

// test
import std.conv;
import std.stdio : writeln;

static import std.bitmanip;
static import std.file;
import std.system : Endian;
import std.traits : isAbstractClass;
import std.typetuple : TypeTuple;
import std.zlib;

import nbt.stream;
import nbt.tags;

enum Compression {

	deflate,
	gzip,
	none

}

/**
 * Example:
 * ---
 * alias Level = Format!(Named!Compound, ClassicStream!(Endian.bigEndian), Compression.gzip);
 * auto level = Level.read("level.dat");
 * level.get!Compound("data")["LevelName"] = "Edited from code!";
 * Level.write(level, "level.dat");
 * ---
 */
class Format(T : Tag, S : Stream, Compression c, int level=6) if(!isAbstractClass!T && !isAbstractClass!S) {

	private static S stream;

	public static this() {
		stream = new S();
	}

	public string location;

	public this(string location) {
		this.location = location;
	}
	
	public T load() {
		
		ubyte[] data = cast(ubyte[])std.file.read(this.location);

		this.readHeader(data);
		
		static if(c != Compression.none) {
			UnCompress uc = new UnCompress(cast(HeaderFormat)c);
			data = cast(ubyte[])uc.uncompress(data);
			data ~= cast(ubyte[])uc.flush();
		}
		
		stream.buffer = data;
		
		static if(is(T : NamedTag)) {
			return cast(T)stream.readNamedTag();
		} else {
			return cast(T)stream.readTag();
		}
		
	}

	protected void readHeader(ref ubyte[] data) {}

	public void save(T tag) {

		stream.buffer.length = 0;
		static if(is(T : NamedTag)) {
			stream.writeNamedTag(tag);
		} else {
			stream.writeTag(tag);
		}
		ubyte[] data = stream.buffer;

		static if(c != Compression.none) {
			Compress compress = new Compress(level, cast(HeaderFormat)c);
			data = cast(ubyte[])compress.compress(data);
			data ~= cast(ubyte[])compress.flush();
		}

		this.writeHeader(data);

		std.file.write(this.location, data);

	}

	protected void writeHeader(ref ubyte[] data) {}

}

alias MinecraftLevelFormat = Format!(Named!Compound, ClassicStream!(Endian.bigEndian), Compression.gzip);

class PocketLevelFormat : Format!(Named!Compound, ClassicStream!(Endian.littleEndian), Compression.none) {

	private uint v = 5;

	public this(string location) {
		super(location);
	}

	protected override void readHeader(ref ubyte[] data) {
		if(data.length >= 8) {
			this.v = std.bitmanip.read!(uint, Endian.littleEndian)(data);
			size_t size = std.bitmanip.read!(uint, Endian.littleEndian)(data);
			assert(data.length == size);
		}
	}

	protected override void writeHeader(ref ubyte[] data) {
		data = std.bitmanip.nativeToLittleEndian(this.v).dup ~ std.bitmanip.nativeToLittleEndian(cast(uint)data.length).dup ~ data;
	}

}
