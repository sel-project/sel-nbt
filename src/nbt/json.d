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
