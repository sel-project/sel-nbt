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
 * Source: $(HTTP github.com/sel-project/sel-nbt/sel/nbt/json.d, sel/nbt/json.d)
 */
module sel.nbt.json;

import std.json;

import sel.nbt.tags;

/**
 * Converts a Tag into a JSONValue.
 */
JSONValue toJSON(Tag tag) {
	if(tag is null) {
		return JSONValue(null);
	} else {
		return tag.toJSON();
	}
}

///
unittest {
	
	auto compound = new Compound();
	compound["a"] = 44;
	assert(toJSON(compound) == JSONValue(["a": 44]));
	
	assert(toJSON(new Int(12)) == JSONValue(12));
	assert(toJSON(new ListOf!Int(9, 10)) == JSONValue([9, 10]));
	assert(toJSON(null).type == JSON_TYPE.NULL);
	
}

/**
 * Converts a JSONValue into a Tag.
 * Returns:
 * 		an instance of Compound when the json is an object, and instance of
 * 		List when the json is an array, an instance of String when the json
 * 		is a string, an instance of Long when the json is an integer, an 
 * 		instance of Double when the json is a floating point number, an
 * 		instance of Byte (with values 0 and 1) when the json is a boolean
 * 		and null when the json is null.
 */
Tag toNBT(JSONValue json) {
	final switch(json.type) {
		case JSON_TYPE.OBJECT:
			Tag[] nt;
			foreach(name, value; json.object) {
				auto tag = toNBT(value);
				if(tag !is null) nt ~= tag.rename(name);
			}
			return new Compound(nt);
		case JSON_TYPE.ARRAY:
			Tag[] t;
			foreach(value ; json.array) {
				auto tag = toNBT(value);
				if(tag !is null) t ~= tag;
			}
			return new List(t);
		case JSON_TYPE.STRING:
			return new String(json.str);
		case JSON_TYPE.INTEGER:
			return new Long(json.integer);
		case JSON_TYPE.UINTEGER:
			return new Long(json.uinteger & long.max);
		case JSON_TYPE.FLOAT:
			return new Double(json.floating);
		case JSON_TYPE.TRUE:
			return new Bool(true);
		case JSON_TYPE.FALSE:
			return new Bool(false);
		case JSON_TYPE.NULL:
			return null;
	}
}

///
unittest {

	assert(toNBT(JSONValue(true)) == new Byte(1));
	assert(toNBT(JSONValue([1, 2, 3])) == new ListOf!Long(1, 2, 3));
	assert(toNBT(JSONValue(["a": [42]])) == new Compound(new Named!(ListOf!Long)("a", 42)));
	//assert(toNBT(JSONValue(["a": [42]])) == new Compound(new Named!List("a", new Long(42)))); //FIXME
	assert(toNBT(JSONValue("test")) == new String("test"));
	assert(toNBT(JSONValue(42)) == new Long(42));
	assert(toNBT(JSONValue(42u)) == new Long(42));
	assert(toNBT(JSONValue(.523)) == new Double(.523));
	assert(toNBT(JSONValue(true)) == new Byte(1));
	assert(toNBT(JSONValue(false)) == new Byte(0));
	assert(toNBT(JSONValue(null)) is null);

}
