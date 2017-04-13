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
module nbt.json;

import std.json;

import nbt.tags;

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
