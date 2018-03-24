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
 * Copyright: Copyright (c) 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/sel-nbt/sel/nbt/file.d, sel/nbt/file.d)
 */
module sel.nbt.file;

import std.conv : to;

static import std.bitmanip;
static import std.file;
import std.system : Endian;
import std.traits : isAbstractClass;
import std.typetuple : TypeTuple;
import std.zlib;

import xbuffer.buffer : Buffer;

import sel.nbt.stream;
import sel.nbt.tags;

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
		stream = new S(new Buffer(1024));
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
		
		stream.buffer.data = std.file.read(this.location);

		this.loadHeader(stream.buffer);
		
		static if(c != Compression.none) {
			UnCompress uc = new UnCompress(cast(HeaderFormat)c);
			void[] data = stream.buffer.data!void.dup;
			stream.buffer.reset();
			stream.buffer.write(uc.uncompress(data));
			stream.buffer.write(uc.flush());
		}

		//TODO nameless tag
		this.tag = cast(T)stream.readTag();

		return this.tag;
		
	}

	protected void loadHeader(Buffer buffer) {}

	public T save() {

		stream.buffer.reset();
		//TODO nameless tag
		stream.writeTag(this.tag);

		static if(c != Compression.none) {
			Compress compress = new Compress(level, cast(HeaderFormat)c);
			stream.buffer.data = compress.compress(stream.buffer.data!void);
			stream.buffer.write(compress.flush());
		}

		this.saveHeader(stream.buffer);

		std.file.write(this.location, stream.buffer.data!void);

		return this.tag;

	}

	protected void saveHeader(Buffer buffer) {}

	alias tag this;

}

alias JavaLevelFormat = Format!(Compound, ClassicStream!(Endian.bigEndian), Compression.gzip);

class PocketLevelFormat : Format!(Compound, ClassicStream!(Endian.littleEndian), Compression.none) {

	private uint v = 5;

	public this(string location, Compound tag=null) {
		super(location, tag);
	}

	public this(Compound tag, string location="") {
		super(tag, location);
	}

	protected override void loadHeader(Buffer buffer) {
		this.v = buffer.read!(Endian.littleEndian, uint)();
		buffer.read!(Endian.littleEndian, uint)(); // size
	}

	protected override void saveHeader(Buffer buffer) {
		void[] data = buffer.data!void.dup;
		buffer.reset();
		buffer.write!(Endian.littleEndian)(this.v);
		buffer.write!(Endian.littleEndian)(data.length.to!uint);
		buffer.write(data);
	}

	alias tag this;

}

unittest {

	auto java = new JavaLevelFormat("test/java.dat");
	java.load();
	auto data = java.get!Compound("Data", null);
	assert(data !is null);
	assert(data.has!String("LevelName") && data.get!String("LevelName", null) == "New World");
	assert(data.has!Int("version") && data.get!Int("version", null) == 19133);

	java = new JavaLevelFormat(new Compound(new Named!Int("Test", 42)), "test.dat");
	java.save();
	auto u = new UnCompress(HeaderFormat.gzip);
	auto b = cast(ubyte[])u.uncompress(std.file.read("test.dat"));
	b ~= cast(ubyte[])u.flush();
	assert(b == [10, 0, 0, 3, 0, 4, 84, 101, 115, 116, 0, 0, 0, 42, 0]);

	auto pocket = new PocketLevelFormat("test/pocket.dat");
	pocket.load();
	assert(pocket.has!String("LevelName") && pocket.get!String("LevelName", null) == "AAAAAAAAAA");
	assert(pocket.has!Int("Difficulty") && pocket.get!Int("Difficulty", null) == 2);

	pocket = new PocketLevelFormat(new Compound(new Named!Int("Test", 42)), "test.dat");
	pocket.save();
	assert(cast(ubyte[])std.file.read("test.dat") == [5, 0, 0, 0, 15, 0, 0, 0, 10, 0, 0, 3, 4, 0, 84, 101, 115, 116, 42, 0, 0, 0, 0]);

}
