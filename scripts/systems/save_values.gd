class_name SaveValues
extends RefCounted
## Encodes whitelisted simulation properties and resolves references inside one settlement.
# gdlint: disable=max-returns

var ids: Dictionary[Object, String] = {}
var objects: Dictionary[String, Object] = {}
var error := ""


func register(id: String, value: Object) -> void:
	if id.is_empty() or value == null or objects.has(id):
		error = "Duplicate or missing settlement object."
		return
	ids[value] = id
	objects[id] = value


func gather(obj: Object, fields: String) -> Dictionary:
	var data := {}
	for key in fields.split(" ", false):
		data[key] = encode(obj.get(key))
	return data


func fill(obj: Object, fields: String, data: Variant) -> bool:
	if obj == null or typeof(data) != TYPE_DICTIONARY:
		return false
	var keys := fields.split(" ", false)
	for key in keys:
		if not data.has(key):
			return false
		var value: Variant = decode(data[key])
		if not error.is_empty():
			return false
		var current: Variant = obj.get(key)
		if current is Array:
			if not value is Array or not _array_fits(current, value):
				return false
			current.assign(value)
		elif current is Dictionary:
			if not value is Dictionary or not _dict_fits(current, value):
				return false
			current.assign(value)
		elif current == null or current is Object:
			if value != null and not value is Object:
				return false
			if value != null and not _fits_property(obj, key, value):
				return false
			obj.set(key, value)
		elif typeof(current) == typeof(value):
			obj.set(key, value)
		else:
			return false
	return true


func _array_fits(target: Array, values: Array) -> bool:
	if target.is_typed():
		for val: Variant in values:
			if not _fits(val, target.get_typed_builtin(), target.get_typed_script()):
				return false
	return true


func _dict_fits(target: Dictionary, values: Dictionary) -> bool:
	if target.is_typed():
		for key: Variant in values:
			if not _fits(key, target.get_typed_key_builtin(), target.get_typed_key_script()):
				return false
			if not _fits(
				values[key], target.get_typed_value_builtin(), target.get_typed_value_script()
			):
				return false
	return true


func _fits(val: Variant, type: int, script: Variant) -> bool:
	if type == TYPE_NIL:
		return true
	if type == TYPE_OBJECT:
		return val == null or (val is Object and (script == null or is_instance_of(val, script)))
	return typeof(val) == type


func _fits_property(obj: Object, key: String, value: Object) -> bool:
	for p: Dictionary in obj.get_property_list():
		if p.name == key:
			if value.is_class(p.class_name):
				return true
			var script := value.get_script() as Script
			while script != null:
				if script.get_global_name() == p.class_name:
					return true
				script = script.get_base_script()
	return false


func encode(value: Variant) -> Variant:
	var result: Variant
	match typeof(value):
		TYPE_NIL, TYPE_FLOAT, TYPE_BOOL, TYPE_STRING:
			result = value
		TYPE_INT:
			result = {"i": str(value)}
		TYPE_STRING_NAME:
			result = {"n": String(value)}
		TYPE_VECTOR3:
			result = {"xyz": [value.x, value.y, value.z]}
		TYPE_VECTOR2, TYPE_VECTOR2I:
			result = {"v": [value.x, value.y], "integer": value is Vector2i}
		TYPE_ARRAY:
			var items: Array = []
			for val: Variant in value:
				items.append(encode(val))
			result = {"a": items}
		TYPE_DICTIONARY:
			var pairs: Array = []
			for key: Variant in value:
				pairs.append([encode(key), encode(value[key])])
			result = {"d": pairs}
		TYPE_OBJECT:
			if not is_instance_valid(value):
				return null
			if not ids.has(value):
				error = "Unregistered settlement object: " + str(value)
			result = {"r": ids.get(value, "")}
		TYPE_PACKED_BYTE_ARRAY:
			result = {
				"p": typeof(value),
				"bytes": "" if value.is_empty() else Marshalls.raw_to_base64(value)
			}
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_VECTOR2_ARRAY:
			var bytes: PackedByteArray = value.to_byte_array()
			result = {
				"p": typeof(value),
				"bytes": "" if bytes.is_empty() else Marshalls.raw_to_base64(bytes)
			}
		_:
			error = "Unsupported save field."
	return result


func decode(value: Variant, depth: int = 0) -> Variant:
	if depth > 12:
		error = "Invalid nesting in save."
		return null
	if value == null or typeof(value) in [TYPE_STRING, TYPE_BOOL, TYPE_FLOAT]:
		return value
	if typeof(value) != TYPE_DICTIONARY:
		error = "Invalid save value."
		return null
	var result: Variant
	if value.has("i") and value.i is String and value.i.is_valid_int():
		result = value.i.to_int()
	elif value.has("n") and value.n is String:
		result = StringName(value.n)
	elif value.has("r") and value.r is String and objects.has(value.r):
		result = objects[value.r]
	elif value.get("xyz") is Array and value.xyz.size() == 3:
		if _number(value.xyz[0]) and _number(value.xyz[1]) and _number(value.xyz[2]):
			result = Vector3(value.xyz[0], value.xyz[1], value.xyz[2])
		else:
			error = "Invalid camera position."
	elif value.has("v") and value.v is Array and value.v.size() == 2 and value.has("integer"):
		if not _number(value.v[0]) or not _number(value.v[1]):
			error = "Invalid map coordinate."
		else:
			var point := Vector2(value.v[0], value.v[1])
			result = Vector2i(point) if value.integer else point
	elif value.has("a") and value.a is Array:
		var array: Array = []
		for val: Variant in value.a:
			array.append(decode(val, depth + 1))
		result = array
	elif value.has("d") and value.d is Array:
		var pairs := {}
		for pair: Variant in value.d:
			if not pair is Array or pair.size() != 2:
				error = "Invalid saved dictionary."
				break
			var key: Variant = decode(pair[0], depth + 1)
			if key == null or pairs.has(key):
				error = "Invalid saved dictionary key."
				break
			pairs[key] = decode(pair[1], depth + 1)
		result = pairs
	elif value.has("p") and value.get("bytes") is String:
		result = _unpack(int(value.p), value.bytes)
	else:
		error = "Unknown value or broken settlement reference."
	return result


func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(value))


func _unpack(type: int, data: String) -> Variant:
	var bytes := PackedByteArray() if data.is_empty() else Marshalls.base64_to_raw(data)
	if not data.is_empty() and bytes.is_empty():
		error = "Invalid packed data."
	match type:
		TYPE_PACKED_BYTE_ARRAY:
			return bytes
		TYPE_PACKED_INT32_ARRAY:
			if bytes.size() % 4 == 0:
				return bytes.to_int32_array()
		TYPE_PACKED_FLOAT32_ARRAY:
			if bytes.size() % 4 == 0:
				return bytes.to_float32_array()
		TYPE_PACKED_VECTOR2_ARRAY:
			if bytes.size() % 8 == 0:
				var floats := bytes.to_float32_array()
				var points := PackedVector2Array()
				points.resize(floats.size() / 2)
				for i in points.size():
					points[i] = Vector2(floats[i * 2], floats[i * 2 + 1])
				return points
	error = "Invalid packed field."
	return null
