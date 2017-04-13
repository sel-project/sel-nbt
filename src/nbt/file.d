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
	public T tag;

	public this(string location, T tag=null) {
		this.location = location;
		this.tag = tag;
	}

	public this(T tag, string location="") {
		this(location, tag);
	}
	
	public T load() {
		
		ubyte[] data = cast(ubyte[])std.file.read(this.location);

		this.loadHeader(data);
		
		static if(c != Compression.none) {
			UnCompress uc = new UnCompress(cast(HeaderFormat)c);
			data = cast(ubyte[])uc.uncompress(data);
			data ~= cast(ubyte[])uc.flush();
		}
		
		stream.buffer = data;

		//TODO nameless tag
		this.tag = cast(T)stream.readTag();

		return this.tag;
		
	}

	protected void loadHeader(ref ubyte[] data) {}

	public T save() {

		stream.buffer.length = 0;
		//TODO nameless tag
		stream.writeTag(this.tag);
		ubyte[] data = stream.buffer;

		static if(c != Compression.none) {
			Compress compress = new Compress(level, cast(HeaderFormat)c);
			data = cast(ubyte[])compress.compress(data);
			data ~= cast(ubyte[])compress.flush();
		}

		this.saveHeader(data);

		std.file.write(this.location, data);

		return this.tag;

	}

	protected void saveHeader(ref ubyte[] data) {}

	alias tag this;

}

alias MinecraftLevelFormat = Format!(Compound, ClassicStream!(Endian.bigEndian), Compression.gzip);

class PocketLevelFormat : Format!(Compound, ClassicStream!(Endian.littleEndian), Compression.none) {

	private uint v = 5;

	public this(string location, Compound tag=null) {
		super(location, tag);
	}

	public this(Compound tag, string location="") {
		super(tag, location);
	}

	protected override void loadHeader(ref ubyte[] data) {
		if(data.length >= 8) {
			this.v = std.bitmanip.read!(uint, Endian.littleEndian)(data);
			size_t size = std.bitmanip.read!(uint, Endian.littleEndian)(data);
			assert(data.length == size);
		}
	}

	protected override void saveHeader(ref ubyte[] data) {
		data = std.bitmanip.nativeToLittleEndian(this.v).dup ~ std.bitmanip.nativeToLittleEndian(cast(uint)data.length).dup ~ data;
	}

	alias tag this;

}

unittest {

	auto minecraft = new MinecraftLevelFormat("test/minecraft.dat");
	minecraft.load();
	auto data = minecraft.get!Compound("Data");
	assert(data !is null);
	assert(data.has!String("LevelName") && data.get!String("LevelName") == "New World");
	assert(data.has!Int("version") && data.get!Int("version") == 19133);

	minecraft = new MinecraftLevelFormat(new Compound(new Named!Int("Test", 42)), "test.dat");
	minecraft.save();
	auto u = new UnCompress(HeaderFormat.gzip);
	auto b = cast(ubyte[])u.uncompress(std.file.read("test.dat"));
	b ~= cast(ubyte[])u.flush();
	assert(b == [10, 0, 0, 3, 0, 4, 84, 101, 115, 116, 0, 0, 0, 42, 0]);

	auto pocket = new PocketLevelFormat("test/pocket.dat");
	pocket.load();
	assert(pocket.has!String("LevelName") && pocket.get!String("LevelName") == "AAAAAAAAAA");
	assert(pocket.has!Int("Difficulty") && pocket.get!Int("Difficulty") == 2);

	pocket = new PocketLevelFormat(new Compound(new Named!Int("Test", 42)), "test.dat");
	pocket.save();
	assert(cast(ubyte[])std.file.read("test.dat") == [5, 0, 0, 0, 15, 0, 0, 0, 10, 0, 0, 3, 4, 0, 84, 101, 115, 116, 42, 0, 0, 0, 0]);

}
