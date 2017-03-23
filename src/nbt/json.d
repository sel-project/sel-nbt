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

JSONValue toJSON(Tag tag) {
	return tag.toJSON();
}

Tag toNBT(JSONValue json) {
	final switch(json.type) {
		case JSON_TYPE.OBJECT:
			Compound ret;
			foreach(name, value; json.object) {
				auto tag = toNBT(value);
				if(cast(NamedTag)tag) ret[name] = cast(NamedTag)tag;
			}
			return ret;
		case JSON_TYPE.ARRAY:
			List ret;
			foreach(value ; json.array) {
				auto tag = toNBT(value);
				if(cast(NamedTag)tag) ret ~= cast(NamedTag)tag;
			}
			return ret;
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
			return new End();
	}
}

unittest {

	auto compound = new Compound();
	compound["a"] = 44;
	assert(toJSON(compound) == JSONValue(["a": 44]));

}
